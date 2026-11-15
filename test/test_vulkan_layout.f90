program test_vulkan_layout
    !! Every bind(C) struct of the Vulkan binding has the size the C compiler
    !! gives the struct of the same name in vulkan_core.h (header 1.4.363, LP64:
    !! Linux and macOS on x86-64 and arm64). A missing or extra member, or a
    !! pointer bound as an integer, changes it; a member narrowed within
    !! alignment padding does not, which needs a check of member offsets.
    use iso_c_binding, only: c_size_t, c_sizeof
    use fortgfx_vulkan
    implicit none
    type(VkExtent2D) :: v0
    type(VkRect2D) :: v1
    type(VkViewport) :: v2
    type(VkSubresourceRange) :: v3
    type(VkApplicationInfo) :: v4
    type(VkInstanceCreateInfo) :: v5
    type(VkXcbSurfaceCreateInfoKHR) :: v6
    type(VkQueueFamilyProperties) :: v7
    type(VkDeviceQueueCreateInfo) :: v8
    type(VkDynamicRenderingFeatures) :: v9
    type(VkDeviceCreateInfo) :: v10
    type(VkSurfaceCapabilitiesKHR) :: v11
    type(VkSurfaceFormatKHR) :: v12
    type(VkSwapchainCreateInfoKHR) :: v13
    type(VkImageViewCreateInfo) :: v14
    type(VkShaderModuleCreateInfo) :: v15
    type(VkPipelineShaderStageCreateInfo) :: v16
    type(VkPipelineVertexInputStateCreateInfo) :: v17
    type(VkPipelineInputAssemblyStateCreateInfo) :: v18
    type(VkPipelineViewportStateCreateInfo) :: v19
    type(VkPipelineRasterizationStateCreateInfo) :: v20
    type(VkPipelineMultisampleStateCreateInfo) :: v21
    type(VkPipelineColorBlendAttachmentState) :: v22
    type(VkPipelineColorBlendStateCreateInfo) :: v23
    type(VkPipelineDynamicStateCreateInfo) :: v24
    type(VkPushConstantRange) :: v25
    type(VkPipelineLayoutCreateInfo) :: v26
    type(VkPipelineRenderingCreateInfo) :: v27
    type(VkGraphicsPipelineCreateInfo) :: v28
    type(VkCommandPoolCreateInfo) :: v29
    type(VkCommandBufferAllocateInfo) :: v30
    type(VkCommandBufferBeginInfo) :: v31
    type(VkSemaphoreCreateInfo) :: v32
    type(VkFenceCreateInfo) :: v33
    type(VkImageMemoryBarrier) :: v34
    type(VkRenderingAttachmentInfo) :: v35
    type(VkRenderingInfo) :: v36
    type(VkSubmitInfo) :: v37
    type(VkPresentInfoKHR) :: v38
    integer :: failures = 0

    call expect("VkExtent2D", c_sizeof(v0), 8)
    call expect("VkRect2D", c_sizeof(v1), 16)
    call expect("VkViewport", c_sizeof(v2), 24)
    call expect("VkSubresourceRange", c_sizeof(v3), 20)
    call expect("VkApplicationInfo", c_sizeof(v4), 48)
    call expect("VkInstanceCreateInfo", c_sizeof(v5), 64)
    call expect("VkXcbSurfaceCreateInfoKHR", c_sizeof(v6), 40)
    call expect("VkQueueFamilyProperties", c_sizeof(v7), 24)
    call expect("VkDeviceQueueCreateInfo", c_sizeof(v8), 40)
    call expect("VkDynamicRenderingFeatures", c_sizeof(v9), 24)
    call expect("VkDeviceCreateInfo", c_sizeof(v10), 72)
    call expect("VkSurfaceCapabilitiesKHR", c_sizeof(v11), 52)
    call expect("VkSurfaceFormatKHR", c_sizeof(v12), 8)
    call expect("VkSwapchainCreateInfoKHR", c_sizeof(v13), 104)
    call expect("VkImageViewCreateInfo", c_sizeof(v14), 80)
    call expect("VkShaderModuleCreateInfo", c_sizeof(v15), 40)
    call expect("VkPipelineShaderStageCreateInfo", c_sizeof(v16), 48)
    call expect("VkPipelineVertexInputStateCreateInfo", c_sizeof(v17), 48)
    call expect("VkPipelineInputAssemblyStateCreateInfo", c_sizeof(v18), 32)
    call expect("VkPipelineViewportStateCreateInfo", c_sizeof(v19), 48)
    call expect("VkPipelineRasterizationStateCreateInfo", c_sizeof(v20), 64)
    call expect("VkPipelineMultisampleStateCreateInfo", c_sizeof(v21), 48)
    call expect("VkPipelineColorBlendAttachmentState", c_sizeof(v22), 32)
    call expect("VkPipelineColorBlendStateCreateInfo", c_sizeof(v23), 56)
    call expect("VkPipelineDynamicStateCreateInfo", c_sizeof(v24), 32)
    call expect("VkPushConstantRange", c_sizeof(v25), 12)
    call expect("VkPipelineLayoutCreateInfo", c_sizeof(v26), 48)
    call expect("VkPipelineRenderingCreateInfo", c_sizeof(v27), 40)
    call expect("VkGraphicsPipelineCreateInfo", c_sizeof(v28), 144)
    call expect("VkCommandPoolCreateInfo", c_sizeof(v29), 24)
    call expect("VkCommandBufferAllocateInfo", c_sizeof(v30), 32)
    call expect("VkCommandBufferBeginInfo", c_sizeof(v31), 32)
    call expect("VkSemaphoreCreateInfo", c_sizeof(v32), 24)
    call expect("VkFenceCreateInfo", c_sizeof(v33), 24)
    call expect("VkImageMemoryBarrier", c_sizeof(v34), 72)
    call expect("VkRenderingAttachmentInfo", c_sizeof(v35), 72)
    call expect("VkRenderingInfo", c_sizeof(v36), 72)
    call expect("VkSubmitInfo", c_sizeof(v37), 72)
    call expect("VkPresentInfoKHR", c_sizeof(v38), 64)
    if (failures > 0) error stop 1
    write (*, '(a)') "Vulkan struct sizes match vulkan_core.h"

contains

    subroutine expect(name, got, want)
        character(*), intent(in) :: name
        integer(c_size_t), intent(in) :: got
        integer, intent(in) :: want
        if (got == int(want, c_size_t)) return
        failures = failures + 1
        write (*, '(a, i0, a, i0)') "FAIL: " // name // " has ", got, " bytes, C has ", want
    end subroutine expect

end program test_vulkan_layout
