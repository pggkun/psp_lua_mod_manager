TARGET = psp_lua_mod_manager_core
LUA_VERSION = 5.4.8
LUA_URL = https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
LUA_DIR = thirdparty/lua
DIST_DIR = build
.DEFAULT_GOAL := dist
OBJS = src/main.o \
	$(LUA_DIR)/src/lapi.o $(LUA_DIR)/src/lcode.o $(LUA_DIR)/src/lctype.o $(LUA_DIR)/src/ldebug.o \
	$(LUA_DIR)/src/ldo.o $(LUA_DIR)/src/ldump.o $(LUA_DIR)/src/lfunc.o $(LUA_DIR)/src/lgc.o \
	$(LUA_DIR)/src/llex.o $(LUA_DIR)/src/lmem.o $(LUA_DIR)/src/lobject.o $(LUA_DIR)/src/lopcodes.o \
	$(LUA_DIR)/src/lparser.o $(LUA_DIR)/src/lstate.o $(LUA_DIR)/src/lstring.o $(LUA_DIR)/src/ltable.o \
	$(LUA_DIR)/src/ltm.o $(LUA_DIR)/src/lundump.o $(LUA_DIR)/src/lvm.o $(LUA_DIR)/src/lzio.o \
	$(LUA_DIR)/src/lauxlib.o $(LUA_DIR)/src/lbaselib.o $(LUA_DIR)/src/lmathlib.o \
	$(LUA_DIR)/src/lstrlib.o $(LUA_DIR)/src/ltablib.o $(LUA_DIR)/src/lutf8lib.o
INCDIR = $(LUA_DIR)/src
CFLAGS = -O2 -G0 -Wall -Wextra -DLUA_USE_C89
LDFLAGS = -nostartfiles
LIBS = -lpspgu -lpspdisplay -lpspctrl
BUILD_PRX = 1
PRX_EXPORTS = exports.exp
PSPSDK := $(shell psp-config --pspsdk-path 2>/dev/null)
ifeq ($(PSPSDK),)
ifneq ($(MAKECMDGOALS),deps)
$(error PSPSDK not found)
endif
else
include $(PSPSDK)/lib/build.mak
endif

.PHONY: bundle dist bootstrap deps check-deps clean-overlay

bundle: dist

dist: check-deps all bootstrap
	mkdir -p $(DIST_DIR)
	cp bootstrap/psp_lua_mod_manager.prx $(DIST_DIR)/
	cp psp_lua_mod_manager_core.prx $(DIST_DIR)/
	cp scripts/main.lua $(DIST_DIR)/
	cp plugin.ini $(DIST_DIR)/

deps:
	@if [ ! -f "$(LUA_DIR)/src/lua.h" ]; then \
		mkdir -p thirdparty; \
		curl -fL "$(LUA_URL)" -o thirdparty/lua.tar.gz; \
		tar -xzf thirdparty/lua.tar.gz -C thirdparty; \
		mv "thirdparty/lua-$(LUA_VERSION)" "$(LUA_DIR)"; \
		rm thirdparty/lua.tar.gz; \
	fi

check-deps:
	@test -f "$(LUA_DIR)/src/lua.h" || { echo "Lua is missing. Run: make deps"; exit 1; }

bootstrap:
	$(MAKE) -C bootstrap

clean: clean-overlay

clean-overlay:
	$(MAKE) -C bootstrap clean
	rm -rf $(DIST_DIR)
	rm -f lua_overlay_core.prx lua_overlay_core.elf
	rm -f bootstrap/lua_overlay.prx bootstrap/lua_overlay.elf
