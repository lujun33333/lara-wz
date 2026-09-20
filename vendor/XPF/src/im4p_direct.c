//
//  im4p_direct.c
//  AX: direct IM4P reader, used by xpf_load_img4() as a fallback.
//
//  img4lib's IM4P path (img4_reopen) refuses the SPTM/TXM containers Apple
//  ships for iOS 26 without leaving a diagnostic behind, and XPF then reports
//  only "Failed to load / decompress SPTM". This reader takes the same
//  container apart with a plain DER walk:
//
//      SEQUENCE {
//          IA5String "IM4P"
//          IA5String type                     -- e.g. "sptm"
//          IA5String description
//          OCTET STRING payload               -- bvx2 LZFSE stream
//          SEQUENCE {                         -- optional
//              INTEGER algorithm              -- 1 == LZFSE
//              INTEGER uncompressedSize
//          }
//          [0] manifest
//      }
//
//  The payload is decoded with the LZFSE decoder linked into this library
//  (lzfse/lzfse, Apple's reference implementation -- the same one img4lib uses
//  when it is built without -DUSE_LIBCOMPRESSION) and the result is returned
//  only when it really is a Mach-O image. Nothing else about XPF changes.
//
#include "im4p_direct.h"

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "lzfse.h"

#define AX_MH_MAGIC_64 0xfeedfacfU
#define AX_MH_CIGAM_64 0xcffaedfeU
#define AX_MH_MAGIC_32 0xfeedfaceU
#define AX_MH_CIGAM_32 0xcefaedfeU
#define AX_FAT_MAGIC   0xcafebabeU
#define AX_FAT_CIGAM   0xbebafecaU

// SPTM/TXM images are around 1 MB; 1 GB is a hard ceiling so a corrupt size
// field cannot turn into an allocation storm.
#define AX_LZFSE_MAX_OUT (1U << 30)

// Last failure reason, readable by the caller (see im4p_direct.h). stderr alone
// is not enough: the App log is often copied filtered, and then the reason for a
// silent refusal is lost.
static char gDiagText[192] = "none";

void xpf_img4_diag(const char *text)
{
	if (!text) {
		return;
	}
	size_t i = 0;
	for (; i + 1 < sizeof(gDiagText) && text[i]; i++) {
		gDiagText[i] = text[i];
	}
	gDiagText[i] = '\0';
}

const char *xpf_img4_last_diag(void)
{
	return gDiagText;
}

void xpf_img4_diag_append(const char *text)
{
	if (!text) {
		return;
	}
	size_t i = strlen(gDiagText);
	if (i + 3 < sizeof(gDiagText)) {
		gDiagText[i++] = ' ';
		gDiagText[i++] = '|';
		gDiagText[i++] = ' ';
		gDiagText[i] = '\0';
	}
	for (size_t j = 0; i + 1 < sizeof(gDiagText) && text[j]; j++) {
		gDiagText[i++] = text[j];
		gDiagText[i] = '\0';
	}
}

static void ax_diag(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(gDiagText, sizeof(gDiagText), fmt, ap);
	va_end(ap);
	fprintf(stderr, "[e] im4p_direct: %s\n", gDiagText);
}

int ax_is_macho(const void *buf, size_t size)
{
	if (!buf || size < 4) {
		return 0;
	}
	uint32_t magic = 0;
	memcpy(&magic, buf, sizeof(magic));
	switch (magic) {
		case AX_MH_MAGIC_64:
		case AX_MH_CIGAM_64:
		case AX_MH_MAGIC_32:
		case AX_MH_CIGAM_32:
		case AX_FAT_MAGIC:
		case AX_FAT_CIGAM:
			return 1;
		default:
			return 0;
	}
}

// One DER TLV. Returns the pointer just past this element, or NULL when the
// buffer ends inside it. Long-form lengths up to four bytes are supported,
// which covers the IM4P files Apple ships.
static const unsigned char *ax_der_tlv(const unsigned char *p, const unsigned char *end,
                                       unsigned char *tag, const unsigned char **content,
                                       size_t *length)
{
	if (end - p < 2) {
		return NULL;
	}
	unsigned char type = p[0];
	size_t len = p[1];
	p += 2;
	if (len & 0x80) {
		size_t count = len & 0x7f;
		if (count == 0 || count > 4 || (size_t)(end - p) < count) {
			return NULL;
		}
		len = 0;
		for (size_t i = 0; i < count; i++) {
			len = (len << 8) | *p++;
		}
	}
	if ((size_t)(end - p) < len) {
		return NULL;
	}
	*tag = type;
	*content = p;
	*length = len;
	return p + len;
}

// Locate the payload OCTET STRING and, when present, the LZFSE algorithm and
// uncompressed size from the compression SEQUENCE.
static int ax_im4p_extract(const unsigned char *file, size_t fileSize,
                           const unsigned char **payload, size_t *payloadSize,
                           uint64_t *usize)
{
	unsigned char tag = 0;
	const unsigned char *content = NULL;
	size_t length = 0;
	const unsigned char *after = ax_der_tlv(file, file + fileSize, &tag, &content, &length);
	if (!after || tag != 0x30) {
		return -1;
	}

	const unsigned char *end = content + length;
	const unsigned char *cursor = content;
	const unsigned char *found = NULL;
	size_t foundSize = 0;
	uint64_t size = 0;

	while (cursor < end) {
		unsigned char itemTag = 0;
		const unsigned char *itemContent = NULL;
		size_t itemLength = 0;
		const unsigned char *next = ax_der_tlv(cursor, end, &itemTag, &itemContent, &itemLength);
		if (!next) {
			return -1;
		}
		if (itemTag == 0x04 && !found) {
			found = itemContent;
			foundSize = itemLength;
		} else if (itemTag == 0x30 && found && !size) {
			// compression SEQUENCE { algorithm, uncompressedSize }
			const unsigned char *scan = itemContent;
			const unsigned char *scanEnd = itemContent + itemLength;
			uint64_t values[2] = {0, 0};
			int seen = 0;
			while (scan < scanEnd && seen < 2) {
				unsigned char innerTag = 0;
				const unsigned char *innerContent = NULL;
				size_t innerLength = 0;
				const unsigned char *innerNext =
					ax_der_tlv(scan, scanEnd, &innerTag, &innerContent, &innerLength);
				if (!innerNext || innerTag != 0x02 || innerLength == 0 || innerLength > 8) {
					break;
				}
				uint64_t value = 0;
				for (size_t i = 0; i < innerLength; i++) {
					value = (value << 8) | innerContent[i];
				}
				values[seen++] = value;
				scan = innerNext;
			}
			if (seen == 2 && values[0] == 1) { // 1 == LZFSE
				size = values[1];
			}
		}
		cursor = next;
	}

	if (!found || foundSize == 0) {
		return -1;
	}
	*payload = found;
	*payloadSize = foundSize;
	*usize = size;
	return 0;
}

static unsigned char *ax_lzfse_decode(const unsigned char *payload, size_t payloadSize,
                                      uint64_t usize, size_t *outLength)
{
	unsigned char *out = NULL;
	if (usize > 0 && usize < AX_LZFSE_MAX_OUT) {
		// The container states the exact output size. img4lib's lzfse_reopen()
		// decodes into usize + 1 bytes and requires the result to be exactly
		// usize: the extra byte lets the decoder consume the end-of-stream
		// marker and distinguishes a complete decode from DST_FULL. Same here.
		out = malloc((size_t)usize + 1);
		if (!out) {
			return NULL;
		}
		size_t produced = lzfse_decode_buffer(out, (size_t)usize + 1, payload, payloadSize, NULL);
		if (produced == (size_t)usize) {
			*outLength = produced;
			return out;
		}
		ax_diag("LZFSE produced %zu bytes, container declares %llu", produced,
		        (unsigned long long)usize);
		free(out);
		return NULL;
	}

	// No usable size in the container: grow until the stream fits. A decoder
	// that cannot fit the output into the buffer returns 0, so 0 means "grow".
	size_t capacity = payloadSize * 4;
	out = malloc(capacity);
	while (out) {
		size_t produced = lzfse_decode_buffer(out, capacity, payload, payloadSize, NULL);
		if (produced > 0 && produced < capacity) {
			*outLength = produced;
			return out;
		}
		if (capacity >= AX_LZFSE_MAX_OUT) {
			break;
		}
		capacity *= 2;
		unsigned char *grown = realloc(out, capacity);
		if (!grown) {
			break;
		}
		out = grown;
	}
	free(out);
	return NULL;
}

int xpf_load_img4_direct(const char *path, void **outBuf, size_t *outSize)
{
	if (!path || !outBuf || !outSize) {
		return -1;
	}

	int fd = open(path, O_RDONLY);
	if (fd < 0) {
		ax_diag("cannot open %s (errno %d)", path, errno);
		return -1;
	}
	struct stat st;
	if (fstat(fd, &st) != 0 || st.st_size <= 0) {
		ax_diag("cannot size %s", path);
		close(fd);
		return -1;
	}
	size_t fileSize = (size_t)st.st_size;
	unsigned char *file = malloc(fileSize);
	if (!file) {
		ax_diag("cannot allocate %zu bytes for %s", fileSize, path);
		close(fd);
		return -1;
	}
	// read() may return short; loop until the whole file is in, and retry EINTR.
	size_t filled = 0;
	while (filled < fileSize) {
		ssize_t got = read(fd, file + filled, fileSize - filled);
		if (got > 0) {
			filled += (size_t)got;
			continue;
		}
		if (got < 0 && errno == EINTR) {
			continue;
		}
		break;
	}
	close(fd);
	if (filled != fileSize) {
		ax_diag("short read %s (%zu of %zu, errno %d)", path, filled, fileSize, errno);
		free(file);
		return -1;
	}

	const unsigned char *payload = NULL;
	size_t payloadSize = 0;
	uint64_t usize = 0;
	if (ax_im4p_extract(file, fileSize, &payload, &payloadSize, &usize) != 0) {
		ax_diag("%s is not an IM4P container", path);
		free(file);
		return -1;
	}

	size_t outLength = 0;
	unsigned char *out = NULL;
	if (payloadSize >= 4 && memcmp(payload, "bvx", 3) == 0) {
		out = ax_lzfse_decode(payload, payloadSize, usize, &outLength);
	} else {
		// Uncompressed payload: pass it through unchanged.
		out = malloc(payloadSize);
		if (out) {
			memcpy(out, payload, payloadSize);
			outLength = payloadSize;
		}
	}
	free(file);

	if (!out) {
		ax_diag("%s could not be decompressed", path);
		return -1;
	}
	if (!ax_is_macho(out, outLength)) {
		uint32_t magic = 0;
		memcpy(&magic, out, sizeof(magic));
		ax_diag("%s decoded to %zu bytes, magic %08x is not Mach-O", path, outLength, magic);
		free(out);
		return -1;
	}

	fprintf(stderr, "[i] im4p_direct: %s -> %zu byte Mach-O\n", path, outLength);
	snprintf(gDiagText, sizeof(gDiagText), "ok %s -> %zu bytes", path, outLength);
	*outBuf = out;
	*outSize = outLength;
	return 0;
}
