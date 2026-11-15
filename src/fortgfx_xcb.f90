module fortgfx_xcb
    !! The few libxcb calls an X11 window needs, bound directly.
    use iso_c_binding
    implicit none
    private
    public :: xcb_window_t, window_open, window_poll, window_close

    integer, parameter, public :: EV_NONE = 0, EV_QUIT = 1, EV_RESIZE = 2

    type, bind(C) :: cookie_t
        integer(c_int) :: sequence
    end type

    type, bind(C) :: screen_iterator_t
        type(c_ptr) :: data
        integer(c_int) :: rem, index
    end type

    type, bind(C) :: screen_t
        integer(c_int32_t) :: root, default_colormap, white_pixel, black_pixel, input_masks
        integer(c_int16_t) :: width, height, width_mm, height_mm, min_maps, max_maps
        integer(c_int32_t) :: root_visual
    end type

    type :: xcb_window_t
        type(c_ptr) :: conn = c_null_ptr
        integer(c_int32_t) :: id = 0, delete_atom = 0
        integer :: width = 0, height = 0
    end type

    interface
        type(c_ptr) function xcb_connect(name, screen) bind(C)
            import :: c_ptr, c_int
            type(c_ptr), value :: name
            integer(c_int), intent(out) :: screen
        end function
        integer(c_int) function xcb_connection_has_error(c) bind(C)
            import :: c_ptr, c_int
            type(c_ptr), value :: c
        end function
        type(c_ptr) function xcb_get_setup(c) bind(C)
            import :: c_ptr
            type(c_ptr), value :: c
        end function
        type(screen_iterator_t) function xcb_setup_roots_iterator(setup) bind(C)
            import :: c_ptr, screen_iterator_t
            type(c_ptr), value :: setup
        end function
        integer(c_int32_t) function xcb_generate_id(c) bind(C)
            import :: c_ptr, c_int32_t
            type(c_ptr), value :: c
        end function
        type(cookie_t) function xcb_create_window(c, depth, wid, parent, x, y, w, h, border, &
                klass, visual, mask, values) bind(C)
            import :: c_ptr, c_int8_t, c_int16_t, c_int32_t, cookie_t
            type(c_ptr), value :: c
            integer(c_int8_t), value :: depth
            integer(c_int32_t), value :: wid, parent, visual, mask
            integer(c_int16_t), value :: x, y, w, h, border, klass
            integer(c_int32_t), intent(in) :: values(*)
        end function
        type(cookie_t) function xcb_map_window(c, w) bind(C)
            import :: c_ptr, c_int32_t, cookie_t
            type(c_ptr), value :: c
            integer(c_int32_t), value :: w
        end function
        type(cookie_t) function xcb_change_property(c, mode, w, prop, typ, fmt, n, data) bind(C)
            import :: c_ptr, c_int8_t, c_int32_t, cookie_t
            type(c_ptr), value :: c, data
            integer(c_int8_t), value :: mode, fmt
            integer(c_int32_t), value :: w, prop, typ, n
        end function
        type(cookie_t) function xcb_intern_atom(c, only_if_exists, n, name) bind(C)
            import :: c_ptr, c_int8_t, c_int16_t, c_char, cookie_t
            type(c_ptr), value :: c
            integer(c_int8_t), value :: only_if_exists
            integer(c_int16_t), value :: n
            character(kind=c_char), intent(in) :: name(*)
        end function
        type(c_ptr) function xcb_intern_atom_reply(c, cookie, err) bind(C)
            import :: c_ptr, cookie_t
            type(c_ptr), value :: c, err
            type(cookie_t), value :: cookie
        end function
        integer(c_int) function xcb_flush(c) bind(C)
            import :: c_ptr, c_int
            type(c_ptr), value :: c
        end function
        type(c_ptr) function xcb_poll_for_event(c) bind(C)
            import :: c_ptr
            type(c_ptr), value :: c
        end function
        subroutine xcb_disconnect(c) bind(C)
            import :: c_ptr
            type(c_ptr), value :: c
        end subroutine
        subroutine c_free(p) bind(C, name="free")
            import :: c_ptr
            type(c_ptr), value :: p
        end subroutine
    end interface

contains

    function window_open(title, width, height) result(win)
        character(*), intent(in) :: title
        integer, intent(in) :: width, height
        type(xcb_window_t) :: win
        type(screen_iterator_t) :: it
        type(screen_t), pointer :: scr
        type(cookie_t) :: ck
        integer(c_int) :: nscreen
        integer(c_int32_t), target :: protocols, values(2), delete_atom
        character(len=len(title), kind=c_char), target :: ctitle

        win%conn = xcb_connect(c_null_ptr, nscreen)
        if (xcb_connection_has_error(win%conn) /= 0) error stop "cannot connect to the X server"
        it = xcb_setup_roots_iterator(xcb_get_setup(win%conn))
        call c_f_pointer(it%data, scr)
        win%id = xcb_generate_id(win%conn)
        ! Background black, then key presses, exposure and size changes.
        values = [scr%black_pixel, int(z'00028001', c_int32_t)]
        ck = xcb_create_window(win%conn, 0_c_int8_t, win%id, scr%root, 0_c_int16_t, 0_c_int16_t, &
            int(width, c_int16_t), int(height, c_int16_t), 0_c_int16_t, 1_c_int16_t, &
            scr%root_visual, int(z'00000802', c_int32_t), values)
        ctitle = title
        ck = xcb_change_property(win%conn, 0_c_int8_t, win%id, 39_c_int32_t, 31_c_int32_t, &
            8_c_int8_t, int(len(title), c_int32_t), c_loc(ctitle))
        ! Ask the window manager for a close message instead of a killed connection.
        protocols = atom(win%conn, "WM_PROTOCOLS")
        delete_atom = atom(win%conn, "WM_DELETE_WINDOW")
        win%delete_atom = delete_atom
        ck = xcb_change_property(win%conn, 0_c_int8_t, win%id, protocols, 4_c_int32_t, &
            32_c_int8_t, 1_c_int32_t, c_loc(delete_atom))
        ck = xcb_map_window(win%conn, win%id)
        if (xcb_flush(win%conn) <= 0) error stop "cannot flush the X connection"
        win%width = width
        win%height = height
    end function window_open

    integer function window_poll(win) result(ev)
        !! The next event of interest, or EV_NONE when the queue is empty.
        type(xcb_window_t), intent(inout) :: win
        type(c_ptr) :: p
        integer(c_int8_t), pointer :: b(:)
        integer :: kind, w, h
        ev = EV_NONE
        do
            p = xcb_poll_for_event(win%conn)
            if (.not. c_associated(p)) return
            call c_f_pointer(p, b, [32])
            kind = iand(int(b(1)), 127)
            select case (kind)
            case (2) ! KeyPress: Escape (9) or q (24) on the evdev keymap
                if (byte(b, 1) == 9 .or. byte(b, 1) == 24) ev = EV_QUIT
            case (22) ! ConfigureNotify
                w = byte(b, 20) + 256 * byte(b, 21)
                h = byte(b, 22) + 256 * byte(b, 23)
                if (w /= win%width .or. h /= win%height) then
                    win%width = w
                    win%height = h
                    ev = EV_RESIZE
                end if
            case (33) ! ClientMessage
                if (u32(b, 12) == win%delete_atom) ev = EV_QUIT
            end select
            call c_free(p)
            if (ev /= EV_NONE) return
        end do
    end function window_poll

    subroutine window_close(win)
        type(xcb_window_t), intent(inout) :: win
        call xcb_disconnect(win%conn)
        win%conn = c_null_ptr
    end subroutine window_close

    integer(c_int32_t) function atom(c, name)
        type(c_ptr), intent(in) :: c
        character(*), intent(in) :: name
        type(c_ptr) :: r
        integer(c_int8_t), pointer :: b(:)
        r = xcb_intern_atom_reply(c, xcb_intern_atom(c, 0_c_int8_t, int(len(name), c_int16_t), &
            name), c_null_ptr)
        if (.not. c_associated(r)) error stop "cannot intern an X atom"
        call c_f_pointer(r, b, [12])
        atom = u32(b, 8)
        call c_free(r)
    end function atom

    pure integer function byte(b, off)
        integer(c_int8_t), intent(in) :: b(:)
        integer, intent(in) :: off
        byte = iand(int(b(off + 1)), 255)
    end function byte

    pure integer(c_int32_t) function u32(b, off)
        integer(c_int8_t), intent(in) :: b(:)
        integer, intent(in) :: off
        u32 = transfer(b(off + 1:off + 4), u32)
    end function u32

end module fortgfx_xcb
