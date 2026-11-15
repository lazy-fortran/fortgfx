module fortgfx_gpu
    !! The frame list drawn by Vulkan 1.3 (dynamic rendering): into a window's
    !! swapchain (an X11 window through VK_KHR_xcb_surface) or into an offscreen
    !! image that can be read back. Shapes and layers are instanced from storage
    !! buffers, textured triangles come from a vertex and an index buffer; the
    !! shaders are those of the CPU renderer's rules.
    use iso_c_binding
    use iso_fortran_env, only: int8, int64
    use fortgfx_vulkan
    use fortgfx_vk
    use fortgfx_list
    use fortgfx_shaders, only: shape_vert_spv, shape_frag_spv, textured_vert_spv, &
        textured_frag_spv
    implicit none
    private
    public :: gfx_gpu_t, gpu_open_window, gpu_open_offscreen, gpu_close, gpu_resize, &
        gpu_render, gpu_read, gpu_texture_create, gpu_texture_update, gpu_texture_release, &
        gpu_layer_set, gpu_layer_release, gpu_device_name

    integer(c_int), parameter :: FMT_RGBA8 = 37, FMT_BGRA8 = 44
    integer(c_int32_t), parameter :: MEM_DEVICE_LOCAL = 1, MEM_HOST_VISIBLE = 2, &
        MEM_HOST_COHERENT = 4
    integer(c_int32_t), parameter :: BUF_TRANSFER_SRC = 1, BUF_TRANSFER_DST = 2, &
        BUF_STORAGE = 32, BUF_INDEX = 64, BUF_VERTEX = 128
    integer(c_int32_t), parameter :: IMG_TRANSFER_SRC = 1, IMG_TRANSFER_DST = 2, &
        IMG_SAMPLED = 4, IMG_COLOR = 16
    integer(c_int), parameter :: LAYOUT_UNDEFINED = 0, LAYOUT_COLOR = 2, &
        LAYOUT_SHADER_READ = 5, LAYOUT_TRANSFER_SRC = 6, LAYOUT_TRANSFER_DST = 7, &
        LAYOUT_PRESENT = 1000001002
    integer(c_int32_t), parameter :: STAGE_TOP = 1, STAGE_FRAGMENT = 128, &
        STAGE_COLOR_OUTPUT = 1024, STAGE_TRANSFER = 4096, STAGE_BOTTOM = 8192, &
        STAGE_HOST = 16384
    integer(c_int32_t), parameter :: ACCESS_SHADER_READ = 32, ACCESS_COLOR_WRITE = 256, &
        ACCESS_TRANSFER_READ = 2048, ACCESS_TRANSFER_WRITE = 4096, ACCESS_HOST_READ = 8192

    type :: gpu_buffer_t
        integer(c_int64_t) :: buffer = 0, memory = 0, size = 0
        type(c_ptr) :: mapped = c_null_ptr
        integer(c_int64_t) :: set = 0 ! storage buffers: their descriptor set
    end type gpu_buffer_t

    type :: gpu_texture_t
        integer :: width = 0, height = 0
        integer(c_int64_t) :: image = 0, memory = 0, view = 0
        integer(c_int64_t) :: set_nearest = 0, set_linear = 0
        logical :: ready = .false. ! in SHADER_READ_ONLY layout
    end type gpu_texture_t

    type :: gpu_layer_t
        type(gpu_buffer_t) :: buf
        integer :: count = 0
    end type gpu_layer_t

    type :: upload_t
        integer :: texture = 0, x = 0, y = 0, w = 0, h = 0
        integer(c_int64_t) :: offset = 0
    end type upload_t

    type :: gfx_gpu_t
        logical :: active = .false., window = .false.
        type(c_ptr) :: instance = c_null_ptr, physical = c_null_ptr, device = c_null_ptr, &
            queue = c_null_ptr
        integer(c_int32_t) :: family = 0
        type(VkPhysicalDeviceMemoryProperties) :: mem
        ! target
        integer :: width = 0, height = 0
        integer(c_int) :: format = FMT_RGBA8
        integer(c_int64_t) :: surface = 0, swapchain = 0
        integer(c_int64_t), allocatable :: images(:), views(:), rendered(:)
        integer(c_int64_t) :: target = 0, target_memory = 0, target_view = 0
        type(gpu_buffer_t) :: readback
        ! pipelines
        integer(c_int64_t) :: set_storage = 0, set_sampler = 0, pool = 0
        integer(c_int64_t) :: shape_layout = 0, tex_layout = 0, shape_pipe = 0, tex_pipe = 0
        integer(c_int64_t) :: nearest = 0, linear = 0
        ! frame data
        type(gpu_buffer_t) :: shapes, verts, idx, staging
        integer(c_int64_t) :: staging_used = 0
        type(upload_t), allocatable :: uploads(:)
        integer :: nuploads = 0
        ! commands
        integer(c_int64_t) :: pool_cmd = 0, fence = 0, acquired = 0
        type(c_ptr) :: cmd = c_null_ptr
        ! resources
        type(gpu_texture_t), allocatable :: textures(:)
        type(gpu_layer_t), allocatable :: layers(:)
        character(len=:), allocatable :: device_name
    end type gfx_gpu_t

    character(len=*, kind=c_char), parameter :: MAIN = "main" // c_null_char

contains

    ! --- opening ----------------------------------------------------------------------

    logical function gpu_open_window(g, connection, window, width, height) result(ok)
        !! Draw into an X11 window (an xcb connection and window id).
        type(gfx_gpu_t), intent(out) :: g
        type(c_ptr), intent(in) :: connection
        integer(c_int32_t), intent(in) :: window
        integer, intent(in) :: width, height
        type(VkXcbSurfaceCreateInfoKHR) :: info
        ok = .false.
        g%window = .true.
        if (.not. create_instance(g, .true.)) return
        info%connection = connection
        info%window = window
        if (vkCreateXcbSurfaceKHR(g%instance, info, c_null_ptr, g%surface) /= VK_SUCCESS) return
        if (.not. create_device(g)) return
        g%format = surface_format(g)
        if (.not. create_common(g)) return
        g%width = width
        g%height = height
        ok = create_swapchain(g)
        g%active = ok
    end function gpu_open_window

    logical function gpu_open_offscreen(g, width, height) result(ok)
        !! Draw into an RGBA8 image of width x height, read back with gpu_read.
        type(gfx_gpu_t), intent(out) :: g
        integer, intent(in) :: width, height
        ok = .false.
        g%window = .false.
        g%format = FMT_RGBA8
        if (.not. create_instance(g, .false.)) return
        if (.not. create_device(g)) return
        if (.not. create_common(g)) return
        g%width = width
        g%height = height
        ok = create_target(g)
        g%active = ok
    end function gpu_open_offscreen

    function gpu_device_name(g) result(name)
        type(gfx_gpu_t), intent(in) :: g
        character(len=:), allocatable :: name
        name = ""
        if (allocated(g%device_name)) name = g%device_name
    end function gpu_device_name

    logical function create_instance(g, surface) result(ok)
        type(gfx_gpu_t), intent(inout) :: g
        logical, intent(in) :: surface
        type(VkApplicationInfo), target :: app
        type(VkInstanceCreateInfo) :: info
        character(len=15, kind=c_char), target :: e1
        character(len=19, kind=c_char), target :: e2
        type(c_ptr), target :: names(2)
        ok = vk_load_global()
        if (.not. ok) return
        app%api_version = ishft(1, 22) + ishft(3, 12)
        info%app_info = c_loc(app)
        if (surface) then
            e1 = "VK_KHR_surface" // c_null_char
            e2 = "VK_KHR_xcb_surface" // c_null_char
            names = [c_loc(e1), c_loc(e2)]
            info%extension_count = 2
            info%extensions = c_loc(names)
        end if
        ok = vkCreateInstance(info, c_null_ptr, g%instance) == VK_SUCCESS
        if (ok) call vk_load_instance(g%instance)
    end function create_instance

    logical function create_device(g) result(ok)
        !! The first GPU with a graphics queue (that presents to the window).
        type(gfx_gpu_t), intent(inout) :: g
        type(c_ptr), allocatable, target :: devices(:)
        type(VkQueueFamilyProperties), allocatable, target :: props(:)
        type(VkDeviceQueueCreateInfo), target :: qinfo
        type(VkDynamicRenderingFeatures), target :: dyn
        type(VkDeviceCreateInfo) :: info
        real(c_float), target :: priority
        character(len=17, kind=c_char), target :: e1
        type(c_ptr), target :: names(1)
        integer(c_int32_t) :: n, nf, supported
        integer :: d, f
        ok = .false.
        if (vkEnumeratePhysicalDevices(g%instance, n, c_null_ptr) /= VK_SUCCESS) return
        if (n == 0) return
        allocate (devices(n))
        if (vkEnumeratePhysicalDevices(g%instance, n, c_loc(devices)) /= VK_SUCCESS) return
        do d = 1, int(n)
            call vkGetPhysicalDeviceQueueFamilyProperties(devices(d), nf, c_null_ptr)
            if (allocated(props)) deallocate (props)
            allocate (props(nf))
            call vkGetPhysicalDeviceQueueFamilyProperties(devices(d), nf, c_loc(props))
            do f = 1, int(nf)
                if (iand(props(f)%flags, 1) == 0) cycle
                if (g%window) then
                    if (vkGetPhysicalDeviceSurfaceSupportKHR(devices(d), int(f - 1, c_int32_t), &
                        g%surface, supported) /= VK_SUCCESS) cycle
                    if (supported == 0) cycle
                end if
                g%physical = devices(d)
                g%family = int(f - 1, c_int32_t)
                exit
            end do
            if (c_associated(g%physical)) exit
        end do
        if (.not. c_associated(g%physical)) return
        call vkGetPhysicalDeviceMemoryProperties(g%physical, g%mem)
        g%device_name = device_name_of(g%instance, g%physical)
        priority = 1.0
        qinfo%family = g%family
        qinfo%count = 1
        qinfo%priorities = c_loc(priority)
        dyn%dynamic_rendering = 1
        info%next = c_loc(dyn)
        info%queue_info_count = 1
        info%queue_infos = c_loc(qinfo)
        if (g%window) then
            e1 = "VK_KHR_swapchain" // c_null_char
            names = [c_loc(e1)]
            info%extension_count = 1
            info%extensions = c_loc(names)
        end if
        ok = vkCreateDevice(g%physical, info, c_null_ptr, g%device) == VK_SUCCESS
        if (ok) call vkGetDeviceQueue(g%device, g%family, 0_c_int32_t, g%queue)
    end function create_device

    function device_name_of(instance, pd) result(name)
        !! VkPhysicalDeviceProperties.deviceName (offset 20, 256 characters).
        type(c_ptr), intent(in) :: instance, pd
        character(len=:), allocatable :: name
        interface
            subroutine get_props(pd, props) bind(C)
                import :: c_ptr, c_int8_t
                type(c_ptr), value :: pd
                integer(c_int8_t), intent(out) :: props(1024)
            end subroutine
        end interface
        procedure(get_props), pointer :: f
        integer(c_int8_t) :: props(1024)
        integer :: k
        name = ""
        call c_f_procpointer(vkGetInstanceProcAddr(instance, &
            "vkGetPhysicalDeviceProperties" // c_null_char), f)
        if (.not. associated(f)) return
        call f(pd, props)
        k = 0
        do while (k < 256)
            if (props(21 + k) == 0) exit
            k = k + 1
        end do
        name = repeat(" ", k)
        do k = 1, len(name)
            name(k:k) = achar(iand(int(props(20 + k)), 255))
        end do
    end function device_name_of

    integer(c_int) function surface_format(g) result(fmt)
        !! 8-bit BGRA or RGBA without sRGB encoding (blending in stored values,
        !! as the shaders expect).
        type(gfx_gpu_t), intent(inout) :: g
        type(VkSurfaceFormatKHR), allocatable, target :: formats(:)
        integer(c_int32_t) :: n
        integer :: k
        fmt = FMT_BGRA8
        if (vkGetPhysicalDeviceSurfaceFormatsKHR(g%physical, g%surface, n, c_null_ptr) /= &
            VK_SUCCESS) return
        allocate (formats(n))
        if (vkGetPhysicalDeviceSurfaceFormatsKHR(g%physical, g%surface, n, c_loc(formats)) /= &
            VK_SUCCESS) return
        if (any(formats%format == FMT_BGRA8)) return
        do k = 1, int(n)
            if (formats(k)%format == FMT_RGBA8) fmt = FMT_RGBA8
        end do
    end function surface_format

    logical function create_common(g) result(ok)
        !! Descriptor layouts and pool, samplers, pipelines and commands.
        type(gfx_gpu_t), intent(inout) :: g
        type(VkDescriptorSetLayoutBinding), target :: binding
        type(VkDescriptorSetLayoutCreateInfo), target :: dsl
        type(VkDescriptorPoolSize), target :: sizes(2)
        type(VkDescriptorPoolCreateInfo), target :: pool
        type(VkSamplerCreateInfo), target :: sampler
        type(VkCommandPoolCreateInfo) :: cpool
        type(VkCommandBufferAllocateInfo) :: ainfo
        type(VkSemaphoreCreateInfo) :: sinfo
        type(VkFenceCreateInfo) :: finfo
        ok = .false.
        binding = VkDescriptorSetLayoutBinding(binding=0, descriptor_type=7, count=1, stages=1)
        dsl%binding_count = 1
        dsl%bindings = c_loc(binding)
        if (vkCreateDescriptorSetLayout(g%device, c_loc(dsl), c_null_ptr, g%set_storage) /= &
            VK_SUCCESS) return
        binding = VkDescriptorSetLayoutBinding(binding=0, descriptor_type=1, count=1, stages=16)
        if (vkCreateDescriptorSetLayout(g%device, c_loc(dsl), c_null_ptr, g%set_sampler) /= &
            VK_SUCCESS) return
        sizes(1) = VkDescriptorPoolSize(7, 4096)
        sizes(2) = VkDescriptorPoolSize(1, 8192)
        pool%flags = 1 ! FREE_DESCRIPTOR_SET
        pool%max_sets = 12288
        pool%size_count = 2
        pool%sizes = c_loc(sizes)
        if (vkCreateDescriptorPool(g%device, c_loc(pool), c_null_ptr, g%pool) /= VK_SUCCESS) &
            return
        sampler%mag_filter = 0
        sampler%min_filter = 0
        if (vkCreateSampler(g%device, c_loc(sampler), c_null_ptr, g%nearest) /= VK_SUCCESS) &
            return
        sampler%mag_filter = 1
        sampler%min_filter = 1
        if (vkCreateSampler(g%device, c_loc(sampler), c_null_ptr, g%linear) /= VK_SUCCESS) &
            return
        if (.not. create_pipelines(g)) return
        cpool%flags = 2
        cpool%family = g%family
        if (vkCreateCommandPool(g%device, cpool, c_null_ptr, g%pool_cmd) /= VK_SUCCESS) return
        ainfo%pool = g%pool_cmd
        if (vkAllocateCommandBuffers(g%device, ainfo, g%cmd) /= VK_SUCCESS) return
        if (vkCreateSemaphore(g%device, sinfo, c_null_ptr, g%acquired) /= VK_SUCCESS) return
        finfo%flags = 1
        if (vkCreateFence(g%device, finfo, c_null_ptr, g%fence) /= VK_SUCCESS) return
        allocate (g%textures(16), g%layers(16), g%uploads(64))
        ok = .true.
    end function create_common

    integer(c_int64_t) function shader(g, words) result(module)
        type(gfx_gpu_t), intent(inout) :: g
        integer(c_int32_t), intent(in), target :: words(:)
        type(VkShaderModuleCreateInfo) :: info
        info%code_size = int(4 * size(words), c_size_t)
        info%code = c_loc(words)
        module = 0
        if (vkCreateShaderModule(g%device, info, c_null_ptr, module) /= VK_SUCCESS) module = 0
    end function shader

    logical function create_pipelines(g) result(ok)
        type(gfx_gpu_t), intent(inout) :: g
        type(VkPushConstantRange), target :: push
        type(VkPipelineLayoutCreateInfo) :: linfo
        integer(c_int64_t), target :: set_layout
        integer(c_int32_t), target :: shape_vs(size(shape_vert_spv)), shape_fs(size(shape_frag_spv))
        integer(c_int32_t), target :: tex_vs(size(textured_vert_spv)), &
            tex_fs(size(textured_frag_spv))
        type(VkVertexInputBindingDescription), target :: vbinding
        type(VkVertexInputAttributeDescription), target :: attrs(3)
        ok = .false.
        push = VkPushConstantRange(stages=1, offset=0, size=48)
        linfo%push_range_count = 1
        linfo%push_ranges = c_loc(push)
        linfo%set_layout_count = 1
        linfo%set_layouts = c_loc(set_layout)
        set_layout = g%set_storage
        if (vkCreatePipelineLayout(g%device, linfo, c_null_ptr, g%shape_layout) /= VK_SUCCESS) &
            return
        set_layout = g%set_sampler
        if (vkCreatePipelineLayout(g%device, linfo, c_null_ptr, g%tex_layout) /= VK_SUCCESS) &
            return
        shape_vs = shape_vert_spv
        shape_fs = shape_frag_spv
        tex_vs = textured_vert_spv
        tex_fs = textured_frag_spv
        g%shape_pipe = pipeline(g, shader(g, shape_vs), shader(g, shape_fs), g%shape_layout, &
            .false.)
        vbinding = VkVertexInputBindingDescription(0, 32, 0)
        attrs(1) = VkVertexInputAttributeDescription(0, 0, 103, 0)
        attrs(2) = VkVertexInputAttributeDescription(1, 0, 103, 8)
        attrs(3) = VkVertexInputAttributeDescription(2, 0, 109, 16)
        g%tex_pipe = pipeline(g, shader(g, tex_vs), shader(g, tex_fs), g%tex_layout, .true., &
            c_loc(vbinding), c_loc(attrs))
        ok = g%shape_pipe /= 0 .and. g%tex_pipe /= 0
    end function create_pipelines

    integer(c_int64_t) function pipeline(g, vs, fs, layout, vertices, binding, attrs) result(pipe)
        !! Triangles, no culling, premultiplied blending, viewport and scissor dynamic.
        type(gfx_gpu_t), intent(inout) :: g
        integer(c_int64_t), intent(in) :: vs, fs, layout
        logical, intent(in) :: vertices
        type(c_ptr), intent(in), optional :: binding, attrs
        type(VkPipelineShaderStageCreateInfo), target :: stages(2)
        type(VkPipelineVertexInputStateCreateInfo), target :: vin
        type(VkPipelineInputAssemblyStateCreateInfo), target :: assembly
        type(VkPipelineViewportStateCreateInfo), target :: viewport
        type(VkPipelineRasterizationStateCreateInfo), target :: raster
        type(VkPipelineMultisampleStateCreateInfo), target :: multisample
        type(VkPipelineColorBlendAttachmentState), target :: attachment
        type(VkPipelineColorBlendStateCreateInfo), target :: blend
        type(VkPipelineDynamicStateCreateInfo), target :: dynamic
        type(VkPipelineRenderingCreateInfo), target :: rendering
        type(VkGraphicsPipelineCreateInfo) :: info
        integer(c_int), target :: dynamic_states(2), colour_format(1)
        character(len=5, kind=c_char), target :: entry
        pipe = 0
        if (vs == 0 .or. fs == 0) return
        entry = MAIN
        stages(1)%stage = 1
        stages(1)%module = vs
        stages(1)%name = c_loc(entry)
        stages(2)%stage = 16
        stages(2)%module = fs
        stages(2)%name = c_loc(entry)
        if (vertices) then
            vin%binding_count = 1
            vin%bindings = binding
            vin%attribute_count = 3
            vin%attributes = attrs
        end if
        attachment%blend = 1
        attachment%src_color = 1 ! ONE
        attachment%dst_color = 7 ! ONE_MINUS_SRC_ALPHA
        attachment%src_alpha = 1
        attachment%dst_alpha = 7
        blend%attachment_count = 1
        blend%attachments = c_loc(attachment)
        dynamic_states = [0, 1]
        dynamic%count = 2
        dynamic%states = c_loc(dynamic_states)
        colour_format(1) = g%format
        rendering%color_count = 1
        rendering%color_formats = c_loc(colour_format)
        info%next = c_loc(rendering)
        info%stage_count = 2
        info%stages = c_loc(stages)
        info%vertex_input = c_loc(vin)
        info%input_assembly = c_loc(assembly)
        info%viewport = c_loc(viewport)
        info%rasterization = c_loc(raster)
        info%multisample = c_loc(multisample)
        info%color_blend = c_loc(blend)
        info%dynamic = c_loc(dynamic)
        info%layout = layout
        if (vkCreateGraphicsPipelines(g%device, 0_c_int64_t, 1_c_int32_t, info, c_null_ptr, &
            pipe) /= VK_SUCCESS) pipe = 0
        call vkDestroyShaderModule(g%device, vs, c_null_ptr)
        call vkDestroyShaderModule(g%device, fs, c_null_ptr)
    end function pipeline

    ! --- targets ----------------------------------------------------------------------

    logical function create_swapchain(g) result(ok)
        type(gfx_gpu_t), intent(inout) :: g
        type(VkSurfaceCapabilitiesKHR) :: caps
        type(VkSwapchainCreateInfoKHR) :: info
        type(VkImageViewCreateInfo) :: vinfo
        type(VkSemaphoreCreateInfo) :: sinfo
        integer(c_int32_t) :: n
        integer(c_int64_t), allocatable, target :: images(:)
        integer :: k
        ok = .false.
        if (vkGetPhysicalDeviceSurfaceCapabilitiesKHR(g%physical, g%surface, caps) /= &
            VK_SUCCESS) return
        if (caps%current%width /= -1) then
            g%width = caps%current%width
            g%height = caps%current%height
        end if
        if (g%width <= 0 .or. g%height <= 0) return
        info%surface = g%surface
        info%min_images = caps%min_images + 1
        if (caps%max_images > 0) info%min_images = min(info%min_images, caps%max_images)
        info%format = g%format
        info%color_space = 0
        info%extent = VkExtent2D(g%width, g%height)
        info%usage = IMG_COLOR
        info%transform = caps%current_transform
        info%composite_alpha = 1
        info%present_mode = 2 ! FIFO
        info%old_swapchain = g%swapchain
        if (vkCreateSwapchainKHR(g%device, info, c_null_ptr, g%swapchain) /= VK_SUCCESS) return
        if (info%old_swapchain /= 0) call vkDestroySwapchainKHR(g%device, info%old_swapchain, &
            c_null_ptr)
        call release_swapchain_images(g)
        if (vkGetSwapchainImagesKHR(g%device, g%swapchain, n, c_null_ptr) /= VK_SUCCESS) return
        allocate (g%images(n), g%views(n), g%rendered(n), images(n))
        if (vkGetSwapchainImagesKHR(g%device, g%swapchain, n, c_loc(images)) /= VK_SUCCESS) &
            return
        g%images = images
        vinfo%format = g%format
        do k = 1, int(n)
            vinfo%image = g%images(k)
            if (vkCreateImageView(g%device, vinfo, c_null_ptr, g%views(k)) /= VK_SUCCESS) return
            if (vkCreateSemaphore(g%device, sinfo, c_null_ptr, g%rendered(k)) /= VK_SUCCESS) &
                return
        end do
        ok = .true.
    end function create_swapchain

    subroutine release_swapchain_images(g)
        type(gfx_gpu_t), intent(inout) :: g
        integer :: k
        if (.not. allocated(g%views)) return
        do k = 1, size(g%views)
            call vkDestroyImageView(g%device, g%views(k), c_null_ptr)
            call vkDestroySemaphore(g%device, g%rendered(k), c_null_ptr)
        end do
        deallocate (g%images, g%views, g%rendered)
    end subroutine release_swapchain_images

    logical function create_target(g) result(ok)
        !! The offscreen colour image and its read-back buffer.
        type(gfx_gpu_t), intent(inout) :: g
        type(VkImageCreateInfo), target :: info
        type(VkImageViewCreateInfo) :: vinfo
        ok = .false.
        info%format = g%format
        info%extent = VkExtent3D(g%width, g%height, 1)
        info%usage = ior(IMG_COLOR, IMG_TRANSFER_SRC)
        if (.not. image_with_memory(g, info, g%target, g%target_memory)) return
        vinfo%image = g%target
        vinfo%format = g%format
        if (vkCreateImageView(g%device, vinfo, c_null_ptr, g%target_view) /= VK_SUCCESS) return
        ok = make_buffer(g, g%readback, int(4, c_int64_t) * g%width * g%height, BUF_TRANSFER_DST)
    end function create_target

    subroutine gpu_resize(g, width, height)
        type(gfx_gpu_t), intent(inout) :: g
        integer, intent(in) :: width, height
        if (.not. g%active) return
        if (vkDeviceWaitIdle(g%device) /= VK_SUCCESS) continue
        g%width = width
        g%height = height
        if (g%window) then
            if (.not. create_swapchain(g)) continue
        else
            call vkDestroyImageView(g%device, g%target_view, c_null_ptr)
            call vkDestroyImage(g%device, g%target, c_null_ptr)
            call vkFreeMemory(g%device, g%target_memory, c_null_ptr)
            call free_buffer(g, g%readback)
            if (.not. create_target(g)) g%active = .false.
        end if
    end subroutine gpu_resize

    ! --- memory -------------------------------------------------------------------------

    integer(c_int32_t) function memory_type(g, bits, want) result(t)
        type(gfx_gpu_t), intent(in) :: g
        integer(c_int32_t), intent(in) :: bits, want
        integer :: k
        do k = 0, int(g%mem%type_count) - 1
            if (iand(ishft(bits, -k), 1) == 0) cycle
            if (iand(g%mem%types(k + 1)%flags, want) == want) then
                t = int(k, c_int32_t)
                return
            end if
        end do
        t = -1
    end function memory_type

    logical function make_buffer(g, b, size, usage) result(ok)
        !! A host-visible, coherent and mapped buffer.
        type(gfx_gpu_t), intent(inout) :: g
        type(gpu_buffer_t), intent(inout) :: b
        integer(c_int64_t), intent(in) :: size
        integer(c_int32_t), intent(in) :: usage
        type(VkBufferCreateInfo), target :: info
        type(VkMemoryRequirements) :: req
        type(VkMemoryAllocateInfo) :: alloc
        ok = .false.
        info%size = max(64_c_int64_t, size)
        info%usage = usage
        if (vkCreateBuffer(g%device, c_loc(info), c_null_ptr, b%buffer) /= VK_SUCCESS) return
        call vkGetBufferMemoryRequirements(g%device, b%buffer, req)
        alloc%size = req%size
        alloc%type_index = memory_type(g, req%type_bits, ior(MEM_HOST_VISIBLE, MEM_HOST_COHERENT))
        if (alloc%type_index < 0) return
        if (vkAllocateMemory(g%device, alloc, c_null_ptr, b%memory) /= VK_SUCCESS) return
        if (vkBindBufferMemory(g%device, b%buffer, b%memory, 0_c_int64_t) /= VK_SUCCESS) return
        if (vkMapMemory(g%device, b%memory, 0_c_int64_t, req%size, 0_c_int32_t, b%mapped) /= &
            VK_SUCCESS) return
        b%size = info%size
        ok = .true.
    end function make_buffer

    subroutine free_buffer(g, b)
        type(gfx_gpu_t), intent(inout) :: g
        type(gpu_buffer_t), intent(inout) :: b
        integer(c_int64_t) :: sets(1)
        if (b%buffer == 0) return
        if (b%set /= 0) then
            sets(1) = b%set
            if (vkFreeDescriptorSets(g%device, g%pool, 1_c_int32_t, sets) /= VK_SUCCESS) continue
        end if
        call vkDestroyBuffer(g%device, b%buffer, c_null_ptr)
        call vkFreeMemory(g%device, b%memory, c_null_ptr)
        b = gpu_buffer_t()
    end subroutine free_buffer

    logical function ensure_buffer(g, b, size, usage, storage) result(ok)
        !! Room for `size` bytes, growing by doubling; storage buffers keep a
        !! descriptor set naming them.
        type(gfx_gpu_t), intent(inout) :: g
        type(gpu_buffer_t), intent(inout) :: b
        integer(c_int64_t), intent(in) :: size
        integer(c_int32_t), intent(in) :: usage
        logical, intent(in) :: storage
        type(VkDescriptorSetAllocateInfo) :: ainfo
        type(VkDescriptorBufferInfo), target :: binfo
        type(VkWriteDescriptorSet) :: write
        integer(c_int64_t), target :: layout
        ok = .true.
        if (b%buffer /= 0 .and. b%size >= size) return
        call free_buffer(g, b)
        ok = make_buffer(g, b, max(size, 2 * b%size, 65536_c_int64_t), usage)
        if (.not. ok .or. .not. storage) return
        layout = g%set_storage
        ainfo%pool = g%pool
        ainfo%layouts = c_loc(layout)
        ok = vkAllocateDescriptorSets(g%device, ainfo, b%set) == VK_SUCCESS
        if (.not. ok) return
        binfo = VkDescriptorBufferInfo(b%buffer, 0_c_int64_t, -1_c_int64_t)
        write%dst_set = b%set
        write%descriptor_type = 7
        write%buffer_info = c_loc(binfo)
        call vkUpdateDescriptorSets(g%device, 1_c_int32_t, write, 0_c_int32_t, c_null_ptr)
    end function ensure_buffer

    logical function image_with_memory(g, info, image, memory) result(ok)
        type(gfx_gpu_t), intent(inout) :: g
        type(VkImageCreateInfo), intent(in), target :: info
        integer(c_int64_t), intent(out) :: image, memory
        type(VkMemoryRequirements) :: req
        type(VkMemoryAllocateInfo) :: alloc
        ok = .false.
        image = 0
        memory = 0
        if (vkCreateImage(g%device, c_loc(info), c_null_ptr, image) /= VK_SUCCESS) return
        call vkGetImageMemoryRequirements(g%device, image, req)
        alloc%size = req%size
        alloc%type_index = memory_type(g, req%type_bits, MEM_DEVICE_LOCAL)
        if (alloc%type_index < 0) alloc%type_index = memory_type(g, req%type_bits, 0_c_int32_t)
        if (vkAllocateMemory(g%device, alloc, c_null_ptr, memory) /= VK_SUCCESS) return
        ok = vkBindImageMemory(g%device, image, memory, 0_c_int64_t) == VK_SUCCESS
    end function image_with_memory

    subroutine wait_idle(g)
        !! The previous frame has finished with every buffer.
        type(gfx_gpu_t), intent(inout) :: g
        if (vkWaitForFences(g%device, 1_c_int32_t, g%fence, 1_c_int32_t, -1_c_int64_t) /= &
            VK_SUCCESS) continue
    end subroutine wait_idle

    ! --- textures and layers ----------------------------------------------------------------

    integer function gpu_texture_create(g, width, height) result(id)
        !! An RGBA8 texture (straight alpha), sampled nearest or bilinear.
        type(gfx_gpu_t), intent(inout) :: g
        integer, intent(in) :: width, height
        type(VkImageCreateInfo), target :: info
        type(VkImageViewCreateInfo) :: vinfo
        type(gpu_texture_t), allocatable :: grown(:)
        integer :: k
        id = 0
        do k = 1, size(g%textures)
            if (g%textures(k)%width == 0) then
                id = k
                exit
            end if
        end do
        if (id == 0) then
            id = size(g%textures) + 1
            allocate (grown(2 * size(g%textures)))
            grown(1:size(g%textures)) = g%textures
            call move_alloc(grown, g%textures)
        end if
        associate (t => g%textures(id))
            t%width = max(1, width)
            t%height = max(1, height)
            info%format = FMT_RGBA8
            info%extent = VkExtent3D(t%width, t%height, 1)
            info%usage = ior(IMG_SAMPLED, IMG_TRANSFER_DST)
            if (.not. image_with_memory(g, info, t%image, t%memory)) then
                t%width = 0
                id = 0
                return
            end if
            vinfo%image = t%image
            vinfo%format = FMT_RGBA8
            if (vkCreateImageView(g%device, vinfo, c_null_ptr, t%view) /= VK_SUCCESS) continue
            t%set_nearest = sampler_set(g, t%view, g%nearest)
            t%set_linear = sampler_set(g, t%view, g%linear)
            t%ready = .false.
        end associate
    end function gpu_texture_create

    integer(c_int64_t) function sampler_set(g, view, sampler) result(set)
        type(gfx_gpu_t), intent(inout) :: g
        integer(c_int64_t), intent(in) :: view, sampler
        type(VkDescriptorSetAllocateInfo) :: ainfo
        type(VkDescriptorImageInfo), target :: iinfo
        type(VkWriteDescriptorSet) :: write
        integer(c_int64_t), target :: layout
        layout = g%set_sampler
        ainfo%pool = g%pool
        ainfo%layouts = c_loc(layout)
        set = 0
        if (vkAllocateDescriptorSets(g%device, ainfo, set) /= VK_SUCCESS) return
        iinfo = VkDescriptorImageInfo(sampler, view, LAYOUT_SHADER_READ)
        write%dst_set = set
        write%descriptor_type = 1
        write%image_info = c_loc(iinfo)
        call vkUpdateDescriptorSets(g%device, 1_c_int32_t, write, 0_c_int32_t, c_null_ptr)
    end function sampler_set

    subroutine gpu_texture_update(g, id, x, y, rgba)
        !! Pixels (4, w, h) at (x, y) from 0; uploaded with the next frame.
        type(gfx_gpu_t), intent(inout) :: g
        integer, intent(in) :: id, x, y
        integer(int8), intent(in), target :: rgba(:, :, :)
        integer(c_int64_t) :: bytes, offset
        integer(int8), pointer :: dst(:)
        type(upload_t), allocatable :: grown(:)
        type(gpu_buffer_t) :: bigger
        integer(int8), pointer :: old(:), new(:)
        if (id < 1 .or. id > size(g%textures)) return
        if (g%textures(id)%width == 0) return
        bytes = int(size(rgba), c_int64_t)
        if (bytes == 0) return
        offset = 4 * ((g%staging_used + 3) / 4)
        if (offset + bytes > g%staging%size) then
            ! The staging buffer only grows between frames, with the GPU idle.
            call wait_idle(g)
            if (.not. make_buffer(g, bigger, max(2 * g%staging%size, offset + bytes, &
                4194304_c_int64_t), BUF_TRANSFER_SRC)) return
            if (g%staging_used > 0) then
                call c_f_pointer(g%staging%mapped, old, [g%staging_used])
                call c_f_pointer(bigger%mapped, new, [g%staging_used])
                new = old
            end if
            call free_buffer(g, g%staging)
            g%staging = bigger
        end if
        call c_f_pointer(g%staging%mapped, dst, [offset + bytes])
        dst(offset + 1:offset + bytes) = reshape(rgba, [bytes])
        g%staging_used = offset + bytes
        if (g%nuploads == size(g%uploads)) then
            allocate (grown(2 * size(g%uploads)))
            grown(1:g%nuploads) = g%uploads(1:g%nuploads)
            call move_alloc(grown, g%uploads)
        end if
        g%nuploads = g%nuploads + 1
        g%uploads(g%nuploads) = upload_t(id, x, y, size(rgba, 2), size(rgba, 3), offset)
    end subroutine gpu_texture_update

    subroutine gpu_texture_release(g, id)
        type(gfx_gpu_t), intent(inout) :: g
        integer, intent(in) :: id
        integer(c_int64_t) :: sets(2)
        integer :: k
        if (id < 1 .or. id > size(g%textures)) return
        if (g%textures(id)%width == 0) return
        call wait_idle(g)
        ! Pending uploads of this texture are dropped.
        do k = 1, g%nuploads
            if (g%uploads(k)%texture == id) g%uploads(k)%texture = 0
        end do
        associate (t => g%textures(id))
            sets = [t%set_nearest, t%set_linear]
            if (vkFreeDescriptorSets(g%device, g%pool, 2_c_int32_t, sets) /= VK_SUCCESS) continue
            call vkDestroyImageView(g%device, t%view, c_null_ptr)
            call vkDestroyImage(g%device, t%image, c_null_ptr)
            call vkFreeMemory(g%device, t%memory, c_null_ptr)
        end associate
        g%textures(id) = gpu_texture_t()
    end subroutine gpu_texture_release

    subroutine gpu_layer_set(g, id, shapes, count)
        !! A retained layer's shapes (16 floats each), kept on the GPU.
        type(gfx_gpu_t), intent(inout) :: g
        integer, intent(in) :: id, count
        real(c_float), intent(in) :: shapes(:, :)
        type(gpu_layer_t), allocatable :: grown(:)
        real(c_float), pointer :: dst(:)
        if (id > size(g%layers)) then
            allocate (grown(max(id, 2 * size(g%layers))))
            grown(1:size(g%layers)) = g%layers
            call move_alloc(grown, g%layers)
        end if
        call wait_idle(g)
        if (.not. ensure_buffer(g, g%layers(id)%buf, int(64, c_int64_t) * max(1, count), &
            BUF_STORAGE, .true.)) return
        g%layers(id)%count = count
        if (count == 0) return
        call c_f_pointer(g%layers(id)%buf%mapped, dst, [16 * count])
        dst = reshape(shapes(:, 1:count), [16 * count])
    end subroutine gpu_layer_set

    subroutine gpu_layer_release(g, id)
        type(gfx_gpu_t), intent(inout) :: g
        integer, intent(in) :: id
        if (id < 1 .or. id > size(g%layers)) return
        call wait_idle(g)
        call free_buffer(g, g%layers(id)%buf)
        g%layers(id)%count = 0
    end subroutine gpu_layer_release

    ! --- frames --------------------------------------------------------------------------------

    logical function gpu_render(g, list) result(ok)
        !! Draw the list and present it (window) or keep it for gpu_read;
        !! false when the window's surface changed and the frame was dropped.
        type(gfx_gpu_t), intent(inout) :: g
        type(gfx_list_t), intent(in) :: list
        integer(c_int32_t), target :: index, wait_stage
        integer(c_int64_t), target :: wait_sem, signal_sem, chain
        type(c_ptr), target :: buffers(1)
        type(VkSubmitInfo) :: submit
        type(VkPresentInfoKHR) :: present
        type(VkCommandBufferBeginInfo) :: binfo
        integer(c_int64_t) :: image, view
        integer(c_int) :: res
        ok = .false.
        if (.not. g%active) return
        call wait_idle(g)
        index = 0
        if (g%window) then
            res = vkAcquireNextImageKHR(g%device, g%swapchain, -1_c_int64_t, g%acquired, &
                0_c_int64_t, index)
            if (res == VK_ERROR_OUT_OF_DATE_KHR) then
                if (create_swapchain(g)) continue
                return
            end if
            image = g%images(index + 1)
            view = g%views(index + 1)
        else
            image = g%target
            view = g%target_view
        end if
        if (vkResetFences(g%device, 1_c_int32_t, g%fence) /= VK_SUCCESS) return
        if (.not. write_frame(g, list)) return
        if (vkResetCommandBuffer(g%cmd, 0_c_int32_t) /= VK_SUCCESS) return
        if (vkBeginCommandBuffer(g%cmd, binfo) /= VK_SUCCESS) return
        call record_uploads(g)
        call barrier(g, image, LAYOUT_UNDEFINED, LAYOUT_COLOR, 0, ACCESS_COLOR_WRITE, &
            STAGE_COLOR_OUTPUT, STAGE_COLOR_OUTPUT)
        call record_batches(g, list, view)
        if (g%window) then
            call barrier(g, image, LAYOUT_COLOR, LAYOUT_PRESENT, ACCESS_COLOR_WRITE, 0, &
                STAGE_COLOR_OUTPUT, STAGE_BOTTOM)
        else
            call barrier(g, image, LAYOUT_COLOR, LAYOUT_TRANSFER_SRC, ACCESS_COLOR_WRITE, &
                ACCESS_TRANSFER_READ, STAGE_COLOR_OUTPUT, STAGE_TRANSFER)
            call vkCmdCopyImageToBuffer(g%cmd, image, LAYOUT_TRANSFER_SRC, g%readback%buffer, &
                1_c_int32_t, VkBufferImageCopy(image_extent=VkExtent3D(g%width, g%height, 1)))
        end if
        if (vkEndCommandBuffer(g%cmd) /= VK_SUCCESS) return
        buffers(1) = g%cmd
        submit%buffer_count = 1
        submit%buffers = c_loc(buffers)
        if (g%window) then
            wait_sem = g%acquired
            wait_stage = STAGE_COLOR_OUTPUT
            signal_sem = g%rendered(index + 1)
            submit%wait_count = 1
            submit%waits = c_loc(wait_sem)
            submit%wait_stages = c_loc(wait_stage)
            submit%signal_count = 1
            submit%signals = c_loc(signal_sem)
        end if
        if (vkQueueSubmit(g%queue, 1_c_int32_t, submit, g%fence) /= VK_SUCCESS) return
        g%nuploads = 0
        g%staging_used = 0
        ok = .true.
        if (.not. g%window) return
        chain = g%swapchain
        present%wait_count = 1
        present%waits = c_loc(signal_sem)
        present%swapchain_count = 1
        present%swapchains = c_loc(chain)
        present%indices = c_loc(index)
        res = vkQueuePresentKHR(g%queue, present)
        if (res == VK_ERROR_OUT_OF_DATE_KHR .or. res == VK_SUBOPTIMAL_KHR) then
            if (create_swapchain(g)) continue
        end if
    end function gpu_render

    logical function write_frame(g, list) result(ok)
        !! The list's shapes, vertices and indices into the frame buffers.
        type(gfx_gpu_t), intent(inout) :: g
        type(gfx_list_t), intent(in), target :: list
        real(c_float), pointer :: f(:)
        integer(c_int32_t), pointer :: i(:)
        ok = ensure_buffer(g, g%shapes, int(64, c_int64_t) * max(1, list%nshapes), &
            BUF_STORAGE, .true.)
        ok = ok .and. ensure_buffer(g, g%verts, int(32, c_int64_t) * max(1, list%nverts), &
            BUF_VERTEX, .false.)
        ok = ok .and. ensure_buffer(g, g%idx, int(4, c_int64_t) * max(1, list%nidx), BUF_INDEX, &
            .false.)
        if (.not. ok) return
        if (list%nshapes > 0) then
            call c_f_pointer(g%shapes%mapped, f, [16 * list%nshapes])
            f = reshape(list%shapes(:, 1:list%nshapes), [16 * list%nshapes])
        end if
        if (list%nverts > 0) then
            call c_f_pointer(g%verts%mapped, f, [8 * list%nverts])
            f = reshape(list%verts(:, 1:list%nverts), [8 * list%nverts])
        end if
        if (list%nidx > 0) then
            call c_f_pointer(g%idx%mapped, i, [list%nidx])
            i = list%idx(1:list%nidx)
        end if
    end function write_frame

    subroutine record_uploads(g)
        !! Staged texture pixels into their images, ready for sampling.
        type(gfx_gpu_t), intent(inout) :: g
        integer :: k
        do k = 1, g%nuploads
            associate (u => g%uploads(k))
                if (u%texture == 0) cycle
                associate (t => g%textures(u%texture))
                    call barrier(g, t%image, merge(LAYOUT_SHADER_READ, LAYOUT_UNDEFINED, t%ready), &
                        LAYOUT_TRANSFER_DST, ACCESS_SHADER_READ, ACCESS_TRANSFER_WRITE, &
                        ior(STAGE_FRAGMENT, STAGE_TOP), STAGE_TRANSFER)
                    call vkCmdCopyBufferToImage(g%cmd, g%staging%buffer, t%image, &
                        LAYOUT_TRANSFER_DST, 1_c_int32_t, VkBufferImageCopy(offset=u%offset, &
                        image_offset=VkOffset3D(u%x, u%y, 0), image_extent=VkExtent3D(u%w, &
                        u%h, 1)))
                    call barrier(g, t%image, LAYOUT_TRANSFER_DST, LAYOUT_SHADER_READ, &
                        ACCESS_TRANSFER_WRITE, ACCESS_SHADER_READ, STAGE_TRANSFER, STAGE_FRAGMENT)
                    t%ready = .true.
                end associate
            end associate
        end do
    end subroutine record_uploads

    subroutine record_batches(g, list, view)
        type(gfx_gpu_t), intent(inout) :: g
        type(gfx_list_t), intent(in) :: list
        integer(c_int64_t), intent(in) :: view
        type(VkRenderingAttachmentInfo), target :: colour
        type(VkRenderingInfo) :: rinfo
        real(c_float), target :: push(12)
        integer(c_int64_t), target :: vbufs(1), voffs(1)
        integer :: b, x0, y0, x1, y1
        integer(c_int64_t) :: set
        colour%view = view
        colour%layout = LAYOUT_COLOR
        colour%load_op = 1
        colour%store_op = 0
        colour%clear = list%clear
        rinfo%area%extent = VkExtent2D(g%width, g%height)
        rinfo%color_count = 1
        rinfo%colors = c_loc(colour)
        call vkCmdBeginRendering(g%cmd, rinfo)
        call vkCmdSetViewport(g%cmd, 0_c_int32_t, 1_c_int32_t, VkViewport(width=real(g%width), &
            height=real(g%height)))
        do b = 1, list%nbatches
            associate (bt => list%batches(b))
                if (bt%count <= 0) cycle
                x0 = max(0, bt%clip(1))
                y0 = max(0, bt%clip(2))
                x1 = min(g%width, bt%clip(1) + bt%clip(3))
                y1 = min(g%height, bt%clip(2) + bt%clip(4))
                if (x1 <= x0 .or. y1 <= y0) cycle
                call vkCmdSetScissor(g%cmd, 0_c_int32_t, 1_c_int32_t, VkRect2D(x0, y0, &
                    VkExtent2D(x1 - x0, y1 - y0)))
                push = bt%view
                push(1) = real(g%width, c_float)
                push(2) = real(g%height, c_float)
                select case (bt%kind)
                case (GFX_SHAPES, GFX_LAYER)
                    if (bt%kind == GFX_LAYER) then
                        if (bt%layer < 1 .or. bt%layer > size(g%layers)) cycle
                        if (g%layers(bt%layer)%buf%set == 0) cycle
                        set = g%layers(bt%layer)%buf%set
                    else
                        set = g%shapes%set
                    end if
                    call vkCmdBindPipeline(g%cmd, 0_c_int, g%shape_pipe)
                    call vkCmdBindDescriptorSets(g%cmd, 0_c_int, g%shape_layout, 0_c_int32_t, &
                        1_c_int32_t, set, 0_c_int32_t, c_null_ptr)
                    call vkCmdPushConstants(g%cmd, g%shape_layout, 1_c_int32_t, 0_c_int32_t, &
                        48_c_int32_t, c_loc(push))
                    if (bt%kind == GFX_LAYER) then
                        call vkCmdDraw(g%cmd, 6_c_int32_t, int(min(bt%count, &
                            g%layers(bt%layer)%count), c_int32_t), 0_c_int32_t, 0_c_int32_t)
                    else
                        call vkCmdDraw(g%cmd, 6_c_int32_t, int(bt%count, c_int32_t), 0_c_int32_t, &
                            int(bt%first, c_int32_t))
                    end if
                case (GFX_TEXTURED)
                    if (bt%texture < 1 .or. bt%texture > size(g%textures)) cycle
                    if (.not. g%textures(bt%texture)%ready) cycle
                    set = merge(g%textures(bt%texture)%set_linear, &
                        g%textures(bt%texture)%set_nearest, bt%linear)
                    call vkCmdBindPipeline(g%cmd, 0_c_int, g%tex_pipe)
                    call vkCmdBindDescriptorSets(g%cmd, 0_c_int, g%tex_layout, 0_c_int32_t, &
                        1_c_int32_t, set, 0_c_int32_t, c_null_ptr)
                    call vkCmdPushConstants(g%cmd, g%tex_layout, 1_c_int32_t, 0_c_int32_t, &
                        48_c_int32_t, c_loc(push))
                    vbufs(1) = g%verts%buffer
                    voffs(1) = 0
                    call vkCmdBindVertexBuffers(g%cmd, 0_c_int32_t, 1_c_int32_t, vbufs(1), &
                        voffs(1))
                    call vkCmdBindIndexBuffer(g%cmd, g%idx%buffer, 0_c_int64_t, 1_c_int)
                    call vkCmdDrawIndexed(g%cmd, int(bt%count, c_int32_t), 1_c_int32_t, &
                        int(bt%first, c_int32_t), 0_c_int32_t, 0_c_int32_t)
                end select
            end associate
        end do
        call vkCmdEndRendering(g%cmd)
    end subroutine record_batches

    subroutine barrier(g, image, old, new, src_access, dst_access, src_stage, dst_stage)
        type(gfx_gpu_t), intent(inout) :: g
        integer(c_int64_t), intent(in) :: image
        integer(c_int), intent(in) :: old, new
        integer(c_int32_t), intent(in) :: src_access, dst_access, src_stage, dst_stage
        type(VkImageMemoryBarrier) :: b
        b%src_access = src_access
        b%dst_access = dst_access
        b%old_layout = old
        b%new_layout = new
        b%image = image
        call vkCmdPipelineBarrier(g%cmd, src_stage, dst_stage, 0_c_int32_t, 0_c_int32_t, &
            c_null_ptr, 0_c_int32_t, c_null_ptr, 1_c_int32_t, b)
    end subroutine barrier

    subroutine gpu_read(g, rgba)
        !! The last offscreen frame as RGBA bytes (4, width, height).
        type(gfx_gpu_t), intent(inout) :: g
        integer(int8), allocatable, intent(out) :: rgba(:, :, :)
        integer(int8), pointer :: src(:)
        allocate (rgba(4, g%width, g%height))
        rgba = 0
        if (g%window .or. .not. g%active) return
        call wait_idle(g)
        call c_f_pointer(g%readback%mapped, src, [4 * g%width * g%height])
        rgba = reshape(src, [4, g%width, g%height])
    end subroutine gpu_read

    subroutine gpu_close(g)
        type(gfx_gpu_t), intent(inout) :: g
        integer :: k
        if (.not. c_associated(g%device)) return
        if (vkDeviceWaitIdle(g%device) /= VK_SUCCESS) continue
        do k = 1, size(g%textures)
            call gpu_texture_release(g, k)
        end do
        do k = 1, size(g%layers)
            call free_buffer(g, g%layers(k)%buf)
        end do
        call free_buffer(g, g%shapes)
        call free_buffer(g, g%verts)
        call free_buffer(g, g%idx)
        call free_buffer(g, g%staging)
        if (g%window) then
            call release_swapchain_images(g)
            call vkDestroySwapchainKHR(g%device, g%swapchain, c_null_ptr)
        else
            call vkDestroyImageView(g%device, g%target_view, c_null_ptr)
            call vkDestroyImage(g%device, g%target, c_null_ptr)
            call vkFreeMemory(g%device, g%target_memory, c_null_ptr)
            call free_buffer(g, g%readback)
        end if
        call vkDestroySemaphore(g%device, g%acquired, c_null_ptr)
        call vkDestroyFence(g%device, g%fence, c_null_ptr)
        call vkDestroyCommandPool(g%device, g%pool_cmd, c_null_ptr)
        call vkDestroyPipeline(g%device, g%shape_pipe, c_null_ptr)
        call vkDestroyPipeline(g%device, g%tex_pipe, c_null_ptr)
        call vkDestroyPipelineLayout(g%device, g%shape_layout, c_null_ptr)
        call vkDestroyPipelineLayout(g%device, g%tex_layout, c_null_ptr)
        call vkDestroySampler(g%device, g%nearest, c_null_ptr)
        call vkDestroySampler(g%device, g%linear, c_null_ptr)
        call vkDestroyDescriptorPool(g%device, g%pool, c_null_ptr)
        call vkDestroyDescriptorSetLayout(g%device, g%set_storage, c_null_ptr)
        call vkDestroyDescriptorSetLayout(g%device, g%set_sampler, c_null_ptr)
        call vkDestroyDevice(g%device, c_null_ptr)
        if (g%surface /= 0) call vkDestroySurfaceKHR(g%instance, g%surface, c_null_ptr)
        call vkDestroyInstance(g%instance, c_null_ptr)
        g%active = .false.
        g%device = c_null_ptr
    end subroutine gpu_close

end module fortgfx_gpu
