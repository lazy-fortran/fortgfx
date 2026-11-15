module fortgfx_list
    !! One frame as batches: instanced shapes (rounded rectangles with border or
    !! checker pattern, line segments, discs), textured triangles (glyphs and
    !! images) and retained shape layers, each batch with a clip rectangle and a
    !! view. Every renderer (Vulkan, CPU) draws the same list the same way.
    use iso_c_binding, only: c_float, c_int32_t
    implicit none
    private
    public :: gfx_list_t, gfx_batch_t, gfx_list_reset, gfx_add_shape, gfx_add_quad, &
        gfx_add_layer, gfx_open_batch

    integer, parameter, public :: GFX_SHAPE_FLOATS = 16, GFX_VERTEX_FLOATS = 8
    integer, parameter, public :: GFX_SHAPES = 1, GFX_TEXTURED = 2, GFX_LAYER = 3
    ! Shape kinds (p(3) of a shape): rectangle, line segment, disc.
    integer, parameter, public :: GFX_RECT = 0, GFX_LINE = 1, GFX_DISC = 2

    type :: gfx_batch_t
        integer :: kind = 0, first = 0, count = 0
        integer :: texture = 0 ! textured: texture id
        logical :: linear = .false. ! textured: bilinear instead of nearest sampling
        integer :: layer = 0 ! layer: layer id
        integer :: clip(4) = 0 ! x, y, width, height in pixels
        ! viewport (w, h, -, -), world-to-pixel transform (scale, x, y, size scale),
        ! extra (minimum disc diameter in pixels, pixel size scale, -, -)
        real(c_float) :: view(12) = 0
    end type gfx_batch_t

    type :: gfx_list_t
        integer :: width = 1, height = 1
        real(c_float) :: clear(4) = [0, 0, 0, 1]
        real(c_float), allocatable :: shapes(:, :) ! (16, n): geo, fill, stroke, p
        real(c_float), allocatable :: verts(:, :) ! (8, n): x, y, u, v, r, g, b, a
        integer(c_int32_t), allocatable :: idx(:) ! zero-based vertex indices
        type(gfx_batch_t), allocatable :: batches(:)
        integer :: nshapes = 0, nverts = 0, nidx = 0, nbatches = 0
    end type gfx_list_t

contains

    subroutine gfx_list_reset(list, width, height, clear)
        type(gfx_list_t), intent(inout) :: list
        integer, intent(in) :: width, height
        real, intent(in) :: clear(4)
        list%width = max(1, width)
        list%height = max(1, height)
        list%clear = real(clear, c_float)
        list%nshapes = 0
        list%nverts = 0
        list%nidx = 0
        list%nbatches = 0
        if (.not. allocated(list%shapes)) allocate (list%shapes(GFX_SHAPE_FLOATS, 1024))
        if (.not. allocated(list%verts)) allocate (list%verts(GFX_VERTEX_FLOATS, 4096))
        if (.not. allocated(list%idx)) allocate (list%idx(6144))
        if (.not. allocated(list%batches)) allocate (list%batches(64))
    end subroutine gfx_list_reset

    function default_view(list) result(v)
        type(gfx_list_t), intent(in) :: list
        real(c_float) :: v(12)
        v = real([real(list%width), real(list%height), 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, &
            1.0, 0.0, 0.0], c_float)
    end function default_view

    integer function gfx_open_batch(list, kind, clip, texture, linear, view) result(b)
        !! The current batch when it can take the drawing, else a new one.
        type(gfx_list_t), intent(inout) :: list
        integer, intent(in) :: kind, clip(4)
        integer, intent(in), optional :: texture
        logical, intent(in), optional :: linear
        real(c_float), intent(in), optional :: view(12)
        type(gfx_batch_t), allocatable :: grown(:)
        type(gfx_batch_t) :: want
        want%kind = kind
        want%clip = clip
        if (present(texture)) want%texture = texture
        if (present(linear)) want%linear = linear
        if (present(view)) then
            want%view = view
        else
            want%view = default_view(list)
        end if
        b = list%nbatches
        if (b > 0 .and. kind /= GFX_LAYER) then
            associate (last => list%batches(b))
                if (last%kind == kind .and. all(last%clip == clip) .and. &
                    last%texture == want%texture .and. (last%linear .eqv. want%linear) .and. &
                    all(last%view == want%view)) return
            end associate
        end if
        if (list%nbatches == size(list%batches)) then
            allocate (grown(2 * size(list%batches)))
            grown(1:list%nbatches) = list%batches(1:list%nbatches)
            call move_alloc(grown, list%batches)
        end if
        b = list%nbatches + 1
        list%nbatches = b
        list%batches(b) = want
        if (kind == GFX_SHAPES) list%batches(b)%first = list%nshapes
        if (kind == GFX_TEXTURED) list%batches(b)%first = list%nidx
    end function gfx_open_batch

    subroutine gfx_add_shape(list, clip, geo, fill, stroke, p, view)
        !! One shape: geo (x, y, w, h) for a rectangle, (x0, y0, x1, y1) for a
        !! line, (x, y, diameter, -) for a disc; fill and stroke premultiplied
        !! later from straight RGBA 0..1; p = (radius, border width, kind, flag).
        type(gfx_list_t), intent(inout) :: list
        integer, intent(in) :: clip(4)
        real, intent(in) :: geo(4), fill(4), stroke(4), p(4)
        real(c_float), intent(in), optional :: view(12)
        real(c_float), allocatable :: grown(:, :)
        integer :: b
        b = gfx_open_batch(list, GFX_SHAPES, clip, view=view)
        if (list%nshapes == size(list%shapes, 2)) then
            allocate (grown(GFX_SHAPE_FLOATS, 2 * size(list%shapes, 2)))
            grown(:, 1:list%nshapes) = list%shapes(:, 1:list%nshapes)
            call move_alloc(grown, list%shapes)
        end if
        list%nshapes = list%nshapes + 1
        list%shapes(:, list%nshapes) = real([geo, fill, stroke, p], c_float)
        list%batches(b)%count = list%batches(b)%count + 1
    end subroutine gfx_add_shape

    subroutine gfx_add_quad(list, clip, texture, linear, xy, uv, colour)
        !! Two triangles with corners xy(:, 1..4), clockwise from the top left.
        type(gfx_list_t), intent(inout) :: list
        integer, intent(in) :: clip(4), texture
        logical, intent(in) :: linear
        real, intent(in) :: xy(2, 4), uv(2, 4), colour(4)
        real(c_float), allocatable :: gv(:, :)
        integer(c_int32_t), allocatable :: gi(:)
        integer :: b, k, base
        b = gfx_open_batch(list, GFX_TEXTURED, clip, texture, linear)
        if (list%nverts + 4 > size(list%verts, 2)) then
            allocate (gv(GFX_VERTEX_FLOATS, 2 * size(list%verts, 2)))
            gv(:, 1:list%nverts) = list%verts(:, 1:list%nverts)
            call move_alloc(gv, list%verts)
        end if
        if (list%nidx + 6 > size(list%idx)) then
            allocate (gi(2 * size(list%idx)))
            gi(1:list%nidx) = list%idx(1:list%nidx)
            call move_alloc(gi, list%idx)
        end if
        base = list%nverts
        do k = 1, 4
            list%verts(:, base + k) = real([xy(:, k), uv(:, k), colour], c_float)
        end do
        list%idx(list%nidx + 1:list%nidx + 6) = int(base + [0, 1, 2, 0, 2, 3], c_int32_t)
        list%nverts = base + 4
        list%nidx = list%nidx + 6
        list%batches(b)%count = list%batches(b)%count + 6
    end subroutine gfx_add_quad

    subroutine gfx_add_layer(list, clip, layer, count, view)
        !! A retained layer's shapes (count of them), drawn with its own view.
        type(gfx_list_t), intent(inout) :: list
        integer, intent(in) :: clip(4), layer, count
        real(c_float), intent(in) :: view(12)
        integer :: b
        b = gfx_open_batch(list, GFX_LAYER, clip, view=view)
        list%batches(b)%layer = layer
        list%batches(b)%count = count
    end subroutine gfx_add_layer

end module fortgfx_list
