#include <pspkernel.h>
#include <pspmodulemgr.h>
#include <pspctrl.h>
#include <pspiofilemgr.h>
#include <pspsysmem_kernel.h>
#include <string.h>

PSP_MODULE_INFO("PSP Lua Mod Manager Boot", PSP_MODULE_KERNEL, 1, 0);

#define CORE_MS0 "ms0:/seplugins/psp_lua_mod_manager/psp_lua_mod_manager_core.prx"
#define CORE_MS0_ROOT "ms0:/seplugins/psp_lua_mod_manager_core.prx"
#define CORE_EF0 "ef0:/seplugins/psp_lua_mod_manager/psp_lua_mod_manager_core.prx"
#define CORE_EF0_ROOT "ef0:/seplugins/psp_lua_mod_manager_core.prx"
#define ERROR_LOG "ms0:/seplugins/psp_lua_mod_manager/load_error.txt"
#define REQUIRED_FREE_BLOCK (900 * 1024)

static char *append_text(char *out, const char *text)
{
    while (*text)
        *out++ = *text++;
    return out;
}

static char *append_uint(char *out, unsigned int value)
{
    char reversed[10];
    int count = 0;
    do
    {
        reversed[count++] = (char)('0' + value % 10);
        value /= 10;
    } while (value && count < 10);
    while (count)
        *out++ = reversed[--count];
    return out;
}

static char *append_hex(char *out, unsigned int value)
{
    static const char digits[] = "0123456789ABCDEF";
    int shift;
    out = append_text(out, "0x");
    for (shift = 28; shift >= 0; shift -= 4)
        *out++ = digits[(value >> shift) & 15];
    return out;
}

static void write_error(const char *stage, int error, unsigned int largest)
{
    char line[160];
    char *out = line;
    SceUID fd;
    out = append_text(out, "stage=");
    out = append_text(out, stage);
    out = append_text(out, " error=");
    out = append_hex(out, (unsigned int)error);
    out = append_text(out, " max_block_bytes=");
    out = append_uint(out, largest);
    out = append_text(out, " max_block_kb=");
    out = append_uint(out, largest / 1024);
    *out++ = '\n';
    fd = sceIoOpen(ERROR_LOG, PSP_O_WRONLY | PSP_O_CREAT | PSP_O_APPEND, 0777);
    if (fd >= 0)
    {
        sceIoWrite(fd, line, (unsigned int)(out - line));
        sceIoClose(fd);
    }
}

static void log_directory(const char *path)
{
    SceUID directory = sceIoDopen(path);
    SceIoDirent entry;
    if (directory < 0)
    {
        write_error("dopen", directory, 0);
        return;
    }
    memset(&entry, 0, sizeof(entry));
    while (sceIoDread(directory, &entry) > 0)
    {
        char line[320];
        char *out = line;
        SceUID fd;
        out = append_text(out, "file=");
        out = append_text(out, entry.d_name);
        out = append_text(out, " size=");
        out = append_uint(out, (unsigned int)entry.d_stat.st_size);
        *out++ = '\n';
        fd = sceIoOpen(ERROR_LOG, PSP_O_WRONLY | PSP_O_CREAT | PSP_O_APPEND, 0777);
        if (fd >= 0)
        {
            sceIoWrite(fd, line, (unsigned int)(out - line));
            sceIoClose(fd);
        }
        memset(&entry, 0, sizeof(entry));
    }
    sceIoDclose(directory);
}

static SceUID load_user_module(const char *path)
{
    SceKernelLMOption option;
    memset(&option, 0, sizeof(option));
    option.size = sizeof(option);
    option.mpidtext = 2;
    option.mpiddata = 2;
    option.position = 0;
    option.access = 1;
    return sceKernelLoadModule(path, 0, &option);
}

static int loader_thread(SceSize args, void *argp)
{
    int held = 0;
    (void)args;
    (void)argp;
    for (;;)
    {
        SceCtrlData pad;
        if (sceCtrlPeekBufferPositive(&pad, 1) > 0)
        {
            int combo = (pad.Buttons & (PSP_CTRL_LTRIGGER | PSP_CTRL_RTRIGGER | PSP_CTRL_SELECT)) == (PSP_CTRL_LTRIGGER | PSP_CTRL_RTRIGGER | PSP_CTRL_SELECT);
            if (combo && !held)
            {
                unsigned int largest = sceKernelPartitionMaxFreeMemSize(2);
                if (largest >= REQUIRED_FREE_BLOCK)
                {
                    int status = 0;
                    SceUID module = load_user_module(CORE_MS0);
                    if (module < 0)
                    {
                        write_error("load_ms0", module, largest);
                        log_directory("ms0:/seplugins/psp_lua_mod_manager");
                        module = load_user_module(CORE_MS0_ROOT);
                    }
                    if (module < 0)
                    {
                        write_error("load_ms0_root", module, largest);
                        log_directory("ms0:/seplugins");
                        module = load_user_module(CORE_EF0);
                    }
                    if (module < 0)
                    {
                        write_error("load_ef0", module, largest);
                        module = load_user_module(CORE_EF0_ROOT);
                        if (module < 0)
                            write_error("load_ef0_root", module, largest);
                    }
                    if (module >= 0)
                    {
                        int result = sceKernelStartModule(module, 0, NULL, &status, NULL);
                        if (result >= 0)
                        {
                            sceKernelSelfStopUnloadModule(1, 0, NULL);
                            return 0;
                        }
                        write_error("start", result, largest);
                    }
                }
                else
                    write_error("memory", (int)0x80020190, largest);
            }
            held = combo;
        }
        sceKernelDelayThread(10000);
    }
}

int module_start(SceSize args, void *argp)
{
    SceUID thread;
    (void)args;
    (void)argp;
    thread = sceKernelCreateThread("psp_lua_mod_manager_loader", loader_thread, 32, 16 * 1024, 0, NULL);
    if (thread < 0)
        return thread;
    return sceKernelStartThread(thread, 0, NULL);
}
