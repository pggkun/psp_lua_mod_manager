#include <pspkernel.h>
#include <pspdisplay.h>
#include <pspctrl.h>
#include <psputils.h>
#include <pspiofilemgr.h>
#include <pspgu.h>
#include <pspsysmem.h>
#include <stdint.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

PSP_MODULE_INFO("PSP Lua Mod Manager", PSP_MODULE_USER, 1, 0);

#define PPSSPP_SCRIPT_PATH "ms0:/PSP/PLUGINS/psp_lua_mod_manager/main.lua"
#define PSP_SCRIPT_PATH "ms0:/seplugins/psp_lua_mod_manager/main.lua"
#define USER_RAM_START 0x08800000u
#define USER_RAM_END 0x0A000000u

static volatile int running = 1;
static lua_State *vm;
static void *framebuffer;
static int stride, pixel_format;
static int script_status;
static char script_error[96];
static unsigned int buttons_current, buttons_previous;

#define MOD_BIN_MAX_SIZE (16 * 1024)
#define MAX_MOD_HOOKS 128

typedef struct
{
   char owner[24];
   uintptr_t address;
   uint32_t original;
} ModHook;

static unsigned char mod_file_buffer[MOD_BIN_MAX_SIZE];
static ModHook mod_hooks[MAX_MOD_HOOKS];
static int mod_hook_count;

#define MAX_VERTICES 4096
typedef struct
{
   uint32_t color;
   short x, y, z;
} OverlayVertex;

static OverlayVertex vertices[MAX_VERTICES] __attribute__((aligned(16)));
static unsigned int gu_list[4096] __attribute__((aligned(16)));
static int vertex_count;

/* Newlib references _exit through abort(), even when that path is never used.
   In a plugin, it must terminate only the thread, never the game. */
void _exit(int status)
{
   sceKernelExitDeleteThread(status);
   for (;;)
   {
   }
}

#define LUA_HEAP_SIZE (128 * 1024)
#define SCRIPT_MAX_SIZE (16 * 1024)
typedef struct HeapBlock
{
   size_t size;
   int free;
   struct HeapBlock *next;
} HeapBlock;

static unsigned char lua_heap[LUA_HEAP_SIZE] __attribute__((aligned(16)));
static unsigned char script_buffer[SCRIPT_MAX_SIZE];
static HeapBlock *heap_head;

static void heap_init(void)
{
   heap_head = (HeapBlock *)lua_heap;
   heap_head->size = LUA_HEAP_SIZE - sizeof(HeapBlock);
   heap_head->free = 1;
   heap_head->next = NULL;
}

static void heap_free(void *p)
{
   HeapBlock *b, *n;
   if (!p)
      return;
   b = (HeapBlock *)p - 1;
   b->free = 1;
   for (b = heap_head; b && b->next; b = b->next)
   {
      n = b->next;
      if (b->free && n->free)
      {
         b->size += sizeof(HeapBlock) + n->size;
         b->next = n->next;
         b = heap_head;
      }
   }
}

static void *heap_alloc(size_t size)
{
   HeapBlock *b, *split;
   size = (size + 15) & ~(size_t)15;
   for (b = heap_head; b; b = b->next)
      if (b->free && b->size >= size)
      {
         if (b->size >= size + sizeof(HeapBlock) + 16)
         {
            split = (HeapBlock *)((unsigned char *)(b + 1) + size);
            split->size = b->size - size - sizeof(HeapBlock);
            split->free = 1;
            split->next = b->next;
            b->next = split;
            b->size = size;
         }
         b->free = 0;
         return b + 1;
      }
   return NULL;
}

static void *lua_allocator(void *ud, void *ptr, size_t old_size, size_t new_size)
{
   void *n;
   (void)ud;
   if (new_size == 0)
   {
      heap_free(ptr);
      return NULL;
   }
   if (!ptr)
      return heap_alloc(new_size);
   if (new_size <= old_size)
      return ptr;
   n = heap_alloc(new_size);
   if (!n)
      return NULL;
   memcpy(n, ptr, old_size);
   heap_free(ptr);
   return n;
}

static const char glyph_chars[] = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:-._/[]+";
static const unsigned char glyphs[][5] = {
    {0, 0, 0, 0, 0}, {0x3E, 0x41, 0x41, 0x41, 0x3E}, {0, 0x42, 0x7F, 0x40, 0}, {0x62, 0x51, 0x49, 0x49, 0x46}, {0x22, 0x41, 0x49, 0x49, 0x36}, {0x18, 0x14, 0x12, 0x7F, 0x10}, {0x27, 0x45, 0x45, 0x45, 0x39}, {0x3E, 0x49, 0x49, 0x49, 0x32}, {1, 1, 0x79, 5, 3}, {0x36, 0x49, 0x49, 0x49, 0x36}, {0x26, 0x49, 0x49, 0x49, 0x3E}, {0x7E, 0x11, 0x11, 0x11, 0x7E}, {0x7F, 0x49, 0x49, 0x49, 0x36}, {0x3E, 0x41, 0x41, 0x41, 0x22}, {0x7F, 0x41, 0x41, 0x22, 0x1C}, {0x7F, 0x49, 0x49, 0x49, 0x41}, {0x7F, 9, 9, 9, 1}, {0x3E, 0x41, 0x49, 0x49, 0x7A}, {0x7F, 8, 8, 8, 0x7F}, {0, 0x41, 0x7F, 0x41, 0}, {0x20, 0x40, 0x41, 0x3F, 1}, {0x7F, 8, 0x14, 0x22, 0x41}, {0x7F, 0x40, 0x40, 0x40, 0x40}, {0x7F, 2, 0x0C, 2, 0x7F}, {0x7F, 4, 8, 0x10, 0x7F}, {0x3E, 0x41, 0x41, 0x41, 0x3E}, {0x7F, 9, 9, 9, 6}, {0x3E, 0x41, 0x51, 0x21, 0x5E}, {0x7F, 9, 0x19, 0x29, 0x46}, {0x46, 0x49, 0x49, 0x49, 0x31}, {1, 1, 0x7F, 1, 1}, {0x3F, 0x40, 0x40, 0x40, 0x3F}, {0x1F, 0x20, 0x40, 0x20, 0x1F}, {0x3F, 0x40, 0x38, 0x40, 0x3F}, {0x63, 0x14, 8, 0x14, 0x63}, {7, 8, 0x70, 8, 7}, {0x61, 0x51, 0x49, 0x45, 0x43}, {0, 0x36, 0x36, 0, 0}, {8, 8, 8, 8, 8}, {0, 0x60, 0x60, 0, 0}, {0x40, 0x40, 0x40, 0x40, 0x40}, {0x20, 0x10, 8, 4, 2}, {0x7F, 0x41, 0x41, 0, 0}, {0, 0, 0x41, 0x41, 0x7F}, {8, 8, 0x3E, 8, 8}};

static uint32_t rgba(unsigned r, unsigned g, unsigned b, unsigned a)
{
   return r | (g << 8) | (b << 16) | (a << 24);
}

static void push_rect(int x, int y, int w, int h, uint32_t c)
{
   OverlayVertex *a, *b;
   if (w <= 0 || h <= 0 || vertex_count + 2 > MAX_VERTICES)
      return;
   a = &vertices[vertex_count++];
   b = &vertices[vertex_count++];
   a->color = c;
   a->x = (short)x;
   a->y = (short)y;
   a->z = 0;
   b->color = c;
   b->x = (short)(x + w);
   b->y = (short)(y + h);
   b->z = 0;
}

static void pixel(int x, int y, uint32_t c)
{
   if (x < 0 || x >= 480 || y < 0 || y >= 272)
      return;
   push_rect(x, y, 1, 1, c);
}

static int api_rect(lua_State *s)
{
   int x = luaL_checkinteger(s, 1), y = luaL_checkinteger(s, 2), w = luaL_checkinteger(s, 3), h = luaL_checkinteger(s, 4);
   uint32_t c = rgba(luaL_optinteger(s, 5, 255), luaL_optinteger(s, 6, 255), luaL_optinteger(s, 7, 255), luaL_optinteger(s, 8, 255));
   push_rect(x, y, w, h, c);
   return 0;
}

static const unsigned char *glyph(char ch)
{
   const char *p;
   if (ch >= 'a' && ch <= 'z')
      ch -= 32;
   p = strchr(glyph_chars, ch);
   return p ? glyphs[p - glyph_chars] : glyphs[0];
}

static void draw_text(const char *t, int x, int y, int scale, uint32_t c)
{
   int cx, cy, xx, yy;
   for (; *t; t++, x += 6 * scale)
   {
      const unsigned char *g = glyph(*t);
      for (cx = 0; cx < 5; cx++)
         for (cy = 0; cy < 7; cy++)
            if (g[cx] & (1 << cy))
               for (yy = 0; yy < scale; yy++)
                  for (xx = 0; xx < scale; xx++)
                     pixel(x + cx * scale + xx, y + cy * scale + yy, c);
   }
}

static int api_text(lua_State *s)
{
   const char *t = luaL_checkstring(s, 1);
   int x = luaL_checkinteger(s, 2), y = luaL_checkinteger(s, 3), scale = luaL_optinteger(s, 4, 1);
   uint32_t c = rgba(luaL_optinteger(s, 5, 255), luaL_optinteger(s, 6, 255), luaL_optinteger(s, 7, 255), luaL_optinteger(s, 8, 255));
   draw_text(t, x, y, scale, c);
   return 0;
}

static uintptr_t address(lua_State *s, int arg, size_t size)
{
   uintptr_t a = (uintptr_t)luaL_checkinteger(s, arg);
   luaL_argcheck(s, a >= USER_RAM_START && a + size <= USER_RAM_END, arg, "address outside game RAM");
   return a;
}

#define READ_API(name, type)                                             \
   static int name(lua_State *s)                                         \
   {                                                                     \
      lua_pushinteger(s, *(volatile type *)address(s, 1, sizeof(type))); \
      return 1;                                                          \
   }
#define WRITE_API(name, type)                                                        \
   static int name(lua_State *s)                                                     \
   {                                                                                 \
      *(volatile type *)address(s, 1, sizeof(type)) = (type)luaL_checkinteger(s, 2); \
      return 0;                                                                      \
   }

READ_API(api_read8, uint8_t)
READ_API(api_read16, uint16_t) READ_API(api_read32, uint32_t)
    WRITE_API(api_write8, uint8_t) WRITE_API(api_write16, uint16_t) WRITE_API(api_write32, uint32_t) static int mod_path_allowed(const char *path) { return path && !strncmp(path, "ms0:/mods/", 10) && strstr(path, "..") == NULL; }

static void sync_code(void *start, unsigned int size)
{
   sceKernelDcacheWritebackInvalidateRange(start, size);
   sceKernelIcacheInvalidateRange(start, size);
}

static int api_memory_dump(lua_State *s)
{
   const char *path = luaL_checkstring(s, 1);
   uintptr_t start = (uintptr_t)luaL_checkinteger(s, 2);
   size_t size = (size_t)luaL_checkinteger(s, 3), written = 0;
   SceUID fd;
   luaL_argcheck(s, mod_path_allowed(path), 1, "dump must be under ms0:/mods and cannot contain ..");
   luaL_argcheck(s, size > 0 && size <= USER_RAM_END - USER_RAM_START, 3, "invalid dump size");
   address(s, 2, size);
   fd = sceIoOpen(path, PSP_O_WRONLY | PSP_O_CREAT | PSP_O_TRUNC, 0777);
   if (fd < 0)
      return luaL_error(s, "could not create %s: 0x%08X", path, (unsigned int)fd);
   while (written < size)
   {
      unsigned int chunk = (unsigned int)(size - written);
      int result;
      if (chunk > MOD_BIN_MAX_SIZE)
         chunk = MOD_BIN_MAX_SIZE;
      result = sceIoWrite(fd, (const void *)(start + written), chunk);
      if (result != (int)chunk)
      {
         sceIoClose(fd);
         return luaL_error(s, "dump failed at %d: 0x%08X", (int)written, (unsigned int)result);
      }
      written += chunk;
   }
   sceIoClose(fd);
   lua_pushinteger(s, (lua_Integer)written);
   return 1;
}

static int api_mod_load_bin(lua_State *s)
{
   const char *path = luaL_checkstring(s, 1);
   uintptr_t destination = address(s, 2, 1);
   SceUID fd;
   int length, read_length;
   luaL_argcheck(s, mod_path_allowed(path), 1, "file must be under ms0:/mods and cannot contain ..");
   fd = sceIoOpen(path, PSP_O_RDONLY, 0);
   if (fd < 0)
      return luaL_error(s, "could not open %s: 0x%08X", path, (unsigned int)fd);
   length = sceIoLseek32(fd, 0, PSP_SEEK_END);
   sceIoLseek32(fd, 0, PSP_SEEK_SET);
   if (length <= 0 || length > MOD_BIN_MAX_SIZE)
   {
      sceIoClose(fd);
      return luaL_error(s, "invalid/oversized binary: %d", length);
   }
   address(s, 2, (size_t)length);
   read_length = sceIoRead(fd, mod_file_buffer, (unsigned int)length);
   sceIoClose(fd);
   if (read_length != length)
      return luaL_error(s, "incomplete read: %d/%d", read_length, length);
   memcpy((void *)destination, mod_file_buffer, (size_t)length);
   sync_code((void *)destination, (unsigned int)length);
   lua_pushinteger(s, length);
   return 1;
}

static int api_mod_load_lua(lua_State *s)
{
   const char *path = luaL_checkstring(s, 1);
   SceUID fd;
   int length, read_length, result;
   luaL_argcheck(s, mod_path_allowed(path), 1, "script must be under ms0:/mods and cannot contain ..");
   fd = sceIoOpen(path, PSP_O_RDONLY, 0);
   if (fd < 0)
      return luaL_error(s, "could not open %s: 0x%08X", path, (unsigned int)fd);
   length = sceIoLseek32(fd, 0, PSP_SEEK_END);
   sceIoLseek32(fd, 0, PSP_SEEK_SET);
   if (length <= 0 || length > MOD_BIN_MAX_SIZE)
   {
      sceIoClose(fd);
      return luaL_error(s, "invalid/oversized Lua script: %d", length);
   }
   read_length = sceIoRead(fd, mod_file_buffer, (unsigned int)length);
   sceIoClose(fd);
   if (read_length != length)
      return luaL_error(s, "incomplete read: %d/%d", read_length, length);
   result = luaL_loadbuffer(s, (const char *)mod_file_buffer, (size_t)length, path);
   if (result != LUA_OK)
      return lua_error(s);
   return 1;
}

static int api_mod_list(lua_State *s)
{
   SceUID directory = sceIoDopen("ms0:/mods");
   SceIoDirent entry;
   int index = 1;
   lua_newtable(s);
   if (directory < 0)
      return 1;
   memset(&entry, 0, sizeof(entry));
   while (sceIoDread(directory, &entry) > 0)
   {
      if (entry.d_name[0] != '.' && FIO_S_ISDIR(entry.d_stat.st_mode))
      {
         char path[320];
         SceIoStat status;
         strcpy(path, "ms0:/mods/");
         strncat(path, entry.d_name, sizeof(path) - strlen(path) - 1);
         strncat(path, "/mod.lua", sizeof(path) - strlen(path) - 1);
         if (sceIoGetstat(path, &status) >= 0 && !FIO_S_ISDIR(status.st_mode))
         {
            lua_pushstring(s, entry.d_name);
            lua_rawseti(s, -2, index++);
         }
      }
      memset(&entry, 0, sizeof(entry));
   }
   sceIoDclose(directory);
   return 1;
}

static void state_path(lua_State *s, const char *game_id, char *path)
{
   size_t i, length = strlen(game_id);
   luaL_argcheck(s, length > 0 && length <= 16, 1, "invalid game ID");
   for (i = 0; i < length; i++)
      luaL_argcheck(s, (game_id[i] >= 'A' && game_id[i] <= 'Z') ||
                          (game_id[i] >= '0' && game_id[i] <= '9') || game_id[i] == '-' || game_id[i] == '_',
                    1, "invalid game ID");
   strcpy(path, "ms0:/mods/.psp_lua_mod_manager_");
   strcat(path, game_id);
   strcat(path, ".cfg");
}

static int api_mod_load_state(lua_State *s)
{
   const char *game_id = luaL_checkstring(s, 1);
   char path[64];
   SceUID fd;
   int length;
   state_path(s, game_id, path);
   fd = sceIoOpen(path, PSP_O_RDONLY, 0);
   if (fd < 0)
   {
      lua_pushliteral(s, "");
      return 1;
   }
   length = sceIoRead(fd, mod_file_buffer, MOD_BIN_MAX_SIZE);
   sceIoClose(fd);
   if (length < 0)
      return luaL_error(s, "could not read state: 0x%08X", (unsigned int)length);
   lua_pushlstring(s, (const char *)mod_file_buffer, (size_t)length);
   return 1;
}

static int api_mod_save_state(lua_State *s)
{
   const char *game_id = luaL_checkstring(s, 1);
   size_t length;
   const char *data = luaL_checklstring(s, 2, &length);
   char path[64];
   SceUID fd;
   int written;
   luaL_argcheck(s, length <= MOD_BIN_MAX_SIZE, 2, "state is too large");
   state_path(s, game_id, path);
   fd = sceIoOpen(path, PSP_O_WRONLY | PSP_O_CREAT | PSP_O_TRUNC, 0777);
   if (fd < 0)
      return luaL_error(s, "could not create state: 0x%08X", (unsigned int)fd);
   written = sceIoWrite(fd, data, (unsigned int)length);
   sceIoClose(fd);
   if (written != (int)length)
      return luaL_error(s, "could not write state: %d/%d", written, (int)length);
   return 0;
}

static int api_mod_hook32(lua_State *s)
{
   const char *owner = luaL_checkstring(s, 1);
   uintptr_t a = address(s, 2, 4);
   uint32_t value = (uint32_t)luaL_checkinteger(s, 3);
   int i;
   luaL_argcheck(s, strlen(owner) > 0 && strlen(owner) < sizeof(mod_hooks[0].owner), 1, "invalid mod ID");
   for (i = 0; i < mod_hook_count; i++)
      if (mod_hooks[i].address == a && !strcmp(mod_hooks[i].owner, owner))
         break;
   if (i == mod_hook_count)
   {
      if (mod_hook_count >= MAX_MOD_HOOKS)
         return luaL_error(s, "hook limit reached");
      strcpy(mod_hooks[i].owner, owner);
      mod_hooks[i].address = a;
      mod_hooks[i].original = (uint32_t)luaL_optinteger(s, 4, *(volatile uint32_t *)a);
      mod_hook_count++;
   }
   *(volatile uint32_t *)a = value;
   sync_code((void *)a, 4);
   return 0;
}

static int api_mod_disable(lua_State *s)
{
   const char *owner = luaL_checkstring(s, 1);
   int i;
   for (i = mod_hook_count - 1; i >= 0; i--)
      if (!strcmp(mod_hooks[i].owner, owner))
      {
         *(volatile uint32_t *)mod_hooks[i].address = mod_hooks[i].original;
         sync_code((void *)mod_hooks[i].address, 4);
         mod_hooks[i] = mod_hooks[--mod_hook_count];
      }
   return 0;
}

static int api_mod_active(lua_State *s)
{
   const char *owner = luaL_checkstring(s, 1);
   int i;
   for (i = 0; i < mod_hook_count; i++)
      if (!strcmp(mod_hooks[i].owner, owner))
      {
         lua_pushboolean(s, 1);
         return 1;
      }
   lua_pushboolean(s, 0);
   return 1;
}

static int api_game_id(lua_State *s)
{
   SceUID fd;
   int length, i;
   fd = sceIoOpen("disc0:/PSP_GAME/PARAM.SFO", PSP_O_RDONLY, 0);
   if (fd < 0)
   {
      lua_pushnil(s);
      return 1;
   }
   length = sceIoRead(fd, mod_file_buffer, MOD_BIN_MAX_SIZE);
   sceIoClose(fd);
   for (i = 0; i + 10 <= length; i++)
   {
      const unsigned char *id = mod_file_buffer + i;
      int dashed = id[4] == '-';
      int digit = dashed ? 5 : 4;
      char normalized[10];
      if ((id[0] != 'U' && id[0] != 'N') ||
          id[1] < 'A' || id[1] > 'Z' || id[2] < 'A' || id[2] > 'Z' || id[3] < 'A' || id[3] > 'Z' ||
          id[digit] < '0' || id[digit] > '9' || id[digit + 1] < '0' || id[digit + 1] > '9' ||
          id[digit + 2] < '0' || id[digit + 2] > '9' || id[digit + 3] < '0' || id[digit + 3] > '9' ||
          id[digit + 4] < '0' || id[digit + 4] > '9')
         continue;
      memcpy(normalized, id, 4);
      memcpy(normalized + 4, id + digit, 5);
      normalized[9] = 0;
      lua_pushstring(s, normalized);
      return 1;
   }
   lua_pushnil(s);
   return 1;
}
static const luaL_Reg overlay_api[] = {{"rect", api_rect}, {"text", api_text}, {NULL, NULL}};

static const luaL_Reg memory_api[] = {{"read8", api_read8}, {"read16", api_read16}, {"read32", api_read32}, 
                                       {"write8", api_write8}, {"write16", api_write16}, {"write32", api_write32}, 
                                       {"dump", api_memory_dump}, {NULL, NULL}};

static const luaL_Reg mods_api[] = {{"list", api_mod_list}, {"load_state", api_mod_load_state}, {"save_state", api_mod_save_state},
                                    {"load_lua", api_mod_load_lua}, {"load_bin", api_mod_load_bin}, {"hook32", api_mod_hook32}, 
                                    {"disable", api_mod_disable}, {"is_active", api_mod_active}, {NULL, NULL}};

static unsigned int button_mask(const char *name)
{
   if (!strcmp(name, "L"))
      return PSP_CTRL_LTRIGGER;
   if (!strcmp(name, "R"))
      return PSP_CTRL_RTRIGGER;
   if (!strcmp(name, "UP"))
      return PSP_CTRL_UP;
   if (!strcmp(name, "DOWN"))
      return PSP_CTRL_DOWN;
   if (!strcmp(name, "LEFT"))
      return PSP_CTRL_LEFT;
   if (!strcmp(name, "RIGHT"))
      return PSP_CTRL_RIGHT;
   if (!strcmp(name, "X") || !strcmp(name, "CROSS"))
      return PSP_CTRL_CROSS;
   if (!strcmp(name, "O") || !strcmp(name, "CIRCLE"))
      return PSP_CTRL_CIRCLE;
   if (!strcmp(name, "TRIANGLE"))
      return PSP_CTRL_TRIANGLE;
   if (!strcmp(name, "START"))
      return PSP_CTRL_START;
   if (!strcmp(name, "SELECT"))
      return PSP_CTRL_SELECT;
   return 0;
}

static int api_button_down(lua_State *s)
{
   unsigned int mask = button_mask(luaL_checkstring(s, 1));
   lua_pushboolean(s, mask && (buttons_current & mask));
   return 1;
}

static int api_button_pressed(lua_State *s)
{
   unsigned int mask = button_mask(luaL_checkstring(s, 1));
   lua_pushboolean(s, mask && (buttons_current & mask) && !(buttons_previous & mask));
   return 1;
}
static const luaL_Reg input_api[] = {{"down", api_button_down}, {"pressed", api_button_pressed}, {NULL, NULL}};

static int api_free_memory(lua_State *s)
{
   lua_pushinteger(s, (lua_Integer)sceKernelTotalFreeMemSize());
   lua_pushinteger(s, (lua_Integer)sceKernelMaxFreeMemSize());
   return 2;
}

static int api_system_time(lua_State *s)
{
   lua_pushinteger(s, (lua_Integer)(sceKernelGetSystemTimeLow() / 1000));
   return 1;
}
static const luaL_Reg system_api[] = {{"free_memory", api_free_memory}, {"game_id", api_game_id}, {"time", api_system_time}, {NULL, NULL}};

static int load_script(void)
{
   SceUID fd;
   int length;
   lua_State *n;
   if (vm)
   {
      lua_close(vm);
      vm = NULL;
   }
   heap_init();
   n = lua_newstate(lua_allocator, NULL);
   if (!n)
   {
      strcpy(script_error, "NOT ENOUGH MEMORY FOR LUA");
      script_status = -1;
      return -1;
   }
   luaL_requiref(n, "_G", luaopen_base, 1);
   lua_pop(n, 1);
   luaL_requiref(n, LUA_TABLIBNAME, luaopen_table, 1);
   lua_pop(n, 1);
   luaL_requiref(n, LUA_STRLIBNAME, luaopen_string, 1);
   lua_pop(n, 1);
   luaL_requiref(n, LUA_MATHLIBNAME, luaopen_math, 1);
   lua_pop(n, 1);
   luaL_requiref(n, LUA_UTF8LIBNAME, luaopen_utf8, 1);
   lua_pop(n, 1);
   luaL_newlib(n, overlay_api);
   lua_setglobal(n, "overlay");
   luaL_newlib(n, memory_api);
   lua_setglobal(n, "memory");
   luaL_newlib(n, mods_api);
   lua_setglobal(n, "mods");
   luaL_newlib(n, input_api);
   lua_setglobal(n, "input");
   luaL_newlib(n, system_api);
   lua_setglobal(n, "system");
   fd = sceIoOpen(PPSSPP_SCRIPT_PATH, PSP_O_RDONLY, 0);
   if (fd < 0)
      fd = sceIoOpen(PSP_SCRIPT_PATH, PSP_O_RDONLY, 0);
   if (fd < 0)
   {
      strcpy(script_error, "MAIN.LUA NOT FOUND");
      script_status = -1;
      lua_close(n);
      return -1;
   }
   length = sceIoRead(fd, script_buffer, SCRIPT_MAX_SIZE);
   sceIoClose(fd);
   if (length <= 0 || length == SCRIPT_MAX_SIZE)
   {
      strcpy(script_error, "MAIN.LUA EMPTY OR TOO LARGE");
      script_status = -1;
      lua_close(n);
      return -1;
   }
   if (luaL_loadbuffer(n, (const char *)script_buffer, (size_t)length, "main.lua") != LUA_OK || lua_pcall(n, 0, 0, 0) != LUA_OK)
   {
      const char *e = lua_tostring(n, -1);
      strncpy(script_error, e ? e : "ERROR IN MAIN.LUA", sizeof(script_error) - 1);
      script_error[sizeof(script_error) - 1] = 0;
      script_status = -1;
      lua_close(n);
      return -1;
   }
   vm = n;
   script_status = 1;
   script_error[0] = 0;
   return 0;
}

static void call_draw(void)
{
   if (!vm)
      return;
   lua_getglobal(vm, "draw");
   if (lua_isfunction(vm, -1))
   {
      if (lua_pcall(vm, 0, 0, 0) != LUA_OK)
      {
         const char *e = lua_tostring(vm, -1);
         strncpy(script_error, e ? e : "ERROR IN DRAW", sizeof(script_error) - 1);
         script_error[sizeof(script_error) - 1] = 0;
         script_status = -2;
         lua_pop(vm, 1);
      }
   }
   else
      lua_pop(vm, 1);
}

static void render_overlay(void *target, int target_stride, int target_format)
{
   if (!target || vertex_count == 0)
      return;
   sceKernelDcacheWritebackRange(vertices, (unsigned int)(vertex_count * sizeof(OverlayVertex)));
   sceGuStart(GU_DIRECT, gu_list);
   sceGuDrawBufferList(target_format, (void *)((uintptr_t)target & 0x001fffff), target_stride);
   sceGuOffset(2048 - 240, 2048 - 136);
   sceGuViewport(2048, 2048, 480, 272);
   sceGuEnable(GU_SCISSOR_TEST);
   sceGuScissor(0, 0, 480, 272);
   sceGuDisable(GU_DEPTH_TEST);
   sceGuDisable(GU_TEXTURE_2D);
   sceGuDisable(GU_CULL_FACE);
   sceGuEnable(GU_BLEND);
   sceGuBlendFunc(GU_ADD, GU_SRC_ALPHA, GU_ONE_MINUS_SRC_ALPHA, 0, 0);
   sceGuDrawArray(GU_SPRITES, GU_COLOR_8888 | GU_VERTEX_16BIT | GU_TRANSFORM_2D, vertex_count, NULL, vertices);
   sceGuFinish();
   sceGuSync(0, 0);
}

static int overlay_thread(SceSize args, void *argp)
{
   (void)args;
   (void)argp;
   load_script();
   int held = 0;
   while (running)
   {
      SceCtrlData pad;
      void *next_framebuffer = NULL;
      int next_stride = 0, next_format = 0;
      sceDisplayWaitVblankStart();
      sceKernelDelayThread(12000);
      sceDisplayGetFrameBuf(&framebuffer, &stride, &pixel_format, PSP_DISPLAY_SETBUF_IMMEDIATE);
      sceDisplayGetFrameBuf(&next_framebuffer, &next_stride, &next_format, PSP_DISPLAY_SETBUF_NEXTFRAME);
      sceCtrlPeekBufferPositive(&pad, 1);
      buttons_previous = buttons_current;
      buttons_current = pad.Buttons;
      int combo = (pad.Buttons & (PSP_CTRL_START | PSP_CTRL_SELECT)) == (PSP_CTRL_START | PSP_CTRL_SELECT);
      if (combo && !held)
         load_script();
      held = combo;
      vertex_count = 0;
      call_draw();
      if (script_status < 0)
      {
         draw_text("LUA ERROR", 408, 262, 1, rgba(255, 70, 80, 255));
         draw_text(script_error, 8, 250, 1, rgba(255, 70, 70, 255));
      }
      render_overlay(framebuffer, stride, pixel_format);
      if (next_framebuffer && next_framebuffer != framebuffer)
         render_overlay(next_framebuffer, next_stride, next_format);
   }
   if (vm)
   {
      lua_close(vm);
      vm = NULL;
   }
   sceKernelExitDeleteThread(0);
   return 0;
}

int module_start(SceSize args, void *argp)
{
   SceUID thread;
   (void)args;
   (void)argp;
   running = 1;
   thread = sceKernelCreateThread("psp_lua_mod_manager", overlay_thread, 0x18, 128 * 1024, PSP_THREAD_ATTR_USER, NULL);
   if (thread < 0)
      return thread;
   return sceKernelStartThread(thread, 0, NULL);
}

int module_stop(SceSize args, void *argp)
{
   (void)args;
   (void)argp;
   running = 0;
   return 0;
}
