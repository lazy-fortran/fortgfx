# Probe build until fortgfx becomes an fpm package.
BUILD ?= /mnt/storage/build/fortgfx-triangle
FC = gfortran
FFLAGS ?= -O2 -g -Wall -Wno-unused-dummy-argument -fimplicit-none

$(BUILD)/triangle: vk.f90 xcb.f90 triangle.f90 $(BUILD)/triangle.vert.spv $(BUILD)/triangle.frag.spv
	$(FC) $(FFLAGS) -J$(BUILD) vk.f90 xcb.f90 triangle.f90 -lxcb -o $@

$(BUILD)/%.spv: % | $(BUILD)
	glslc $< -o $@

$(BUILD):
	mkdir -p $@

run: $(BUILD)/triangle
	$(BUILD)/triangle
