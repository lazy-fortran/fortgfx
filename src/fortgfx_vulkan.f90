module fortgfx_vulkan
    !! The Vulkan 1.3 subset the triangle needs. The loader is opened at run time,
    !! so a machine without Vulkan reports it instead of failing to start.
    use iso_c_binding
    implicit none
    public

    integer(c_int), parameter :: VK_SUCCESS = 0, VK_SUBOPTIMAL_KHR = 1000001003, &
        VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    integer(c_int), parameter :: ST_APPLICATION_INFO = 0, ST_INSTANCE_CREATE_INFO = 1, &
        ST_DEVICE_QUEUE_CREATE_INFO = 2, ST_DEVICE_CREATE_INFO = 3, ST_SUBMIT_INFO = 4, &
        ST_FENCE_CREATE_INFO = 8, ST_SEMAPHORE_CREATE_INFO = 9, &
        ST_IMAGE_VIEW_CREATE_INFO = 15, ST_SHADER_MODULE_CREATE_INFO = 16, &
        ST_PIPELINE_SHADER_STAGE_CREATE_INFO = 18, ST_VERTEX_INPUT_STATE = 19, &
        ST_INPUT_ASSEMBLY_STATE = 20, ST_VIEWPORT_STATE = 22, ST_RASTERIZATION_STATE = 23, &
        ST_MULTISAMPLE_STATE = 24, ST_COLOR_BLEND_STATE = 26, ST_DYNAMIC_STATE = 27, &
        ST_GRAPHICS_PIPELINE_CREATE_INFO = 28, ST_PIPELINE_LAYOUT_CREATE_INFO = 30, &
        ST_COMMAND_POOL_CREATE_INFO = 39, ST_COMMAND_BUFFER_ALLOCATE_INFO = 40, &
        ST_COMMAND_BUFFER_BEGIN_INFO = 42, ST_IMAGE_MEMORY_BARRIER = 45, &
        ST_SWAPCHAIN_CREATE_INFO_KHR = 1000001000, ST_PRESENT_INFO_KHR = 1000001001, &
        ST_XCB_SURFACE_CREATE_INFO_KHR = 1000005000, ST_RENDERING_INFO = 1000044000, &
        ST_RENDERING_ATTACHMENT_INFO = 1000044001, &
        ST_PIPELINE_RENDERING_CREATE_INFO = 1000044002, &
        ST_DYNAMIC_RENDERING_FEATURES = 1000044003

    type, bind(C) :: VkExtent2D
        integer(c_int32_t) :: width = 0, height = 0
    end type
    type, bind(C) :: VkRect2D
        integer(c_int32_t) :: x = 0, y = 0
        type(VkExtent2D) :: extent
    end type
    type, bind(C) :: VkViewport
        real(c_float) :: x = 0, y = 0, width = 0, height = 0, min_depth = 0, max_depth = 1
    end type
    type, bind(C) :: VkSubresourceRange
        integer(c_int32_t) :: aspect = 1, base_mip = 0, levels = 1, base_layer = 0, layers = 1
    end type

    type, bind(C) :: VkApplicationInfo
        integer(c_int) :: s_type = ST_APPLICATION_INFO
        type(c_ptr) :: next = c_null_ptr, app_name = c_null_ptr
        integer(c_int32_t) :: app_version = 0
        type(c_ptr) :: engine_name = c_null_ptr
        integer(c_int32_t) :: engine_version = 0, api_version = 0
    end type
    type, bind(C) :: VkInstanceCreateInfo
        integer(c_int) :: s_type = ST_INSTANCE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        type(c_ptr) :: app_info = c_null_ptr
        integer(c_int32_t) :: layer_count = 0
        type(c_ptr) :: layers = c_null_ptr
        integer(c_int32_t) :: extension_count = 0
        type(c_ptr) :: extensions = c_null_ptr
    end type
    type, bind(C) :: VkXcbSurfaceCreateInfoKHR
        integer(c_int) :: s_type = ST_XCB_SURFACE_CREATE_INFO_KHR
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        type(c_ptr) :: connection = c_null_ptr
        integer(c_int32_t) :: window = 0
    end type
    type, bind(C) :: VkQueueFamilyProperties
        integer(c_int32_t) :: flags = 0, count = 0, timestamp_bits = 0, granularity(3) = 0
    end type
    type, bind(C) :: VkDeviceQueueCreateInfo
        integer(c_int) :: s_type = ST_DEVICE_QUEUE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, family = 0, count = 0
        type(c_ptr) :: priorities = c_null_ptr
    end type
    type, bind(C) :: VkDynamicRenderingFeatures
        integer(c_int) :: s_type = ST_DYNAMIC_RENDERING_FEATURES
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: dynamic_rendering = 0
    end type
    type, bind(C) :: VkDeviceCreateInfo
        integer(c_int) :: s_type = ST_DEVICE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, queue_info_count = 0
        type(c_ptr) :: queue_infos = c_null_ptr
        integer(c_int32_t) :: layer_count = 0
        type(c_ptr) :: layers = c_null_ptr
        integer(c_int32_t) :: extension_count = 0
        type(c_ptr) :: extensions = c_null_ptr, features = c_null_ptr
    end type
    type, bind(C) :: VkSurfaceCapabilitiesKHR
        integer(c_int32_t) :: min_images = 0, max_images = 0
        type(VkExtent2D) :: current, min_extent, max_extent
        integer(c_int32_t) :: max_layers = 0, transforms = 0, current_transform = 0, &
            composite_alpha = 0, usage = 0
    end type
    type, bind(C) :: VkSurfaceFormatKHR
        integer(c_int) :: format = 0, color_space = 0
    end type
    type, bind(C) :: VkSwapchainCreateInfoKHR
        integer(c_int) :: s_type = ST_SWAPCHAIN_CREATE_INFO_KHR
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        integer(c_int64_t) :: surface = 0
        integer(c_int32_t) :: min_images = 0
        integer(c_int) :: format = 0, color_space = 0
        type(VkExtent2D) :: extent
        integer(c_int32_t) :: layers = 1, usage = 0
        integer(c_int) :: sharing = 0
        integer(c_int32_t) :: family_count = 0
        type(c_ptr) :: families = c_null_ptr
        integer(c_int) :: transform = 0, composite_alpha = 0, present_mode = 0
        integer(c_int32_t) :: clipped = 1
        integer(c_int64_t) :: old_swapchain = 0
    end type
    type, bind(C) :: VkImageViewCreateInfo
        integer(c_int) :: s_type = ST_IMAGE_VIEW_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        integer(c_int64_t) :: image = 0
        integer(c_int) :: view_type = 1, format = 0, components(4) = 0
        type(VkSubresourceRange) :: range
    end type
    type, bind(C) :: VkShaderModuleCreateInfo
        integer(c_int) :: s_type = ST_SHADER_MODULE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        integer(c_size_t) :: code_size = 0
        type(c_ptr) :: code = c_null_ptr
    end type
    type, bind(C) :: VkPipelineShaderStageCreateInfo
        integer(c_int) :: s_type = ST_PIPELINE_SHADER_STAGE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, stage = 0
        integer(c_int64_t) :: module = 0
        type(c_ptr) :: name = c_null_ptr, specialization = c_null_ptr
    end type
    type, bind(C) :: VkPipelineVertexInputStateCreateInfo
        integer(c_int) :: s_type = ST_VERTEX_INPUT_STATE
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, binding_count = 0
        type(c_ptr) :: bindings = c_null_ptr
        integer(c_int32_t) :: attribute_count = 0
        type(c_ptr) :: attributes = c_null_ptr
    end type
    type, bind(C) :: VkPipelineInputAssemblyStateCreateInfo
        integer(c_int) :: s_type = ST_INPUT_ASSEMBLY_STATE
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        integer(c_int) :: topology = 3
        integer(c_int32_t) :: primitive_restart = 0
    end type
    type, bind(C) :: VkPipelineViewportStateCreateInfo
        integer(c_int) :: s_type = ST_VIEWPORT_STATE
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, viewport_count = 1
        type(c_ptr) :: viewports = c_null_ptr
        integer(c_int32_t) :: scissor_count = 1
        type(c_ptr) :: scissors = c_null_ptr
    end type
    type, bind(C) :: VkPipelineRasterizationStateCreateInfo
        integer(c_int) :: s_type = ST_RASTERIZATION_STATE
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, depth_clamp = 0, discard = 0
        integer(c_int) :: polygon_mode = 0
        integer(c_int32_t) :: cull_mode = 0
        integer(c_int) :: front_face = 0
        integer(c_int32_t) :: depth_bias = 0
        real(c_float) :: bias_constant = 0, bias_clamp = 0, bias_slope = 0, line_width = 1
    end type
    type, bind(C) :: VkPipelineMultisampleStateCreateInfo
        integer(c_int) :: s_type = ST_MULTISAMPLE_STATE
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, samples = 1, sample_shading = 0
        real(c_float) :: min_sample_shading = 0
        type(c_ptr) :: sample_mask = c_null_ptr
        integer(c_int32_t) :: alpha_to_coverage = 0, alpha_to_one = 0
    end type
    type, bind(C) :: VkPipelineColorBlendAttachmentState
        integer(c_int32_t) :: blend = 0
        integer(c_int) :: src_color = 0, dst_color = 0, color_op = 0, src_alpha = 0, &
            dst_alpha = 0, alpha_op = 0
        integer(c_int32_t) :: write_mask = 15
    end type
    type, bind(C) :: VkPipelineColorBlendStateCreateInfo
        integer(c_int) :: s_type = ST_COLOR_BLEND_STATE
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, logic_op_enable = 0
        integer(c_int) :: logic_op = 0
        integer(c_int32_t) :: attachment_count = 0
        type(c_ptr) :: attachments = c_null_ptr
        real(c_float) :: constants(4) = 0
    end type
    type, bind(C) :: VkPipelineDynamicStateCreateInfo
        integer(c_int) :: s_type = ST_DYNAMIC_STATE
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, count = 0
        type(c_ptr) :: states = c_null_ptr
    end type
    type, bind(C) :: VkPushConstantRange
        integer(c_int32_t) :: stages = 0, offset = 0, size = 0
    end type
    type, bind(C) :: VkPipelineLayoutCreateInfo
        integer(c_int) :: s_type = ST_PIPELINE_LAYOUT_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, set_layout_count = 0
        type(c_ptr) :: set_layouts = c_null_ptr
        integer(c_int32_t) :: push_range_count = 0
        type(c_ptr) :: push_ranges = c_null_ptr
    end type
    type, bind(C) :: VkPipelineRenderingCreateInfo
        integer(c_int) :: s_type = ST_PIPELINE_RENDERING_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: view_mask = 0, color_count = 0
        type(c_ptr) :: color_formats = c_null_ptr
        integer(c_int) :: depth_format = 0, stencil_format = 0
    end type
    type, bind(C) :: VkGraphicsPipelineCreateInfo
        integer(c_int) :: s_type = ST_GRAPHICS_PIPELINE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, stage_count = 0
        type(c_ptr) :: stages = c_null_ptr, vertex_input = c_null_ptr, &
            input_assembly = c_null_ptr, tessellation = c_null_ptr, viewport = c_null_ptr, &
            rasterization = c_null_ptr, multisample = c_null_ptr, depth_stencil = c_null_ptr, &
            color_blend = c_null_ptr, dynamic = c_null_ptr
        integer(c_int64_t) :: layout = 0, render_pass = 0
        integer(c_int32_t) :: subpass = 0
        integer(c_int64_t) :: base_pipeline = 0
        integer(c_int32_t) :: base_index = -1
    end type
    type, bind(C) :: VkCommandPoolCreateInfo
        integer(c_int) :: s_type = ST_COMMAND_POOL_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0, family = 0
    end type
    type, bind(C) :: VkCommandBufferAllocateInfo
        integer(c_int) :: s_type = ST_COMMAND_BUFFER_ALLOCATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int64_t) :: pool = 0
        integer(c_int) :: level = 0
        integer(c_int32_t) :: count = 1
    end type
    type, bind(C) :: VkCommandBufferBeginInfo
        integer(c_int) :: s_type = ST_COMMAND_BUFFER_BEGIN_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        type(c_ptr) :: inheritance = c_null_ptr
    end type
    type, bind(C) :: VkSemaphoreCreateInfo
        integer(c_int) :: s_type = ST_SEMAPHORE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
    end type
    type, bind(C) :: VkFenceCreateInfo
        integer(c_int) :: s_type = ST_FENCE_CREATE_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
    end type
    type, bind(C) :: VkImageMemoryBarrier
        integer(c_int) :: s_type = ST_IMAGE_MEMORY_BARRIER
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: src_access = 0, dst_access = 0
        integer(c_int) :: old_layout = 0, new_layout = 0
        integer(c_int32_t) :: src_family = -1, dst_family = -1
        integer(c_int64_t) :: image = 0
        type(VkSubresourceRange) :: range
    end type
    type, bind(C) :: VkRenderingAttachmentInfo
        integer(c_int) :: s_type = ST_RENDERING_ATTACHMENT_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int64_t) :: view = 0
        integer(c_int) :: layout = 0
        integer(c_int32_t) :: resolve_mode = 0
        integer(c_int64_t) :: resolve_view = 0
        integer(c_int) :: resolve_layout = 0, load_op = 0, store_op = 0
        real(c_float) :: clear(4) = 0
    end type
    type, bind(C) :: VkRenderingInfo
        integer(c_int) :: s_type = ST_RENDERING_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: flags = 0
        type(VkRect2D) :: area
        integer(c_int32_t) :: layer_count = 1, view_mask = 0, color_count = 0
        type(c_ptr) :: colors = c_null_ptr, depth = c_null_ptr, stencil = c_null_ptr
    end type
    type, bind(C) :: VkSubmitInfo
        integer(c_int) :: s_type = ST_SUBMIT_INFO
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: wait_count = 0
        type(c_ptr) :: waits = c_null_ptr, wait_stages = c_null_ptr
        integer(c_int32_t) :: buffer_count = 0
        type(c_ptr) :: buffers = c_null_ptr
        integer(c_int32_t) :: signal_count = 0
        type(c_ptr) :: signals = c_null_ptr
    end type
    type, bind(C) :: VkPresentInfoKHR
        integer(c_int) :: s_type = ST_PRESENT_INFO_KHR
        type(c_ptr) :: next = c_null_ptr
        integer(c_int32_t) :: wait_count = 0
        type(c_ptr) :: waits = c_null_ptr
        integer(c_int32_t) :: swapchain_count = 0
        type(c_ptr) :: swapchains = c_null_ptr, indices = c_null_ptr, results = c_null_ptr
    end type

    abstract interface
        integer(c_int) function fn_create_instance(info, alloc, instance) bind(C)
            import
            type(VkInstanceCreateInfo), intent(in) :: info
            type(c_ptr), value :: alloc
            type(c_ptr), intent(out) :: instance
        end function
        integer(c_int) function fn_create_xcb_surface(instance, info, alloc, surface) bind(C)
            import
            type(c_ptr), value :: instance, alloc
            type(VkXcbSurfaceCreateInfoKHR), intent(in) :: info
            integer(c_int64_t), intent(out) :: surface
        end function
        integer(c_int) function fn_enumerate(handle, count, items) bind(C)
            import
            type(c_ptr), value :: handle, items
            integer(c_int32_t), intent(inout) :: count
        end function
        subroutine fn_queue_families(pd, count, props) bind(C)
            import
            type(c_ptr), value :: pd, props
            integer(c_int32_t), intent(inout) :: count
        end subroutine
        integer(c_int) function fn_surface_support(pd, family, surface, supported) bind(C)
            import
            type(c_ptr), value :: pd
            integer(c_int32_t), value :: family
            integer(c_int64_t), value :: surface
            integer(c_int32_t), intent(out) :: supported
        end function
        integer(c_int) function fn_create_device(pd, info, alloc, device) bind(C)
            import
            type(c_ptr), value :: pd, alloc
            type(VkDeviceCreateInfo), intent(in) :: info
            type(c_ptr), intent(out) :: device
        end function
        subroutine fn_get_queue(device, family, index, queue) bind(C)
            import
            type(c_ptr), value :: device
            integer(c_int32_t), value :: family, index
            type(c_ptr), intent(out) :: queue
        end subroutine
        integer(c_int) function fn_surface_caps(pd, surface, caps) bind(C)
            import
            type(c_ptr), value :: pd
            integer(c_int64_t), value :: surface
            type(VkSurfaceCapabilitiesKHR), intent(out) :: caps
        end function
        integer(c_int) function fn_surface_list(pd, surface, count, items) bind(C)
            import
            type(c_ptr), value :: pd, items
            integer(c_int64_t), value :: surface
            integer(c_int32_t), intent(inout) :: count
        end function
        integer(c_int) function fn_create_swapchain(device, info, alloc, swapchain) bind(C)
            import
            type(c_ptr), value :: device, alloc
            type(VkSwapchainCreateInfoKHR), intent(in) :: info
            integer(c_int64_t), intent(out) :: swapchain
        end function
        integer(c_int) function fn_swapchain_images(device, swapchain, count, images) bind(C)
            import
            type(c_ptr), value :: device, images
            integer(c_int64_t), value :: swapchain
            integer(c_int32_t), intent(inout) :: count
        end function
        integer(c_int) function fn_create_image_view(device, info, alloc, view) bind(C)
            import
            type(c_ptr), value :: device, alloc
            type(VkImageViewCreateInfo), intent(in) :: info
            integer(c_int64_t), intent(out) :: view
        end function
        subroutine fn_destroy(device, handle, alloc) bind(C)
            import
            type(c_ptr), value :: device, alloc
            integer(c_int64_t), value :: handle
        end subroutine
        subroutine fn_destroy_dispatchable(handle, alloc) bind(C)
            import
            type(c_ptr), value :: handle, alloc
        end subroutine
        integer(c_int) function fn_create_shader_module(device, info, alloc, module) bind(C)
            import
            type(c_ptr), value :: device, alloc
            type(VkShaderModuleCreateInfo), intent(in) :: info
            integer(c_int64_t), intent(out) :: module
        end function
        integer(c_int) function fn_create_pipeline_layout(device, info, alloc, layout) bind(C)
            import
            type(c_ptr), value :: device, alloc
            type(VkPipelineLayoutCreateInfo), intent(in) :: info
            integer(c_int64_t), intent(out) :: layout
        end function
        integer(c_int) function fn_create_pipelines(device, cache, count, infos, alloc, &
                pipelines) bind(C)
            import
            type(c_ptr), value :: device, alloc
            integer(c_int64_t), value :: cache
            integer(c_int32_t), value :: count
            type(VkGraphicsPipelineCreateInfo), intent(in) :: infos
            integer(c_int64_t), intent(out) :: pipelines
        end function
        integer(c_int) function fn_create_command_pool(device, info, alloc, pool) bind(C)
            import
            type(c_ptr), value :: device, alloc
            type(VkCommandPoolCreateInfo), intent(in) :: info
            integer(c_int64_t), intent(out) :: pool
        end function
        integer(c_int) function fn_allocate_command_buffers(device, info, buffers) bind(C)
            import
            type(c_ptr), value :: device
            type(VkCommandBufferAllocateInfo), intent(in) :: info
            type(c_ptr), intent(out) :: buffers
        end function
        integer(c_int) function fn_create_semaphore(device, info, alloc, semaphore) bind(C)
            import
            type(c_ptr), value :: device, alloc
            type(VkSemaphoreCreateInfo), intent(in) :: info
            integer(c_int64_t), intent(out) :: semaphore
        end function
        integer(c_int) function fn_create_fence(device, info, alloc, fence) bind(C)
            import
            type(c_ptr), value :: device, alloc
            type(VkFenceCreateInfo), intent(in) :: info
            integer(c_int64_t), intent(out) :: fence
        end function
        integer(c_int) function fn_wait_fences(device, count, fences, all, timeout) bind(C)
            import
            type(c_ptr), value :: device
            integer(c_int32_t), value :: count, all
            integer(c_int64_t), intent(in) :: fences
            integer(c_int64_t), value :: timeout
        end function
        integer(c_int) function fn_reset_fences(device, count, fences) bind(C)
            import
            type(c_ptr), value :: device
            integer(c_int32_t), value :: count
            integer(c_int64_t), intent(in) :: fences
        end function
        integer(c_int) function fn_acquire_image(device, swapchain, timeout, semaphore, &
                fence, index) bind(C)
            import
            type(c_ptr), value :: device
            integer(c_int64_t), value :: swapchain, timeout, semaphore, fence
            integer(c_int32_t), intent(out) :: index
        end function
        integer(c_int) function fn_reset_command_buffer(buffer, flags) bind(C)
            import
            type(c_ptr), value :: buffer
            integer(c_int32_t), value :: flags
        end function
        integer(c_int) function fn_begin_command_buffer(buffer, info) bind(C)
            import
            type(c_ptr), value :: buffer
            type(VkCommandBufferBeginInfo), intent(in) :: info
        end function
        integer(c_int) function fn_end_command_buffer(buffer) bind(C)
            import
            type(c_ptr), value :: buffer
        end function
        subroutine fn_cmd_pipeline_barrier(buffer, src_stage, dst_stage, dependency, &
                n_memory, memory, n_buffer, buffers, n_image, images) bind(C)
            import
            type(c_ptr), value :: buffer, memory, buffers
            integer(c_int32_t), value :: src_stage, dst_stage, dependency, n_memory, &
                n_buffer, n_image
            type(VkImageMemoryBarrier), intent(in) :: images
        end subroutine
        subroutine fn_cmd_begin_rendering(buffer, info) bind(C)
            import
            type(c_ptr), value :: buffer
            type(VkRenderingInfo), intent(in) :: info
        end subroutine
        subroutine fn_cmd_end_rendering(buffer) bind(C)
            import
            type(c_ptr), value :: buffer
        end subroutine
        subroutine fn_cmd_bind_pipeline(buffer, bind_point, pipeline) bind(C)
            import
            type(c_ptr), value :: buffer
            integer(c_int), value :: bind_point
            integer(c_int64_t), value :: pipeline
        end subroutine
        subroutine fn_cmd_set_viewport(buffer, first, count, viewports) bind(C)
            import
            type(c_ptr), value :: buffer
            integer(c_int32_t), value :: first, count
            type(VkViewport), intent(in) :: viewports
        end subroutine
        subroutine fn_cmd_set_scissor(buffer, first, count, scissors) bind(C)
            import
            type(c_ptr), value :: buffer
            integer(c_int32_t), value :: first, count
            type(VkRect2D), intent(in) :: scissors
        end subroutine
        subroutine fn_cmd_push_constants(buffer, layout, stages, offset, size, values) bind(C)
            import
            type(c_ptr), value :: buffer, values
            integer(c_int64_t), value :: layout
            integer(c_int32_t), value :: stages, offset, size
        end subroutine
        subroutine fn_cmd_draw(buffer, vertices, instances, first_vertex, first_instance) &
                bind(C)
            import
            type(c_ptr), value :: buffer
            integer(c_int32_t), value :: vertices, instances, first_vertex, first_instance
        end subroutine
        integer(c_int) function fn_queue_submit(queue, count, submits, fence) bind(C)
            import
            type(c_ptr), value :: queue
            integer(c_int32_t), value :: count
            type(VkSubmitInfo), intent(in) :: submits
            integer(c_int64_t), value :: fence
        end function
        integer(c_int) function fn_queue_present(queue, info) bind(C)
            import
            type(c_ptr), value :: queue
            type(VkPresentInfoKHR), intent(in) :: info
        end function
        integer(c_int) function fn_device_wait_idle(device) bind(C)
            import
            type(c_ptr), value :: device
        end function
        subroutine fn_destroy_surface(instance, surface, alloc) bind(C)
            import
            type(c_ptr), value :: instance, alloc
            integer(c_int64_t), value :: surface
        end subroutine
        type(c_funptr) function fn_get_proc(instance, name) bind(C)
            import
            type(c_ptr), value :: instance
            character(kind=c_char), intent(in) :: name(*)
        end function
    end interface

    interface
        type(c_ptr) function dlopen(name, flags) bind(C)
            import :: c_ptr, c_char, c_int
            character(kind=c_char), intent(in) :: name(*)
            integer(c_int), value :: flags
        end function
        type(c_funptr) function dlsym(handle, name) bind(C)
            import :: c_ptr, c_funptr, c_char
            type(c_ptr), value :: handle
            character(kind=c_char), intent(in) :: name(*)
        end function
    end interface

    procedure(fn_get_proc), pointer :: vkGetInstanceProcAddr => null()

contains

    logical function vk_open_loader()
        !! Opens the system's Vulkan loader; false when there is none.
        type(c_ptr) :: lib
        lib = dlopen("libvulkan.so.1" // c_null_char, 2_c_int)
        vk_open_loader = c_associated(lib)
        if (.not. vk_open_loader) return
        call c_f_procpointer(dlsym(lib, "vkGetInstanceProcAddr" // c_null_char), &
            vkGetInstanceProcAddr)
    end function vk_open_loader

    type(c_funptr) function vk_proc(instance, name) result(f)
        type(c_ptr), intent(in) :: instance
        character(*), intent(in) :: name
        f = vkGetInstanceProcAddr(instance, name // c_null_char)
        if (.not. c_associated(f)) error stop "Vulkan function missing: " // name
    end function vk_proc

    subroutine vk_check(res, what)
        integer(c_int), intent(in) :: res
        character(*), intent(in) :: what
        character(16) :: code
        if (res == VK_SUCCESS) return
        write (code, '(i0)') res
        error stop what // " failed with VkResult " // trim(code)
    end subroutine vk_check

end module fortgfx_vulkan
