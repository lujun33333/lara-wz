CC = clang

CHOMA_DYLIB_PATH ?= 0
CHOMA_PATH       ?= external/ChOma
CFLAGS            = -O2 -framework Foundation -I$(CHOMA_PATH)/include
CFLAGS_MACOS      = $(CFLAGS)
CFLAGS_IOS        = $(CFLAGS) -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=15.0 -arch arm64 -arch arm64e
LDFLAGS           = -lcompression

all: output/macos/libxpf.dylib output/ios/libxpf.dylib output/macos/xpf_test output/ios/xpf_test

ifneq ($(CHOMA_DYLIB_PATH), 0)
CHOMA_DEP = 
LDFLAGS  += -L$(CHOMA_DYLIB_PATH) -lchoma
else
CHOMA_DEP = $(CHOMA_PATH)/src/*.c
endif

IMG4LIB_CFLAGS = -DUSE_COMMONCRYPTO -DUSE_LIBCOMPRESSION -DiOS10 -DDER_MULTIBYTE_TAGS=1 -D__unused="__attribute__((unused))" -DDER_TAG_SIZE=8 -Iexternal/img4lib -Iexternal/img4lib/lzfse/src -Wno-variadic-macros -Wno-multichar -Wno-four-char-constants -Wno-unused-parameter
IMG4LIB_LDFLAGS = -framework Security
# 上游假设系统里装了 lzfse；这里改为直接编译 img4lib 自带的 lzfse 源码
# （external/img4lib/lzfse/src），否则 src/im4p_direct.c 找不到 lzfse.h。
LZFSE_DEP = $(wildcard external/img4lib/lzfse/src/*.c)
IMG4LIB_DEP = $(filter-out external/img4lib/libvfs/vfs_lzvn.c, $(wildcard external/img4lib/lzss.c external/img4lib/libvfs/*.c external/img4lib/libDER/*.c)) $(LZFSE_DEP)

CFLAGS += $(IMG4LIB_CFLAGS)
LDFLAGS += $(IMG4LIB_LDFLAGS)

output/macos/libxpf.dylib: $(wildcard src/*.c) $(CHOMA_DEP) $(IMG4LIB_DEP)
	@mkdir -p $(shell dirname $@)
	$(CC) $(CFLAGS_MACOS) $(LDFLAGS) -dynamiclib -install_name @loader_path/libxpf.dylib -o $@ $^

output/ios/libxpf.dylib: $(wildcard src/*.c) $(CHOMA_DEP) $(IMG4LIB_DEP)
	@mkdir -p $(shell dirname $@)
	$(CC) $(CFLAGS_IOS) $(LDFLAGS) -dynamiclib -install_name @loader_path/libxpf.dylib -o $@ $^
	ldid -S $@

output/macos/xpf_test: $(wildcard src/cli/*.c)
	@mkdir -p $(shell dirname $@)
	$(CC) $(CFLAGS_MACOS) $(LDFLAGS) -L$(shell dirname $@) -lxpf -o $@ $^

output/ios/xpf_test: $(wildcard src/cli/*.c)
	@mkdir -p $(shell dirname $@)
	$(CC) $(CFLAGS_IOS) $(LDFLAGS) -L$(shell dirname $@) -lxpf -o $@ $^
	@ldid -S $@

clean:
	@rm -rf output