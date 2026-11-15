program test_render
    !! One frame with every primitive: the CPU renderer gives the expected
    !! pixels where they are exact; the Vulkan renderer, offscreen, agrees with
    !! the CPU renderer within rounding (where a GPU is present).
    use iso_c_binding, only: c_float
    use iso_fortran_env, only: int8
    use fortgfx_list
    use fortgfx_cpu
    use fortgfx_gpu
    implicit none
    integer, parameter :: W = 160, H = 120
    ! Largest per-channel difference GPU against CPU, and the share of pixels
    ! allowed above 2 levels (antialiased edges of curves).
    integer, parameter :: MAX_DIFF = 8
    real, parameter :: MAX_ROUGH = 0.01
    type(gfx_list_t) :: list
    type(gfx_cpu_t) :: cpu
    type(gfx_gpu_t) :: gpu
    integer(int8), allocatable :: tex(:, :, :), gpu_px(:, :, :)
    integer :: failures, checked, t_cpu, t_gpu, l_cpu, l_gpu, worst, rough
    real(c_float) :: layer(16, 3), view(12)
    character(len=256) :: need

    failures = 0
    checked = 0
    allocate (tex(4, 4, 4))
    call checker_texture(tex)
    layer(:, 1) = real([10.0, 10.0, 30.0, 20.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, &
        2.0, 1.0, 0.0], c_float)
    layer(:, 2) = real([20.0, 5.0, 6.0, 0.0, 0.0, 0.5, 0.0, 1.0, 0.0, 0.5, 0.0, 1.0, 0.0, 0.0, &
        2.0, 0.0], c_float)
    layer(:, 3) = real([5.0, 25.0, 4.0, 0.0, 0.9, 0.5, 0.1, 0.8, 0.9, 0.5, 0.1, 0.8, 0.0, 0.0, &
        2.0, 0.0], c_float)

    t_cpu = cpu_texture_create(cpu, 4, 4)
    call cpu_texture_update(cpu, t_cpu, 0, 0, tex)
    l_cpu = 1
    call cpu_layer_set(cpu, l_cpu, layer, 3)
    call build(list, t_cpu, l_cpu)
    call cpu_render(cpu, list)
    call check_cpu_pixels()

    call get_environment_variable("FORTGFX_REQUIRE_GPU", need)
    if (gpu_open_offscreen(gpu, W, H)) then
        write (*, '(a)') "GPU: " // gpu_device_name(gpu)
        t_gpu = gpu_texture_create(gpu, 4, 4)
        call gpu_texture_update(gpu, t_gpu, 0, 0, tex)
        l_gpu = 1
        call gpu_layer_set(gpu, l_gpu, layer, 3)
        call build(list, t_gpu, l_gpu)
        call check(gpu_render(gpu, list), "GPU renders")
        call gpu_read(gpu, gpu_px)
        worst = maxval(abs(u8(gpu_px) - u8(cpu%rgba)))
        rough = count(any(abs(u8(gpu_px) - u8(cpu%rgba)) > 2, dim=1))
        write (*, '(a, i0, a, i0, a)') "GPU against CPU: largest difference ", worst, ", ", &
            rough, " pixels above 2"
        call check(worst <= MAX_DIFF .and. rough <= MAX_ROUGH * W * H, &
            "GPU frame equals the CPU frame within rounding")
        call gpu_close(gpu)
        call check_uploads_between_frames()
    else
        write (*, '(a)') "no Vulkan device: the GPU comparison did not run"
        call check(len_trim(need) == 0, "a GPU is required (FORTGFX_REQUIRE_GPU)")
    end if
    write (*, '(a, i0, a, i0, a)') "render: ", checked, " checks, ", failures, " failures"
    if (failures > 0) error stop 1

contains

    subroutine check(ok, what)
        logical, intent(in) :: ok
        character(*), intent(in) :: what
        checked = checked + 1
        if (ok) return
        failures = failures + 1
        write (*, '(a)') "FAIL: " // what
    end subroutine check

    subroutine check_uploads_between_frames()
        !! Texture uploads made right after a frame is submitted, while the GPU
        !! may still copy that frame's uploads, arrive intact (a glyph atlas
        !! grows this way): 48 tiles prepared first, then one uploaded per frame
        !! with no other work between submitting and uploading.
        integer, parameter :: TS = 128, N = 48
        type(gfx_gpu_t) :: g
        type(gfx_cpu_t) :: c
        type(gfx_list_t) :: l
        integer(int8), allocatable :: tiles(:, :, :, :), px(:, :, :)
        integer :: tg, tc, k, x, y, side, v(4)
        side = 8 * TS
        if (.not. gpu_open_offscreen(g, side, side)) return
        tg = gpu_texture_create(g, side, side)
        tc = cpu_texture_create(c, side, side)
        allocate (tiles(4, TS, TS, N))
        do k = 1, N
            do y = 1, TS
                do x = 1, TS
                    v = [mod(x * k, 256), mod(y * 3 + k, 256), mod(x + y + 17 * k, 256), 255]
                    tiles(:, x, y, k) = int(v - 256 * merge(1, 0, v > 127), int8)
                end do
            end do
        end do
        call gfx_list_reset(l, side, side, [0.0, 0.0, 0.0, 1.0])
        call gfx_add_quad(l, [0, 0, side, side], tg, .false., reshape([0.0, 0.0, real(side), &
            0.0, real(side), real(side), 0.0, real(side)], [2, 4]), reshape([0.0, 0.0, 1.0, &
            0.0, 1.0, 1.0, 0.0, 1.0], [2, 4]), [1.0, 1.0, 1.0, 1.0])
        do k = 1, N
            x = mod(k - 1, 8) * TS
            y = ((k - 1) / 8) * TS
            call gpu_texture_update(g, tg, x, y, tiles(:, :, :, k))
            call cpu_texture_update(c, tc, x, y, tiles(:, :, :, k))
            if (.not. gpu_render(g, l)) exit
        end do
        call gpu_read(g, px)
        l%batches(1)%texture = tc
        call cpu_render(c, l)
        call check(all(px == c%rgba), "uploads between frames arrive intact")
        call gpu_close(g)
    end subroutine check_uploads_between_frames

    subroutine checker_texture(t)
        integer(int8), intent(out) :: t(4, 4, 4)
        integer :: x, y
        do y = 1, 4
            do x = 1, 4
                if (mod(x + y, 2) == 0) then
                    t(:, x, y) = int([-1, 0, 0, -1], int8) ! red, opaque
                else
                    t(:, x, y) = int([0, 0, -1, -128], int8) ! blue, half
                end if
            end do
        end do
    end subroutine checker_texture

    subroutine build(list, texture, layer_id)
        type(gfx_list_t), intent(inout) :: list
        integer, intent(in) :: texture, layer_id
        integer :: full(4)
        full = [0, 0, W, H]
        call gfx_list_reset(list, W, H, [0.75, 0.75, 0.75, 1.0])
        ! Plain, rounded with border, half-pixel border, checker.
        call gfx_add_shape(list, full, [4.0, 4.0, 30.0, 12.0], [0.0, 0.0, 0.5, 1.0], &
            [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0])
        call gfx_add_shape(list, full, [40.0, 4.0, 40.0, 24.0], [1.0, 1.0, 1.0, 1.0], &
            [0.1, 0.4, 0.8, 1.0], [6.0, 2.0, 0.0, 0.0])
        call gfx_add_shape(list, full, [90.0, 4.5, 30.0, 20.0], [1.0, 1.0, 0.0, 0.5], &
            [0.0, 0.0, 0.0, 1.0], [0.0, 1.5, 0.0, 0.0])
        call gfx_add_shape(list, full, [130.0, 4.0, 20.0, 20.0], [1.0, 1.0, 1.0, 1.0], &
            [0.0, 0.0, 0.0, 1.0], [0.0, 0.0, 0.0, 1.0])
        ! Clipped shapes: a line with a gradient and a disc, in world units.
        view = real([160.0, 120.0, 0.0, 0.0, 2.0, 10.0, 40.0, 2.0, 3.0, 1.0, 0.0, 0.0], &
            c_float)
        call gfx_add_shape(list, [5, 35, 70, 40], [0.0, 0.0, 40.0, 15.0], [1.0, 0.0, 0.0, 1.0], &
            [0.0, 0.0, 1.0, 1.0], [0.0, 3.0, 1.0, 0.0], view)
        call gfx_add_shape(list, [5, 35, 70, 40], [25.0, 5.0, 8.0, 0.0], [0.0, 0.6, 0.0, 0.7], &
            [0.0, 0.6, 0.0, 0.7], [0.0, 0.0, 2.0, 1.0], view)
        ! A retained layer under another view.
        view = real([160.0, 120.0, 0.0, 0.0, 1.0, 90.0, 40.0, 1.0, 2.0, 1.0, 0.0, 0.0], &
            c_float)
        call gfx_add_layer(list, full, layer_id, 3, view)
        ! Textured quads: the 4x4 texture enlarged, nearest and bilinear.
        call gfx_add_quad(list, full, texture, .false., reshape([10.0, 80.0, 42.0, 80.0, 42.0, &
            112.0, 10.0, 112.0], [2, 4]), reshape([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0], &
            [2, 4]), [1.0, 1.0, 1.0, 1.0])
        call gfx_add_quad(list, full, texture, .true., reshape([50.0, 80.0, 82.0, 80.0, 82.0, &
            112.0, 50.0, 112.0], [2, 4]), reshape([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0], &
            [2, 4]), [1.0, 1.0, 1.0, 0.8])
    end subroutine build

    subroutine check_cpu_pixels()
        ! Background, a plain fill, the border of the rounded box, the checker.
        integer :: c(3)
        call check(all(rgb(cpu%rgba, 2, 2) == [191, 191, 191]), "clear colour")
        call check(all(rgb(cpu%rgba, 10, 10) == [0, 0, 128]), "plain rectangle")
        call check(all(rgb(cpu%rgba, 60, 4) == [26, 102, 204]), "border of the rounded box")
        call check(all(rgb(cpu%rgba, 60, 15) == [255, 255, 255]), "inside of the rounded box")
        c = rgb(cpu%rgba, 41, 5)
        call check(c(1) > 26 .and. c(1) < 191, "antialiased rounded corner")
        call check(all(rgb(cpu%rgba, 130, 4) == [255, 255, 255]) .and. &
            all(rgb(cpu%rgba, 131, 4) == [0, 0, 0]), "checker pattern")
        c = rgb(cpu%rgba, 12, 82)
        call check(all(c == [255, 0, 0]) .or. all(c == [96, 96, 223]), "nearest texel colours")
        call check(all(rgb(cpu%rgba, 4, 40) == [191, 191, 191]), "clip keeps the line inside")
    end subroutine check_cpu_pixels

    function rgb(px, x, y) result(c)
        integer(int8), intent(in) :: px(:, :, :)
        integer, intent(in) :: x, y
        integer :: c(3)
        c = u8(px(1:3, x + 1, y + 1))
    end function rgb

    elemental integer function u8(b)
        integer(int8), intent(in) :: b
        u8 = iand(int(b), 255)
    end function u8

end program test_render
