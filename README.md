# fortgfx

Graphics for the lazy-fortran ecosystem, in Fortran: one scene of 2D paths,
text, images and 3D meshes, drawn by

- Vulkan (Linux, Windows) and Metal (macOS), loaded at run time, so a program
  without a usable GPU falls back instead of failing to start;
- a CPU rasteriser with a depth buffer, for windows without a GPU, PNG
  files, printing and tests;
- terminal cells: the CPU raster as Unicode sextants, quadrants, half blocks
  or braille, or as ASCII shading where the locale is not UTF-8, in 24-bit, 256,
  16 or no colours, with text written as real characters on top; sixel or
  kitty images where the terminal has them.

FortUI, fortplot and fortterm draw through it. OpenGL and WebGPU are
deliberately not used.

Status: probe. `example/triangle` draws a spinning colour triangle in an X11
window through libxcb and Vulkan 1.3 dynamic rendering, in Fortran only.

```sh
make -C example/triangle run    # needs gfortran, glslc, libxcb and a Vulkan driver
```

Escape, q or closing the window ends it.
