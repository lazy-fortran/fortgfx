module triangle_state
    !! Vulkan objects of the running example and the functions it calls.
    use iso_c_binding
    use fortgfx_vulkan
    implicit none
    public

    type(c_ptr) :: instance = c_null_ptr, physical = c_null_ptr, device = c_null_ptr, &
        queue = c_null_ptr, cmd = c_null_ptr
    integer(c_int64_t) :: surface = 0, swapchain = 0, layout = 0, pipeline = 0, pool = 0, &
        acquired = 0, in_flight = 0
    integer(c_int32_t) :: family = 0
    integer(c_int) :: format = 0, color_space = 0
    type(VkExtent2D) :: extent
    integer(c_int64_t), allocatable, target :: images(:), views(:), rendered(:)

    procedure(fn_create_instance), pointer :: vkCreateInstance
    procedure(fn_create_xcb_surface), pointer :: vkCreateXcbSurfaceKHR
    procedure(fn_enumerate), pointer :: vkEnumeratePhysicalDevices
    procedure(fn_queue_families), pointer :: vkGetPhysicalDeviceQueueFamilyProperties
    procedure(fn_surface_support), pointer :: vkGetPhysicalDeviceSurfaceSupportKHR
    procedure(fn_create_device), pointer :: vkCreateDevice
    procedure(fn_get_queue), pointer :: vkGetDeviceQueue
    procedure(fn_surface_caps), pointer :: vkGetPhysicalDeviceSurfaceCapabilitiesKHR
    procedure(fn_surface_list), pointer :: vkGetPhysicalDeviceSurfaceFormatsKHR
    procedure(fn_create_swapchain), pointer :: vkCreateSwapchainKHR
    procedure(fn_swapchain_images), pointer :: vkGetSwapchainImagesKHR
    procedure(fn_create_image_view), pointer :: vkCreateImageView
    procedure(fn_destroy), pointer :: vkDestroyImageView, vkDestroySwapchainKHR, &
        vkDestroySemaphore, vkDestroyFence, vkDestroyPipeline, vkDestroyPipelineLayout, &
        vkDestroyCommandPool, vkDestroyShaderModule
    procedure(fn_destroy_dispatchable), pointer :: vkDestroyDevice, vkDestroyInstance
    procedure(fn_destroy_surface), pointer :: vkDestroySurfaceKHR
    procedure(fn_create_shader_module), pointer :: vkCreateShaderModule
    procedure(fn_create_pipeline_layout), pointer :: vkCreatePipelineLayout
    procedure(fn_create_pipelines), pointer :: vkCreateGraphicsPipelines
    procedure(fn_create_command_pool), pointer :: vkCreateCommandPool
    procedure(fn_allocate_command_buffers), pointer :: vkAllocateCommandBuffers
    procedure(fn_create_semaphore), pointer :: vkCreateSemaphore
    procedure(fn_create_fence), pointer :: vkCreateFence
    procedure(fn_wait_fences), pointer :: vkWaitForFences
    procedure(fn_reset_fences), pointer :: vkResetFences
    procedure(fn_acquire_image), pointer :: vkAcquireNextImageKHR
    procedure(fn_reset_command_buffer), pointer :: vkResetCommandBuffer
    procedure(fn_begin_command_buffer), pointer :: vkBeginCommandBuffer
    procedure(fn_end_command_buffer), pointer :: vkEndCommandBuffer
    procedure(fn_cmd_pipeline_barrier), pointer :: vkCmdPipelineBarrier
    procedure(fn_cmd_begin_rendering), pointer :: vkCmdBeginRendering
    procedure(fn_cmd_end_rendering), pointer :: vkCmdEndRendering
    procedure(fn_cmd_bind_pipeline), pointer :: vkCmdBindPipeline
    procedure(fn_cmd_set_viewport), pointer :: vkCmdSetViewport
    procedure(fn_cmd_set_scissor), pointer :: vkCmdSetScissor
    procedure(fn_cmd_push_constants), pointer :: vkCmdPushConstants
    procedure(fn_cmd_draw), pointer :: vkCmdDraw
    procedure(fn_queue_submit), pointer :: vkQueueSubmit
    procedure(fn_queue_present), pointer :: vkQueuePresentKHR
    procedure(fn_device_wait_idle), pointer :: vkDeviceWaitIdle

    character(len=*, kind=c_char), parameter :: EXT_SURFACE = "VK_KHR_surface" // c_null_char, &
        EXT_XCB = "VK_KHR_xcb_surface" // c_null_char, &
        EXT_SWAPCHAIN = "VK_KHR_swapchain" // c_null_char, MAIN = "main" // c_null_char

contains

    subroutine create_instance()
        type(VkApplicationInfo), target :: app
        type(VkInstanceCreateInfo) :: info
        character(len=len(EXT_SURFACE), kind=c_char), target :: e1
        character(len=len(EXT_XCB), kind=c_char), target :: e2
        type(c_ptr), target :: names(2)
        call c_f_procpointer(vk_proc(c_null_ptr, "vkCreateInstance"), vkCreateInstance)
        e1 = EXT_SURFACE
        e2 = EXT_XCB
        names = [c_loc(e1), c_loc(e2)]
        app%api_version = ishft(1, 22) + ishft(3, 12)
        info%app_info = c_loc(app)
        info%extension_count = 2
        info%extensions = c_loc(names)
        call vk_check(vkCreateInstance(info, c_null_ptr, instance), "vkCreateInstance")
        call load_instance_functions()
    end subroutine create_instance

    subroutine load_instance_functions()
        call c_f_procpointer(vk_proc(instance, "vkCreateXcbSurfaceKHR"), vkCreateXcbSurfaceKHR)
        call c_f_procpointer(vk_proc(instance, "vkEnumeratePhysicalDevices"), &
            vkEnumeratePhysicalDevices)
        call c_f_procpointer(vk_proc(instance, "vkGetPhysicalDeviceQueueFamilyProperties"), &
            vkGetPhysicalDeviceQueueFamilyProperties)
        call c_f_procpointer(vk_proc(instance, "vkGetPhysicalDeviceSurfaceSupportKHR"), &
            vkGetPhysicalDeviceSurfaceSupportKHR)
        call c_f_procpointer(vk_proc(instance, "vkCreateDevice"), vkCreateDevice)
        call c_f_procpointer(vk_proc(instance, "vkGetDeviceQueue"), vkGetDeviceQueue)
        call c_f_procpointer(vk_proc(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR"), &
            vkGetPhysicalDeviceSurfaceCapabilitiesKHR)
        call c_f_procpointer(vk_proc(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR"), &
            vkGetPhysicalDeviceSurfaceFormatsKHR)
        call c_f_procpointer(vk_proc(instance, "vkCreateSwapchainKHR"), vkCreateSwapchainKHR)
        call c_f_procpointer(vk_proc(instance, "vkGetSwapchainImagesKHR"), &
            vkGetSwapchainImagesKHR)
        call c_f_procpointer(vk_proc(instance, "vkCreateImageView"), vkCreateImageView)
        call c_f_procpointer(vk_proc(instance, "vkDestroyImageView"), vkDestroyImageView)
        call c_f_procpointer(vk_proc(instance, "vkDestroySwapchainKHR"), vkDestroySwapchainKHR)
        call c_f_procpointer(vk_proc(instance, "vkDestroySemaphore"), vkDestroySemaphore)
        call c_f_procpointer(vk_proc(instance, "vkDestroyFence"), vkDestroyFence)
        call c_f_procpointer(vk_proc(instance, "vkDestroyPipeline"), vkDestroyPipeline)
        call c_f_procpointer(vk_proc(instance, "vkDestroyPipelineLayout"), &
            vkDestroyPipelineLayout)
        call c_f_procpointer(vk_proc(instance, "vkDestroyCommandPool"), vkDestroyCommandPool)
        call c_f_procpointer(vk_proc(instance, "vkDestroyShaderModule"), vkDestroyShaderModule)
        call c_f_procpointer(vk_proc(instance, "vkDestroyDevice"), vkDestroyDevice)
        call c_f_procpointer(vk_proc(instance, "vkDestroyInstance"), vkDestroyInstance)
        call c_f_procpointer(vk_proc(instance, "vkDestroySurfaceKHR"), vkDestroySurfaceKHR)
        call c_f_procpointer(vk_proc(instance, "vkCreateShaderModule"), vkCreateShaderModule)
        call c_f_procpointer(vk_proc(instance, "vkCreatePipelineLayout"), vkCreatePipelineLayout)
        call c_f_procpointer(vk_proc(instance, "vkCreateGraphicsPipelines"), &
            vkCreateGraphicsPipelines)
        call c_f_procpointer(vk_proc(instance, "vkCreateCommandPool"), vkCreateCommandPool)
        call c_f_procpointer(vk_proc(instance, "vkAllocateCommandBuffers"), &
            vkAllocateCommandBuffers)
        call c_f_procpointer(vk_proc(instance, "vkCreateSemaphore"), vkCreateSemaphore)
        call c_f_procpointer(vk_proc(instance, "vkCreateFence"), vkCreateFence)
        call c_f_procpointer(vk_proc(instance, "vkWaitForFences"), vkWaitForFences)
        call c_f_procpointer(vk_proc(instance, "vkResetFences"), vkResetFences)
        call c_f_procpointer(vk_proc(instance, "vkAcquireNextImageKHR"), vkAcquireNextImageKHR)
        call c_f_procpointer(vk_proc(instance, "vkResetCommandBuffer"), vkResetCommandBuffer)
        call c_f_procpointer(vk_proc(instance, "vkBeginCommandBuffer"), vkBeginCommandBuffer)
        call c_f_procpointer(vk_proc(instance, "vkEndCommandBuffer"), vkEndCommandBuffer)
        call c_f_procpointer(vk_proc(instance, "vkCmdPipelineBarrier"), vkCmdPipelineBarrier)
        call c_f_procpointer(vk_proc(instance, "vkCmdBeginRendering"), vkCmdBeginRendering)
        call c_f_procpointer(vk_proc(instance, "vkCmdEndRendering"), vkCmdEndRendering)
        call c_f_procpointer(vk_proc(instance, "vkCmdBindPipeline"), vkCmdBindPipeline)
        call c_f_procpointer(vk_proc(instance, "vkCmdSetViewport"), vkCmdSetViewport)
        call c_f_procpointer(vk_proc(instance, "vkCmdSetScissor"), vkCmdSetScissor)
        call c_f_procpointer(vk_proc(instance, "vkCmdPushConstants"), vkCmdPushConstants)
        call c_f_procpointer(vk_proc(instance, "vkCmdDraw"), vkCmdDraw)
        call c_f_procpointer(vk_proc(instance, "vkQueueSubmit"), vkQueueSubmit)
        call c_f_procpointer(vk_proc(instance, "vkQueuePresentKHR"), vkQueuePresentKHR)
        call c_f_procpointer(vk_proc(instance, "vkDeviceWaitIdle"), vkDeviceWaitIdle)
    end subroutine load_instance_functions

    subroutine create_surface(conn, window)
        type(c_ptr), intent(in) :: conn
        integer(c_int32_t), intent(in) :: window
        type(VkXcbSurfaceCreateInfoKHR) :: info
        info%connection = conn
        info%window = window
        call vk_check(vkCreateXcbSurfaceKHR(instance, info, c_null_ptr, surface), &
            "vkCreateXcbSurfaceKHR")
    end subroutine create_surface

    subroutine create_device()
        !! The first GPU with a queue family that draws and presents to the window.
        type(c_ptr), allocatable, target :: devices(:)
        type(VkQueueFamilyProperties), allocatable, target :: props(:)
        type(VkDeviceQueueCreateInfo), target :: qinfo
        type(VkDynamicRenderingFeatures), target :: dyn
        type(VkDeviceCreateInfo) :: info
        real(c_float), target :: priority
        character(len=len(EXT_SWAPCHAIN), kind=c_char), target :: e1
        type(c_ptr), target :: names(1)
        integer(c_int32_t) :: n, nf, supported
        integer :: d, f
        call vk_check(vkEnumeratePhysicalDevices(instance, n, c_null_ptr), "enumerate GPUs")
        if (n == 0) error stop "no Vulkan GPU"
        allocate (devices(n))
        call vk_check(vkEnumeratePhysicalDevices(instance, n, c_loc(devices)), "enumerate GPUs")
        do d = 1, int(n)
            call vkGetPhysicalDeviceQueueFamilyProperties(devices(d), nf, c_null_ptr)
            if (allocated(props)) deallocate (props)
            allocate (props(nf))
            call vkGetPhysicalDeviceQueueFamilyProperties(devices(d), nf, c_loc(props))
            do f = 1, int(nf)
                if (iand(props(f)%flags, 1) == 0) cycle
                call vk_check(vkGetPhysicalDeviceSurfaceSupportKHR(devices(d), &
                    int(f - 1, c_int32_t), surface, supported), "surface support")
                if (supported == 0) cycle
                physical = devices(d)
                family = int(f - 1, c_int32_t)
                exit
            end do
            if (c_associated(physical)) exit
        end do
        if (.not. c_associated(physical)) error stop "no GPU can present to this window"
        priority = 1.0
        qinfo%family = family
        qinfo%count = 1
        qinfo%priorities = c_loc(priority)
        dyn%dynamic_rendering = 1
        e1 = EXT_SWAPCHAIN
        names = [c_loc(e1)]
        info%next = c_loc(dyn)
        info%queue_info_count = 1
        info%queue_infos = c_loc(qinfo)
        info%extension_count = 1
        info%extensions = c_loc(names)
        call vk_check(vkCreateDevice(physical, info, c_null_ptr, device), "vkCreateDevice")
        call vkGetDeviceQueue(device, family, 0_c_int32_t, queue)
    end subroutine create_device

    subroutine choose_format()
        !! Plain 8-bit BGRA without sRGB encoding, as the old fixed pipeline drew.
        type(VkSurfaceFormatKHR), allocatable, target :: formats(:)
        integer(c_int32_t) :: n
        integer :: k
        call vk_check(vkGetPhysicalDeviceSurfaceFormatsKHR(physical, surface, n, c_null_ptr), &
            "surface formats")
        allocate (formats(n))
        call vk_check(vkGetPhysicalDeviceSurfaceFormatsKHR(physical, surface, n, &
            c_loc(formats)), "surface formats")
        format = formats(1)%format
        color_space = formats(1)%color_space
        do k = 1, int(n)
            if (formats(k)%format == 44) then
                format = formats(k)%format
                color_space = formats(k)%color_space
            end if
        end do
    end subroutine choose_format

    logical function create_swapchain(width, height) result(ok)
        !! False while the window has no area (minimised).
        integer, intent(in) :: width, height
        type(VkSurfaceCapabilitiesKHR) :: caps
        type(VkSwapchainCreateInfoKHR) :: info
        type(VkImageViewCreateInfo) :: vinfo
        type(VkSemaphoreCreateInfo) :: sinfo
        integer(c_int32_t) :: n
        integer :: k
        call vk_check(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical, surface, caps), &
            "surface capabilities")
        extent = caps%current
        if (extent%width == -1) extent = VkExtent2D(width, height)
        ok = extent%width > 0
        if (.not. ok) return
        ok = extent%height > 0
        if (.not. ok) return
        info%surface = surface
        info%min_images = caps%min_images + 1
        if (caps%max_images > 0) info%min_images = min(info%min_images, caps%max_images)
        info%format = format
        info%color_space = color_space
        info%extent = extent
        info%usage = 16
        info%transform = caps%current_transform
        info%composite_alpha = 1
        info%present_mode = 2
        info%old_swapchain = swapchain
        call vk_check(vkCreateSwapchainKHR(device, info, c_null_ptr, swapchain), &
            "vkCreateSwapchainKHR")
        if (info%old_swapchain /= 0) call vkDestroySwapchainKHR(device, info%old_swapchain, &
            c_null_ptr)
        call vk_check(vkGetSwapchainImagesKHR(device, swapchain, n, c_null_ptr), &
            "swapchain images")
        allocate (images(n), views(n), rendered(n))
        call vk_check(vkGetSwapchainImagesKHR(device, swapchain, n, c_loc(images)), &
            "swapchain images")
        vinfo%format = format
        do k = 1, int(n)
            vinfo%image = images(k)
            call vk_check(vkCreateImageView(device, vinfo, c_null_ptr, views(k)), &
                "vkCreateImageView")
            ! One semaphore per image: presenting it waits until that image is drawn.
            call vk_check(vkCreateSemaphore(device, sinfo, c_null_ptr, rendered(k)), &
                "vkCreateSemaphore")
        end do
    end function create_swapchain

    subroutine release_swapchain_images()
        integer :: k
        if (.not. allocated(views)) return
        do k = 1, size(views)
            call vkDestroyImageView(device, views(k), c_null_ptr)
            call vkDestroySemaphore(device, rendered(k), c_null_ptr)
        end do
        deallocate (images, views, rendered)
    end subroutine release_swapchain_images

    integer(c_int64_t) function load_shader(path) result(module)
        character(*), intent(in) :: path
        integer(c_int32_t), allocatable, target :: words(:)
        type(VkShaderModuleCreateInfo) :: info
        integer :: unit, bytes, ios
        open (newunit=unit, file=path, access="stream", form="unformatted", status="old", &
            iostat=ios)
        if (ios /= 0) error stop "cannot open shader " // path
        inquire (unit=unit, size=bytes)
        allocate (words(bytes / 4))
        read (unit) words
        close (unit)
        info%code_size = int(bytes, c_size_t)
        info%code = c_loc(words)
        call vk_check(vkCreateShaderModule(device, info, c_null_ptr, module), path)
    end function load_shader

    subroutine create_pipeline(dir)
        character(*), intent(in) :: dir
        type(VkPipelineShaderStageCreateInfo), target :: stages(2)
        type(VkPipelineVertexInputStateCreateInfo), target :: vertex_input
        type(VkPipelineInputAssemblyStateCreateInfo), target :: assembly
        type(VkPipelineViewportStateCreateInfo), target :: viewport
        type(VkPipelineRasterizationStateCreateInfo), target :: raster
        type(VkPipelineMultisampleStateCreateInfo), target :: multisample
        type(VkPipelineColorBlendAttachmentState), target :: attachment
        type(VkPipelineColorBlendStateCreateInfo), target :: blend
        type(VkPipelineDynamicStateCreateInfo), target :: dynamic
        type(VkPipelineRenderingCreateInfo), target :: rendering
        type(VkPushConstantRange), target :: push
        type(VkPipelineLayoutCreateInfo) :: linfo
        type(VkGraphicsPipelineCreateInfo) :: info
        integer(c_int), target :: dynamic_states(2), color_format(1)
        character(len=len(MAIN), kind=c_char), target :: entry
        integer :: k

        push = VkPushConstantRange(stages=1, offset=0, size=8)
        linfo%push_range_count = 1
        linfo%push_ranges = c_loc(push)
        call vk_check(vkCreatePipelineLayout(device, linfo, c_null_ptr, layout), &
            "vkCreatePipelineLayout")

        entry = MAIN
        stages(1)%stage = 1
        stages(1)%module = load_shader(dir // "/triangle.vert.spv")
        stages(2)%stage = 16
        stages(2)%module = load_shader(dir // "/triangle.frag.spv")
        do k = 1, 2
            stages(k)%name = c_loc(entry)
        end do
        blend%attachment_count = 1
        blend%attachments = c_loc(attachment)
        dynamic_states = [0, 1]
        dynamic%count = 2
        dynamic%states = c_loc(dynamic_states)
        color_format(1) = format
        rendering%color_count = 1
        rendering%color_formats = c_loc(color_format)

        info%next = c_loc(rendering)
        info%stage_count = 2
        info%stages = c_loc(stages)
        info%vertex_input = c_loc(vertex_input)
        info%input_assembly = c_loc(assembly)
        info%viewport = c_loc(viewport)
        info%rasterization = c_loc(raster)
        info%multisample = c_loc(multisample)
        info%color_blend = c_loc(blend)
        info%dynamic = c_loc(dynamic)
        info%layout = layout
        call vk_check(vkCreateGraphicsPipelines(device, 0_c_int64_t, 1_c_int32_t, info, &
            c_null_ptr, pipeline), "vkCreateGraphicsPipelines")
        do k = 1, 2
            call vkDestroyShaderModule(device, stages(k)%module, c_null_ptr)
        end do
    end subroutine create_pipeline

    subroutine create_commands()
        type(VkCommandPoolCreateInfo) :: pinfo
        type(VkCommandBufferAllocateInfo) :: ainfo
        type(VkSemaphoreCreateInfo) :: sinfo
        type(VkFenceCreateInfo) :: finfo
        pinfo%flags = 2
        pinfo%family = family
        call vk_check(vkCreateCommandPool(device, pinfo, c_null_ptr, pool), "command pool")
        ainfo%pool = pool
        call vk_check(vkAllocateCommandBuffers(device, ainfo, cmd), "command buffer")
        call vk_check(vkCreateSemaphore(device, sinfo, c_null_ptr, acquired), "semaphore")
        finfo%flags = 1
        call vk_check(vkCreateFence(device, finfo, c_null_ptr, in_flight), "fence")
    end subroutine create_commands

    integer(c_int) function draw_frame(angle) result(res)
        !! One frame; VK_ERROR_OUT_OF_DATE_KHR or VK_SUBOPTIMAL_KHR ask for a new swapchain.
        real, intent(in) :: angle
        type(VkCommandBufferBeginInfo) :: binfo
        type(VkImageMemoryBarrier) :: barrier
        type(VkRenderingAttachmentInfo), target :: colour
        type(VkRenderingInfo) :: rinfo
        type(VkSubmitInfo) :: submit
        type(VkPresentInfoKHR) :: present
        real(c_float), target :: push(2)
        integer(c_int32_t), target :: index, wait_stage
        integer(c_int64_t), target :: wait_sem, signal_sem, chain
        type(c_ptr), target :: buffers(1)

        call vk_check(vkWaitForFences(device, 1_c_int32_t, in_flight, 1_c_int32_t, &
            -1_c_int64_t), "vkWaitForFences")
        res = vkAcquireNextImageKHR(device, swapchain, -1_c_int64_t, acquired, 0_c_int64_t, &
            index)
        if (res == VK_ERROR_OUT_OF_DATE_KHR) return
        if (res /= VK_SUBOPTIMAL_KHR) call vk_check(res, "vkAcquireNextImageKHR")
        call vk_check(vkResetFences(device, 1_c_int32_t, in_flight), "vkResetFences")

        call vk_check(vkResetCommandBuffer(cmd, 0_c_int32_t), "vkResetCommandBuffer")
        call vk_check(vkBeginCommandBuffer(cmd, binfo), "vkBeginCommandBuffer")
        barrier%dst_access = 256
        barrier%old_layout = 0
        barrier%new_layout = 2
        barrier%image = images(index + 1)
        call vkCmdPipelineBarrier(cmd, 1024_c_int32_t, 1024_c_int32_t, 0_c_int32_t, &
            0_c_int32_t, c_null_ptr, 0_c_int32_t, c_null_ptr, 1_c_int32_t, barrier)

        colour%view = views(index + 1)
        colour%layout = 2
        colour%load_op = 1
        colour%store_op = 0
        colour%clear = [0.0, 0.0, 0.0, 1.0]
        rinfo%area%extent = extent
        rinfo%color_count = 1
        rinfo%colors = c_loc(colour)
        call vkCmdBeginRendering(cmd, rinfo)
        call vkCmdBindPipeline(cmd, 0_c_int, pipeline)
        call vkCmdSetViewport(cmd, 0_c_int32_t, 1_c_int32_t, VkViewport(width= &
            real(extent%width), height=real(extent%height)))
        call vkCmdSetScissor(cmd, 0_c_int32_t, 1_c_int32_t, VkRect2D(extent=extent))
        push = [angle, real(extent%width) / real(extent%height)]
        call vkCmdPushConstants(cmd, layout, 1_c_int32_t, 0_c_int32_t, 8_c_int32_t, c_loc(push))
        call vkCmdDraw(cmd, 3_c_int32_t, 1_c_int32_t, 0_c_int32_t, 0_c_int32_t)
        call vkCmdEndRendering(cmd)

        barrier%src_access = 256
        barrier%dst_access = 0
        barrier%old_layout = 2
        barrier%new_layout = 1000001002
        call vkCmdPipelineBarrier(cmd, 1024_c_int32_t, 8192_c_int32_t, 0_c_int32_t, &
            0_c_int32_t, c_null_ptr, 0_c_int32_t, c_null_ptr, 1_c_int32_t, barrier)
        call vk_check(vkEndCommandBuffer(cmd), "vkEndCommandBuffer")

        wait_sem = acquired
        wait_stage = 1024
        signal_sem = rendered(index + 1)
        buffers(1) = cmd
        submit%wait_count = 1
        submit%waits = c_loc(wait_sem)
        submit%wait_stages = c_loc(wait_stage)
        submit%buffer_count = 1
        submit%buffers = c_loc(buffers)
        submit%signal_count = 1
        submit%signals = c_loc(signal_sem)
        call vk_check(vkQueueSubmit(queue, 1_c_int32_t, submit, in_flight), "vkQueueSubmit")

        chain = swapchain
        present%wait_count = 1
        present%waits = c_loc(signal_sem)
        present%swapchain_count = 1
        present%swapchains = c_loc(chain)
        present%indices = c_loc(index)
        res = vkQueuePresentKHR(queue, present)
        if (res /= VK_ERROR_OUT_OF_DATE_KHR .and. res /= VK_SUBOPTIMAL_KHR) &
            call vk_check(res, "vkQueuePresentKHR")
    end function draw_frame

    subroutine shutdown()
        call vk_check(vkDeviceWaitIdle(device), "vkDeviceWaitIdle")
        call release_swapchain_images()
        call vkDestroySwapchainKHR(device, swapchain, c_null_ptr)
        call vkDestroySemaphore(device, acquired, c_null_ptr)
        call vkDestroyFence(device, in_flight, c_null_ptr)
        call vkDestroyCommandPool(device, pool, c_null_ptr)
        call vkDestroyPipeline(device, pipeline, c_null_ptr)
        call vkDestroyPipelineLayout(device, layout, c_null_ptr)
        call vkDestroyDevice(device, c_null_ptr)
        call vkDestroySurfaceKHR(instance, surface, c_null_ptr)
        call vkDestroyInstance(instance, c_null_ptr)
    end subroutine shutdown

end module triangle_state

program triangle
    !! A spinning colour triangle in an X11 window, drawn with Vulkan from Fortran.
    !! Escape, q or closing the window ends it.
    use iso_c_binding, only: c_int
    use fortgfx_vulkan, only: vk_open_loader, VK_SUCCESS
    use fortgfx_xcb, only: xcb_window_t, window_open, window_poll, window_close, EV_QUIT, EV_RESIZE
    use triangle_state
    implicit none
    type(xcb_window_t) :: win
    character(4096) :: exe
    character(:), allocatable :: dir
    integer :: ev, slash
    integer(8) :: t0, t, rate
    integer(c_int) :: res
    logical :: have_chain

    call get_command_argument(0, exe)
    slash = index(exe, "/", back=.true.)
    dir = "."
    if (slash > 0) dir = exe(:slash - 1)

    if (.not. vk_open_loader()) error stop "no Vulkan loader (libvulkan.so.1) on this system"
    win = window_open("Spinning triangle - Fortran and Vulkan", 640, 480)
    call create_instance()
    call create_surface(win%conn, win%id)
    call create_device()
    call choose_format()
    have_chain = create_swapchain(win%width, win%height)
    call create_pipeline(dir)
    call create_commands()

    call system_clock(t0, rate)
    do
        ev = window_poll(win)
        if (ev == EV_QUIT) exit
        if (ev == EV_RESIZE .or. .not. have_chain) then
            have_chain = rebuild()
            if (.not. have_chain) cycle
        end if
        call system_clock(t)
        res = draw_frame(real(t - t0) / real(rate) * 1.5)
        if (res /= VK_SUCCESS) have_chain = rebuild()
    end do
    call shutdown()
    call window_close(win)

contains

    logical function rebuild()
        call vk_check(vkDeviceWaitIdle(device), "vkDeviceWaitIdle")
        call release_swapchain_images()
        rebuild = create_swapchain(win%width, win%height)
    end function rebuild

end program triangle
