//
//  im4p_direct.h
//  AX: direct IM4P reader, used by xpf_load_img4() as a fallback.
//
#ifndef im4p_direct_h
#define im4p_direct_h

#include <stddef.h>

// Longest path XPF accepts for the kernelcache / SPTM / TXM arguments.
#ifndef XPF_PATH_MAX
#define XPF_PATH_MAX 4096
#endif

// Non-zero when the buffer starts with a Mach-O (thin or fat) magic. Every
// image XPF takes through xpf_load_img4() (SPTM, TXM) is a Mach-O, so the
// result of any container reader is only accepted when this holds.
int ax_is_macho(const void *buf, size_t size);

// Read an IM4P container from disk, decode its LZFSE payload with the LZFSE
// implementation linked into this library, and return the Mach-O image.
// Allocates *outBuf on success (caller frees); returns 0 on success, -1
// otherwise. Writes its own reason to stderr and to the diag slot below.
int xpf_load_img4_direct(const char *path, void **outBuf, size_t *outSize);

// Record why the last xpf_load_img4() attempt failed. The caller (the App) reads
// this back so the reason reaches the bracketed log line: stderr alone is easy
// to lose when the log is filtered, and img4lib keeps quiet by design.
void xpf_img4_diag(const char *text);
void xpf_img4_diag_append(const char *text);
const char *xpf_img4_last_diag(void);

#endif /* im4p_direct_h */
