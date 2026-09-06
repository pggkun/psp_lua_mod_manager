TARGET = psp_lua_mod_manager
OBJS = main.o
CFLAGS = -Os -G0 -Wall -fno-pic -mno-check-zero-division
LDFLAGS = -nostartfiles
BUILD_PRX = 1
USE_KERNEL_LIBS = 1
PRX_EXPORTS = exports.exp

PSPSDK := $(shell psp-config --pspsdk-path 2>/dev/null)
ifeq ($(PSPSDK),)
$(error PSPSDK not found)
endif
include $(PSPSDK)/lib/build.mak
