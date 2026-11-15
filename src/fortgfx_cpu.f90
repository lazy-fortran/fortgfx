module fortgfx_cpu
    !! The frame list drawn on the CPU into RGBA8, by the rules of the GPU
    !! shaders: fragments at pixel centres (top-left rule), the same distance
    !! functions, premultiplied blending into 8-bit unsigned normalised values
    !! (rounded after each blend), nearest or bilinear sampling clamped to the
    !! edge. It is the fallback without a GPU and the reference of the GPU tests.
    use iso_c_binding, only: c_float, c_int32_t
    use iso_fortran_env, only: int8
    use fortgfx_list
    implicit none
    private
    public :: gfx_cpu_t, cpu_render, cpu_texture_create, cpu_texture_update, &
        cpu_texture_release, cpu_layer_set, cpu_layer_release

    type :: cpu_texture_t
        integer :: width = 0, height = 0
        integer(int8), allocatable :: rgba(:, :, :)
    end type cpu_texture_t

    type :: cpu_layer_t
        integer :: count = 0
        real(c_float), allocatable :: shapes(:, :)
    end type cpu_layer_t

    type :: gfx_cpu_t
        integer :: width = 0, height = 0
        integer(int8), allocatable :: rgba(:, :, :) ! (4, width, height), the frame
        type(cpu_texture_t), allocatable :: textures(:)
        type(cpu_layer_t), allocatable :: layers(:)
    end type gfx_cpu_t

contains

    ! --- resources ----------------------------------------------------------------

    integer function cpu_texture_create(r, width, height) result(id)
        type(gfx_cpu_t), intent(inout) :: r
        integer, intent(in) :: width, height
        type(cpu_texture_t), allocatable :: grown(:)
        integer :: k
        if (.not. allocated(r%textures)) allocate (r%textures(16))
        id = 0
        do k = 1, size(r%textures)
            if (r%textures(k)%width == 0) then
                id = k
                exit
            end if
        end do
        if (id == 0) then
            id = size(r%textures) + 1
            allocate (grown(2 * size(r%textures)))
            grown(1:size(r%textures)) = r%textures
            call move_alloc(grown, r%textures)
        end if
        r%textures(id)%width = max(1, width)
        r%textures(id)%height = max(1, height)
        allocate (r%textures(id)%rgba(4, r%textures(id)%width, r%textures(id)%height))
        r%textures(id)%rgba = 0
    end function cpu_texture_create

    subroutine cpu_texture_update(r, id, x, y, rgba)
        !! Straight RGBA at (x, y) (from 0) of a texture.
        type(gfx_cpu_t), intent(inout) :: r
        integer, intent(in) :: id, x, y
        integer(int8), intent(in) :: rgba(:, :, :)
        r%textures(id)%rgba(:, x + 1:x + size(rgba, 2), y + 1:y + size(rgba, 3)) = rgba
    end subroutine cpu_texture_update

    subroutine cpu_texture_release(r, id)
        type(gfx_cpu_t), intent(inout) :: r
        integer, intent(in) :: id
        if (id < 1 .or. id > size(r%textures)) return
        r%textures(id)%width = 0
        r%textures(id)%height = 0
        if (allocated(r%textures(id)%rgba)) deallocate (r%textures(id)%rgba)
    end subroutine cpu_texture_release

    subroutine cpu_layer_set(r, id, shapes, count)
        type(gfx_cpu_t), intent(inout) :: r
        integer, intent(in) :: id, count
        real(c_float), intent(in) :: shapes(:, :)
        type(cpu_layer_t), allocatable :: grown(:)
        if (.not. allocated(r%layers)) allocate (r%layers(16))
        if (id > size(r%layers)) then
            allocate (grown(max(id, 2 * size(r%layers))))
            grown(1:size(r%layers)) = r%layers
            call move_alloc(grown, r%layers)
        end if
        r%layers(id)%count = count
        r%layers(id)%shapes = shapes(:, 1:count)
    end subroutine cpu_layer_set

    subroutine cpu_layer_release(r, id)
        type(gfx_cpu_t), intent(inout) :: r
        integer, intent(in) :: id
        if (.not. allocated(r%layers)) return
        if (id < 1 .or. id > size(r%layers)) return
        r%layers(id)%count = 0
        if (allocated(r%layers(id)%shapes)) deallocate (r%layers(id)%shapes)
    end subroutine cpu_layer_release

    ! --- drawing ------------------------------------------------------------------

    subroutine cpu_render(r, list)
        type(gfx_cpu_t), intent(inout) :: r
        type(gfx_list_t), intent(in) :: list
        integer :: b, k, c
        if (r%width /= list%width .or. r%height /= list%height .or. &
            .not. allocated(r%rgba)) then
            if (allocated(r%rgba)) deallocate (r%rgba)
            r%width = list%width
            r%height = list%height
            allocate (r%rgba(4, r%width, r%height))
        end if
        do c = 1, 4
            r%rgba(c, :, :) = unorm(list%clear(c))
        end do
        do b = 1, list%nbatches
            associate (bt => list%batches(b))
                if (bt%count <= 0 .or. bt%clip(3) <= 0 .or. bt%clip(4) <= 0) cycle
                select case (bt%kind)
                case (GFX_SHAPES)
                    do k = bt%first + 1, bt%first + bt%count
                        call draw_shape(r, list%shapes(:, k), bt%clip, bt%view)
                    end do
                case (GFX_LAYER)
                    if (.not. allocated(r%layers)) cycle
                    if (bt%layer > size(r%layers)) cycle
                    do k = 1, min(bt%count, r%layers(bt%layer)%count)
                        call draw_shape(r, r%layers(bt%layer)%shapes(:, k), bt%clip, bt%view)
                    end do
                case (GFX_TEXTURED)
                    do k = bt%first + 1, bt%first + bt%count, 3
                        call draw_triangle(r, list, list%idx(k:k + 2), bt%texture, bt%linear, &
                            bt%clip)
                    end do
                end select
            end associate
        end do
    end subroutine cpu_render

    subroutine draw_shape(r, s, clip, view)
        !! shape.vert's quad and shape.frag's coverage, per pixel.
        type(gfx_cpu_t), intent(inout) :: r
        real(c_float), intent(in) :: s(16), view(12)
        integer, intent(in) :: clip(4)
        real :: geo(4), fill(4), stroke(4), p(4), lo(2), hi(2), a(2), bb(2), c(2), d, rad
        real :: xf(4), extra(4)
        integer :: kind, x0, x1, y0, y1, x, y
        real :: px(2), out(4)
        geo = s(1:4)
        fill = s(5:8)
        stroke = s(9:12)
        p = s(13:16)
        xf = view(5:8)
        extra = view(9:12)
        kind = nint(p(3))
        select case (kind)
        case (GFX_RECT)
            lo = geo(1:2)
            hi = geo(1:2) + geo(3:4)
            if (p(1) > 0.0 .or. p(2) /= aint(p(2))) then
                lo = lo - 1.0
                hi = hi + 1.0
            end if
        case (GFX_LINE)
            a = xf(1) * geo(1:2) + xf(2:3)
            bb = xf(1) * geo(3:4) + xf(2:3)
            geo = [a, bb]
            rad = 0.5 * p(2) * merge(extra(2), 1.0, p(4) > 0.5) + 1.0
            p(2) = p(2) * merge(extra(2), 1.0, p(4) > 0.5)
            lo = min(a, bb) - rad
            hi = max(a, bb) + rad
        case default
            c = xf(1) * geo(1:2) + xf(2:3)
            d = max(geo(3) * merge(xf(4), extra(2), p(4) > 0.5), extra(1))
            geo = [c, 0.5 * d, 0.0]
            lo = c - 0.5 * d - 1.0
            hi = c + 0.5 * d + 1.0
        end select
        ! Pixels whose centres lie in [lo, hi), inside the clip and the target.
        x0 = max(int(ceiling(lo(1) - 0.5)), clip(1), 0)
        x1 = min(int(ceiling(hi(1) - 0.5)) - 1, clip(1) + clip(3) - 1, r%width - 1)
        y0 = max(int(ceiling(lo(2) - 0.5)), clip(2), 0)
        y1 = min(int(ceiling(hi(2) - 0.5)) - 1, clip(2) + clip(4) - 1, r%height - 1)
        do y = y0, y1
            do x = x0, x1
                px = [x + 0.5, y + 0.5]
                out = shade(kind, px, geo, fill, stroke, p, x, y)
                call blend(r, x, y, out)
            end do
        end do
    end subroutine draw_shape

    function shade(kind, px, geo, fill, stroke, p, ix, iy) result(o)
        !! shape.frag: premultiplied colour of one fragment.
        integer, intent(in) :: kind, ix, iy
        real, intent(in) :: px(2), geo(4), fill(4), stroke(4), p(4)
        real :: o(4), half(2), d, outer, inner, ab(2), t, r, bw
        select case (kind)
        case (GFX_RECT)
            if (p(4) > 0.5) then
                if (mod(ix + iy, 2) == 0) then
                    o = premul(fill, 1.0)
                else
                    o = premul(stroke, 1.0)
                end if
                return
            end if
            r = p(1)
            bw = p(2)
            if (r <= 0.0 .and. bw <= 0.0) then
                o = premul(fill, 1.0)
                return
            end if
            half = 0.5 * geo(3:4)
            d = round_box(px - (geo(1:2) + half), half, min(r, min(half(1), half(2))))
            outer = clamp01(0.5 - d)
            if (bw > 0.0) then
                inner = clamp01(0.5 - (d + bw))
            else
                inner = outer
            end if
            o = premul(fill, inner) + premul(stroke, outer - inner)
        case (GFX_LINE)
            ab = geo(3:4) - geo(1:2)
            t = clamp01(dot_product(px - geo(1:2), ab) / max(dot_product(ab, ab), 1e-6))
            d = norm2(px - geo(1:2) - t * ab) - 0.5 * p(2)
            o = premul(fill + (stroke - fill) * t, clamp01(0.5 - d))
        case default
            d = norm2(px - geo(1:2)) - geo(3)
            o = premul(fill, clamp01(0.5 - d))
        end select
    end function shade

    pure real function round_box(q, half, r)
        real, intent(in) :: q(2), half(2), r
        real :: d(2)
        d = abs(q) - half + r
        round_box = norm2(max(d, 0.0)) + min(max(d(1), d(2)), 0.0) - r
    end function round_box

    pure function premul(c, coverage) result(o)
        real, intent(in) :: c(4), coverage
        real :: o(4)
        o = [c(1:3) * c(4), c(4)] * coverage
    end function premul

    pure real function clamp01(v)
        real, intent(in) :: v
        clamp01 = max(0.0, min(1.0, v))
    end function clamp01

    subroutine draw_triangle(r, list, tri, texture, linear, clip)
        !! textured.frag over one triangle: colour times texel, premultiplied.
        type(gfx_cpu_t), intent(inout) :: r
        type(gfx_list_t), intent(in) :: list
        integer(c_int32_t), intent(in) :: tri(3)
        integer, intent(in) :: texture, clip(4)
        logical, intent(in) :: linear
        real :: v(2, 3), uv(2, 3), col(4), area, w(3), px(2), tex(4), c(4)
        integer :: x0, x1, y0, y1, x, y, k
        do k = 1, 3
            v(:, k) = list%verts(1:2, tri(k) + 1)
            uv(:, k) = list%verts(3:4, tri(k) + 1)
        end do
        col = list%verts(5:8, tri(1) + 1)
        area = edge(v(:, 1), v(:, 2), v(:, 3))
        if (area == 0.0) return
        x0 = max(int(ceiling(minval(v(1, :)) - 0.5)), clip(1), 0)
        x1 = min(int(ceiling(maxval(v(1, :)) - 0.5)) - 1, clip(1) + clip(3) - 1, r%width - 1)
        y0 = max(int(ceiling(minval(v(2, :)) - 0.5)), clip(2), 0)
        y1 = min(int(ceiling(maxval(v(2, :)) - 0.5)) - 1, clip(2) + clip(4) - 1, r%height - 1)
        do y = y0, y1
            do x = x0, x1
                px = [x + 0.5, y + 0.5]
                w(1) = edge(v(:, 2), v(:, 3), px) / area
                w(2) = edge(v(:, 3), v(:, 1), px) / area
                w(3) = edge(v(:, 1), v(:, 2), px) / area
                if (.not. inside(w, v, area)) cycle
                tex = sample(r, texture, w(1) * uv(:, 1) + w(2) * uv(:, 2) + w(3) * uv(:, 3), &
                    linear)
                c = col * tex
                call blend(r, x, y, [c(1:3) * c(4), c(4)])
            end do
        end do
    end subroutine draw_triangle

    pure real function edge(a, b, p)
        real, intent(in) :: a(2), b(2), p(2)
        edge = (b(1) - a(1)) * (p(2) - a(2)) - (b(2) - a(2)) * (p(1) - a(1))
    end function edge

    pure logical function inside(w, v, area)
        !! Barycentric inside test with the top-left rule on shared edges.
        real, intent(in) :: w(3), v(2, 3), area
        integer :: k, a, b
        real :: e(2)
        inside = .true.
        do k = 1, 3
            if (w(k) > 0.0) cycle
            if (w(k) < 0.0) then
                inside = .false.
                return
            end if
            ! On the edge opposite vertex k: owned when it is a top or left edge.
            a = mod(k, 3) + 1
            b = mod(k + 1, 3) + 1
            e = v(:, b) - v(:, a)
            if (area < 0.0) e = -e
            if (.not. ((e(2) == 0.0 .and. e(1) > 0.0) .or. e(2) < 0.0)) then
                inside = .false.
                return
            end if
        end do
    end function inside

    function sample(r, id, uv, linear) result(c)
        !! Straight RGBA 0..1 at uv, clamped to the edge.
        type(gfx_cpu_t), intent(in) :: r
        integer, intent(in) :: id
        real, intent(in) :: uv(2)
        logical, intent(in) :: linear
        real :: c(4), fx, fy, tx, ty
        integer :: w, h, i0, j0, i1, j1
        c = [1.0, 1.0, 1.0, 1.0]
        if (.not. allocated(r%textures)) return
        if (id < 1 .or. id > size(r%textures)) return
        w = r%textures(id)%width
        h = r%textures(id)%height
        if (w == 0) return
        if (.not. linear) then
            i0 = min(w - 1, max(0, int(floor(uv(1) * w))))
            j0 = min(h - 1, max(0, int(floor(uv(2) * h))))
            c = texel(i0, j0)
            return
        end if
        fx = uv(1) * w - 0.5
        fy = uv(2) * h - 0.5
        i0 = int(floor(fx))
        j0 = int(floor(fy))
        tx = fx - i0
        ty = fy - j0
        i1 = min(w - 1, max(0, i0 + 1))
        j1 = min(h - 1, max(0, j0 + 1))
        i0 = min(w - 1, max(0, i0))
        j0 = min(h - 1, max(0, j0))
        c = (1 - ty) * ((1 - tx) * texel(i0, j0) + tx * texel(i1, j0)) + &
            ty * ((1 - tx) * texel(i0, j1) + tx * texel(i1, j1))
    contains
        function texel(i, j) result(t)
            integer, intent(in) :: i, j
            real :: t(4)
            t = real(iand(int(r%textures(id)%rgba(:, i + 1, j + 1)), 255)) / 255.0
        end function texel
    end function sample

    subroutine blend(r, x, y, src)
        !! Premultiplied source over the destination: one, one minus source alpha.
        type(gfx_cpu_t), intent(inout) :: r
        integer, intent(in) :: x, y
        real, intent(in) :: src(4)
        real :: dst(4)
        dst = real(iand(int(r%rgba(:, x + 1, y + 1)), 255)) / 255.0
        r%rgba(:, x + 1, y + 1) = unorm(src + dst * (1.0 - src(4)))
    end subroutine blend

    elemental integer(int8) function unorm(v)
        !! A value 0..1 as an 8-bit unsigned normalised number (round to nearest).
        real, intent(in) :: v
        integer :: i
        i = nint(max(0.0, min(1.0, v)) * 255.0)
        unorm = int(i - 256 * (i / 128), int8)
    end function unorm

end module fortgfx_cpu
