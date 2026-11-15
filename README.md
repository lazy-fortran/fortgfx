# fortgpu

One Fortran GPU API over Vulkan (Linux, Windows) and Metal (macOS), with the
browser served through FortUI's JavaScript host. Vulkan is opened at run time,
so a program without a usable GPU falls back instead of failing to start.

Status: probe. `example/triangle` draws a spinning colour triangle in an X11
window through libxcb and Vulkan 1.3 dynamic rendering, in Fortran only.

```sh
make -C example/triangle run    # needs gfortran, glslc, libxcb and a Vulkan driver
```

Escape, q or closing the window ends it.
