module fortgfx_gpu_async
    !! An owned window-device initialization request. Finish before using the device.
    use iso_c_binding
    use fortgfx_gpu, only: gfx_gpu_t, gpu_open_window
    implicit none
    private
    public :: gpu_start_window, gpu_start_ready, gpu_start_finish
    type, bind(C) :: request_t
        type(c_ptr) :: device, connection
        integer(c_int32_t) :: window, width, height
    end type
    interface
        type(c_ptr) function start(work, data) bind(C, name="fortgfx_start")
            import c_ptr, c_funptr
            type(c_funptr), value :: work
            type(c_ptr), value :: data
        end function
        integer(c_int) function gpu_start_ready(job) bind(C, name="fortgfx_ready")
            import c_ptr, c_int
            type(c_ptr), value :: job
        end function
        integer(c_int) function finish(job, data) bind(C, name="fortgfx_finish")
            import c_ptr, c_int
            type(c_ptr), value :: job
            type(c_ptr), intent(out) :: data
        end function
    end interface
contains
    function gpu_start_window(device, connection, window, width, height) result(job)
        type(gfx_gpu_t), intent(inout), target :: device
        type(c_ptr), intent(in) :: connection
        integer(c_int32_t), intent(in) :: window
        integer, intent(in) :: width, height
        type(c_ptr) :: job
        type(request_t), pointer :: request
        allocate(request)
        request%device = c_loc(device)
        request%connection = connection
        request%window = window
        request%width = width
        request%height = height
        job = start(c_funloc(initialize), c_loc(request))
        if (.not. c_associated(job)) deallocate(request)
    end function
    integer(c_int) function initialize(data) bind(C) result(status)
        type(c_ptr), value :: data
        type(request_t), pointer :: request
        type(gfx_gpu_t), pointer :: device
        call c_f_pointer(data, request)
        call c_f_pointer(request%device, device)
        status = merge(1_c_int, -1_c_int, gpu_open_window(device, request%connection, &
            request%window, int(request%width), int(request%height)))
    end function
    logical function gpu_start_finish(job) result(ok)
        type(c_ptr), intent(inout) :: job
        type(c_ptr) :: data
        type(request_t), pointer :: request
        integer(c_int) :: status
        ok = .false.
        if (.not. c_associated(job)) return
        status = finish(job, data)
        if (c_associated(data)) then
            call c_f_pointer(data, request)
            deallocate(request)
        end if
        job = c_null_ptr
        ok = status == 1
    end function
end module
