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

The frame is a list of batches (`fortgfx_list`): instanced shapes (rounded
rectangles with border or checker pattern, line segments with a colour
gradient, discs), textured triangles (glyphs, images) and retained shape
layers, each with a clip rectangle and a view. `fortgfx_gpu` draws it with
Vulkan 1.3 into an X11 window or an offscreen image; `fortgfx_cpu` draws it
into memory by the same rules (fragments at pixel centres, the same distance
functions, premultiplied blending in 8-bit values).

Status: the GPU and CPU renderers draw the same frames; the terminal target
and Metal follow. `example/triangle` draws a spinning colour triangle in an X11
window, the first step.

```sh
make -C example/triangle run    # needs gfortran, glslc, libxcb and a Vulkan driver
```

Escape, q or closing the window ends it.

## Tests

```sh
fo test        # or: fpm test
```

`test_render` draws one frame with every primitive on the CPU, checks exact
pixels, and draws it again with Vulkan offscreen: both frames agree within one
level per channel (on an NVIDIA GPU and on Mesa's lavapipe). Without a Vulkan
device the GPU half is reported as not run, unless `FORTGFX_REQUIRE_GPU` is
set, as in CI. `test_vulkan_layout` checks every Vulkan structure's size
against `vulkan_core.h`.
