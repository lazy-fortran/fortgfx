/* The optional Vulkan loader has different names and loader APIs. */
#ifdef _WIN32
#include <windows.h>
void *fortgfx_dlopen(const char *name, int flags) { (void)flags; return (void *)LoadLibraryA(name); }
void *fortgfx_dlsym(void *lib, const char *name) { return (void *)GetProcAddress((HMODULE)lib, name); }
#else
#include <dlfcn.h>
void *fortgfx_dlopen(const char *name, int flags) { return dlopen(name, flags); }
void *fortgfx_dlsym(void *lib, const char *name) { return dlsym(lib, name); }
#endif
