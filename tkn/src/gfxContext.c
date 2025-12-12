#include "gfxCore.h"

static void getGfxAndPresentQueueFamilyIndices(TknGfxContext *pTknGfxContext, VkPhysicalDevice vkPhysicalDevice, uint32_t *pGfxQueueFamilyIndex, uint32_t *pPresentQueueFamilyIndex)
{
    VkSurfaceKHR vkSurface = pTknGfxContext->vkSurface;
    uint32_t queueFamilyPropertiesCount;
    vkGetPhysicalDeviceQueueFamilyProperties(vkPhysicalDevice, &queueFamilyPropertiesCount, NULL);
    VkQueueFamilyProperties *vkQueueFamilyPropertiesArray = tknMalloc(queueFamilyPropertiesCount * sizeof(VkQueueFamilyProperties));
    vkGetPhysicalDeviceQueueFamilyProperties(vkPhysicalDevice, &queueFamilyPropertiesCount, vkQueueFamilyPropertiesArray);
    *pGfxQueueFamilyIndex = UINT32_MAX;
    *pPresentQueueFamilyIndex = UINT32_MAX;
    for (int queueFamilyPropertiesIndex = 0; queueFamilyPropertiesIndex < queueFamilyPropertiesCount; queueFamilyPropertiesIndex++)
    {
        VkQueueFamilyProperties vkQueueFamilyProperties = vkQueueFamilyPropertiesArray[queueFamilyPropertiesIndex];
        if (vkQueueFamilyProperties.queueCount > 0 && vkQueueFamilyProperties.queueFlags & VK_QUEUE_GRAPHICS_BIT)
        {
            *pGfxQueueFamilyIndex = queueFamilyPropertiesIndex;
        }
        else
        {
            // continue;
        }
        VkBool32 pSupported = VK_FALSE;
        assertVkResult(vkGetPhysicalDeviceSurfaceSupportKHR(vkPhysicalDevice, queueFamilyPropertiesIndex, vkSurface, &pSupported));
        if (vkQueueFamilyProperties.queueCount > 0 && pSupported)
        {
            *pPresentQueueFamilyIndex = queueFamilyPropertiesIndex;
        }
        else
        {
            // continue;
        }

        if (*pGfxQueueFamilyIndex != UINT32_MAX && *pPresentQueueFamilyIndex != UINT32_MAX)
        {
            break;
        }
    }
    tknFree(vkQueueFamilyPropertiesArray);
}
static void pickPhysicalDevice(TknGfxContext *pTknGfxContext, VkSurfaceFormatKHR targetVkSurfaceFormat, VkPresentModeKHR targetVkPresentMode)
{
    uint32_t deviceCount = -1;
    assertVkResult(vkEnumeratePhysicalDevices(pTknGfxContext->vkInstance, &deviceCount, NULL));
    if (deviceCount <= 0)
    {
        printf("failed to find GPUs with Vulkan support!");
    }
    else
    {
        VkPhysicalDevice *devices = tknMalloc(deviceCount * sizeof(VkPhysicalDevice));
        assertVkResult(vkEnumeratePhysicalDevices(pTknGfxContext->vkInstance, &deviceCount, devices));
        uint32_t maxScore = 0;
        char *targetDeviceName = NULL;
        pTknGfxContext->vkPhysicalDevice = VK_NULL_HANDLE;
        VkSurfaceKHR vkSurface = pTknGfxContext->vkSurface;
        for (uint32_t deviceIndex = 0; deviceIndex < deviceCount; deviceIndex++)
        {
            uint32_t score = 0;
            VkPhysicalDevice vkPhysicalDevice = devices[deviceIndex];
            VkPhysicalDeviceProperties deviceProperties;
            vkGetPhysicalDeviceProperties(vkPhysicalDevice, &deviceProperties);
            char *requiredExtensionNames[] = {
                VK_KHR_SWAPCHAIN_EXTENSION_NAME,
            };
            uint32_t requiredExtensionCount = TKN_ARRAY_COUNT(requiredExtensionNames);
            uint32_t extensionCount = 0;
            assertVkResult(vkEnumerateDeviceExtensionProperties(vkPhysicalDevice, NULL, &extensionCount, NULL));
            VkExtensionProperties *extensionProperties = tknMalloc(extensionCount * sizeof(VkExtensionProperties));
            assertVkResult(vkEnumerateDeviceExtensionProperties(vkPhysicalDevice, NULL, &extensionCount, extensionProperties));
            uint32_t requiredExtensionIndex;
            for (requiredExtensionIndex = 0; requiredExtensionIndex < requiredExtensionCount; requiredExtensionIndex++)
            {
                char *requiredExtensionName = requiredExtensionNames[requiredExtensionIndex];
                uint32_t extensionIndex;
                for (extensionIndex = 0; extensionIndex < extensionCount; extensionIndex++)
                {
                    char *supportedExtensionName = extensionProperties[extensionIndex].extensionName;
                    if (0 == strcmp(supportedExtensionName, requiredExtensionName))
                    {
                        break;
                    }
                    else
                    {
                        // continue;
                    }
                }
                if (extensionIndex < extensionCount)
                {
                    // found one
                    continue;
                }
                else
                {
                    // not found
                    break;
                }
            }
            tknFree(extensionProperties);
            if (requiredExtensionIndex < requiredExtensionCount)
            {
                // not found all required extensions
                continue;
            }
            else
            {
                // found all
            }

            uint32_t gfxQueueFamilyIndex;
            uint32_t presentQueueFamilyIndex;
            getGfxAndPresentQueueFamilyIndices(pTknGfxContext, vkPhysicalDevice, &gfxQueueFamilyIndex, &presentQueueFamilyIndex);
            if (UINT32_MAX == gfxQueueFamilyIndex || UINT32_MAX == presentQueueFamilyIndex)
            {
                // No gfx or present queue family index
                continue;
            }

            uint32_t surfaceFormatCount;
            assertVkResult(vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &surfaceFormatCount, NULL));
            VkSurfaceFormatKHR *supportedSurfaceFormats = tknMalloc(surfaceFormatCount * sizeof(VkSurfaceFormatKHR));
            assertVkResult(vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &surfaceFormatCount, supportedSurfaceFormats));
            uint32_t supportedSurfaceFormatIndex;
            for (supportedSurfaceFormatIndex = 0; supportedSurfaceFormatIndex < surfaceFormatCount; supportedSurfaceFormatIndex++)
            {
                VkSurfaceFormatKHR vkSurfaceFormat = supportedSurfaceFormats[supportedSurfaceFormatIndex];
                if (vkSurfaceFormat.colorSpace == targetVkSurfaceFormat.colorSpace &&
                    vkSurfaceFormat.format == targetVkSurfaceFormat.format)
                {
                    break;
                }
                else
                {
                    // continue
                }
            }
            tknFree(supportedSurfaceFormats);
            if (supportedSurfaceFormatIndex < surfaceFormatCount)
            {
                // found one
            }
            else
            {
                // not found
                continue;
            }

            uint32_t presentModeCount;
            assertVkResult(vkGetPhysicalDeviceSurfacePresentModesKHR(vkPhysicalDevice, vkSurface, &presentModeCount, NULL));
            VkPresentModeKHR *supportedPresentModes = tknMalloc(presentModeCount * sizeof(VkPresentModeKHR));
            assertVkResult(vkGetPhysicalDeviceSurfacePresentModesKHR(vkPhysicalDevice, vkSurface, &presentModeCount, supportedPresentModes));
            uint32_t supportedPresentModeIndex;
            for (supportedPresentModeIndex = 0; supportedPresentModeIndex < presentModeCount; supportedPresentModeIndex++)
            {
                VkPresentModeKHR supportedPresentMode = supportedPresentModes[supportedPresentModeIndex];
                if (supportedPresentMode == targetVkPresentMode)
                {
                    // found one
                    break;
                }
                else
                {
                    // continue
                }
            }
            tknFree(supportedPresentModes);
            if (supportedPresentModeIndex < presentModeCount)
            {
                // found one
            }
            else
            {
                // not found
                continue;
            }

            VkFormatProperties vkFormatProperties;
            vkGetPhysicalDeviceFormatProperties(vkPhysicalDevice, VK_FORMAT_ASTC_4x4_UNORM_BLOCK, &vkFormatProperties);
            if (!(vkFormatProperties.optimalTilingFeatures & VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT))
            {
                // ASTC format not supported
                continue;
            }

            if (deviceProperties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
            {
                score += 1000;
            }
            else if (deviceProperties.deviceType == VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU)
            {
                score += 500;
            }
            else if (deviceProperties.deviceType == VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU)
            {
                score += 300;
            }
            else if (deviceProperties.deviceType == VK_PHYSICAL_DEVICE_TYPE_CPU)
            {
                score += 100;
            }

            if (score >= maxScore)
            {
                maxScore = score;
                targetDeviceName = deviceProperties.deviceName;
                pTknGfxContext->vkPhysicalDevice = vkPhysicalDevice;
                pTknGfxContext->gfxQueueFamilyIndex = gfxQueueFamilyIndex;
                pTknGfxContext->presentQueueFamilyIndex = presentQueueFamilyIndex;
                pTknGfxContext->vkPhysicalDeviceProperties = deviceProperties;
                pTknGfxContext->surfaceFormat = targetVkSurfaceFormat;
                pTknGfxContext->presentMode = targetVkPresentMode;
            }
            else
            {
                // continue
            }
        }
        tknFree(devices);

        if (NULL != pTknGfxContext->vkPhysicalDevice)
        {
            printf("Selected target physical device named %s\n", targetDeviceName);
        }
        else
        {
            tknError("failed to find GPUs with Vulkan support!");
        }
    }
}
static void populateLogicalDevice(TknGfxContext *pTknGfxContext)
{
    VkPhysicalDevice vkPhysicalDevice = pTknGfxContext->vkPhysicalDevice;
    uint32_t gfxQueueFamilyIndex = pTknGfxContext->gfxQueueFamilyIndex;
    uint32_t presentQueueFamilyIndex = pTknGfxContext->presentQueueFamilyIndex;
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo *queueCreateInfos;
    uint32_t queueCount;
    if (gfxQueueFamilyIndex == presentQueueFamilyIndex)
    {
        queueCount = 1;
        queueCreateInfos = tknMalloc(sizeof(VkDeviceQueueCreateInfo) * queueCount);
        VkDeviceQueueCreateInfo gfxCreateInfo =
            {
                .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .pNext = NULL,
                .flags = 0,
                .queueFamilyIndex = gfxQueueFamilyIndex,
                .queueCount = 1,
                .pQueuePriorities = &queuePriority,
            };
        queueCreateInfos[0] = gfxCreateInfo;
    }
    else
    {
        queueCount = 2;
        queueCreateInfos = tknMalloc(sizeof(VkDeviceQueueCreateInfo) * queueCount);
        VkDeviceQueueCreateInfo gfxCreateInfo =
            {
                .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .pNext = NULL,
                .flags = 0,
                .queueFamilyIndex = gfxQueueFamilyIndex,
                .queueCount = 1,
                .pQueuePriorities = &queuePriority,
            };
        VkDeviceQueueCreateInfo presentCreateInfo = {
            .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = NULL,
            .flags = 0,
            .queueFamilyIndex = presentQueueFamilyIndex,
            .queueCount = 1,
            .pQueuePriorities = &queuePriority,
        };
        queueCreateInfos[0] = gfxCreateInfo;
        queueCreateInfos[1] = presentCreateInfo;
    }

    VkPhysicalDeviceFeatures deviceFeatures =
        {
            .fillModeNonSolid = VK_TRUE,
            .sampleRateShading = VK_TRUE,
        };
    char **enabledLayerNames = NULL;
    uint32_t enabledLayerCount = 0;

    char *extensionNames[] = {
        VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        "VK_KHR_portability_subset",
    };
    uint32_t extensionCount = TKN_ARRAY_COUNT(extensionNames);
    VkDeviceCreateInfo vkDeviceCreateInfo =
        {
            .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = NULL,
            .flags = 0,
            .queueCreateInfoCount = queueCount,
            .pQueueCreateInfos = queueCreateInfos,
            .enabledLayerCount = enabledLayerCount,
            .ppEnabledLayerNames = (const char *const *)enabledLayerNames,
            .enabledExtensionCount = extensionCount,
            .ppEnabledExtensionNames = (const char *const *)extensionNames,
            .pEnabledFeatures = &deviceFeatures,
        };
    assertVkResult(vkCreateDevice(vkPhysicalDevice, &vkDeviceCreateInfo, NULL, &pTknGfxContext->vkDevice));
    vkGetDeviceQueue(pTknGfxContext->vkDevice, gfxQueueFamilyIndex, 0, &pTknGfxContext->vkGfxQueue);
    vkGetDeviceQueue(pTknGfxContext->vkDevice, presentQueueFamilyIndex, 0, &pTknGfxContext->vkPresentQueue);
    tknFree(queueCreateInfos);
}
static void cleanupLogicalDevice(TknGfxContext *pTknGfxContext)
{
    vkDestroyDevice(pTknGfxContext->vkDevice, NULL);
}
static void createSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext, VkExtent2D targetSwapchainExtent, uint32_t targetSwapchainImageCount)
{
    TknAttachment *pSwapchainAttachment = tknMalloc(sizeof(TknAttachment));

    VkPhysicalDevice vkPhysicalDevice = pTknGfxContext->vkPhysicalDevice;
    VkSurfaceKHR vkSurface = pTknGfxContext->vkSurface;
    VkDevice vkDevice = pTknGfxContext->vkDevice;

    assertVkResult(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vkPhysicalDevice, vkSurface, &pTknGfxContext->vkSurfaceCapabilities));

    uint32_t swapchainImageCount = TKN_CLAMP(targetSwapchainImageCount, pTknGfxContext->vkSurfaceCapabilities.minImageCount, pTknGfxContext->vkSurfaceCapabilities.maxImageCount);

    VkExtent2D swapchainExtent;
    swapchainExtent.width = TKN_CLAMP(targetSwapchainExtent.width, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.width, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.width);
    swapchainExtent.height = TKN_CLAMP(targetSwapchainExtent.height, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.height, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.height);

    VkSharingMode imageSharingMode = pTknGfxContext->gfxQueueFamilyIndex != pTknGfxContext->presentQueueFamilyIndex ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE;
    uint32_t queueFamilyIndexCount = pTknGfxContext->gfxQueueFamilyIndex != pTknGfxContext->presentQueueFamilyIndex ? 2 : 0;
    uint32_t pQueueFamilyIndices[] = {pTknGfxContext->gfxQueueFamilyIndex, pTknGfxContext->presentQueueFamilyIndex};

    VkSwapchainCreateInfoKHR swapchainCreateInfo =
        {
            .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .pNext = NULL,
            .flags = 0,
            .surface = vkSurface,
            .minImageCount = swapchainImageCount,
            .imageFormat = pTknGfxContext->surfaceFormat.format,
            .imageColorSpace = pTknGfxContext->surfaceFormat.colorSpace,
            .imageExtent = swapchainExtent,
            .imageArrayLayers = 1,
            .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = imageSharingMode,
            .queueFamilyIndexCount = queueFamilyIndexCount,
            .pQueueFamilyIndices = pQueueFamilyIndices,
            .preTransform = pTknGfxContext->vkSurfaceCapabilities.currentTransform,
            .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = pTknGfxContext->presentMode,
            .clipped = VK_TRUE,
            .oldSwapchain = VK_NULL_HANDLE,
        };
    VkSwapchainKHR vkSwapchain;
    assertVkResult(vkCreateSwapchainKHR(vkDevice, &swapchainCreateInfo, NULL, &vkSwapchain));

    VkImage *swapchainImages = tknMalloc(swapchainImageCount * sizeof(VkImage));
    assertVkResult(vkGetSwapchainImagesKHR(vkDevice, vkSwapchain, &swapchainImageCount, swapchainImages));
    VkImageView *swapchainImageViews = tknMalloc(swapchainImageCount * sizeof(VkImageView));
    for (uint32_t i = 0; i < swapchainImageCount; i++)
    {
        VkComponentMapping components = {
            .r = VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = VK_COMPONENT_SWIZZLE_IDENTITY,
        };
        VkImageSubresourceRange subresourceRange = {
            .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
            .levelCount = 1,
            .baseMipLevel = 0,
            .layerCount = 1,
            .baseArrayLayer = 0,
        };
        VkImageViewCreateInfo imageViewCreateInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = NULL,
            .flags = 0,
            .image = swapchainImages[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D,
            .format = pTknGfxContext->surfaceFormat.format,
            .components = components,
            .subresourceRange = subresourceRange,
        };
        assertVkResult(vkCreateImageView(vkDevice, &imageViewCreateInfo, NULL, &swapchainImageViews[i]));
    }
    *pSwapchainAttachment = (TknAttachment){
        .attachmentType = ATTACHMENT_TYPE_SWAPCHAIN,
        .attachmentUnion.swapchainAttachment = {
            .swapchainExtent = swapchainExtent,
            .vkSwapchain = vkSwapchain,
            .swapchainImageCount = swapchainImageCount,
            .swapchainImages = swapchainImages,
            .swapchainImageViews = swapchainImageViews,
        },
        .vkFormat = pTknGfxContext->surfaceFormat.format,
        .renderPassPtrHashSet = tknCreateHashSet(sizeof(TknRenderPass *)),
    };
    pTknGfxContext->pSwapchainAttachment = pSwapchainAttachment;
};
static void destroySwapchainAttachmentPtr(TknGfxContext *pTknGfxContext)
{
    TknAttachment *pSwapchainAttachment = pTknGfxContext->pSwapchainAttachment;
    tknAssert(0 == pSwapchainAttachment->renderPassPtrHashSet.count, "TknRenderPass hash set should be empty before destroying SwapchainAttachment.");

    VkDevice vkDevice = pTknGfxContext->vkDevice;
    SwapchainAttachment swapchainAttachment = pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    for (uint32_t i = 0; i < swapchainAttachment.swapchainImageCount; i++)
    {
        vkDestroyImageView(vkDevice, swapchainAttachment.swapchainImageViews[i], NULL);
    }
    tknFree(swapchainAttachment.swapchainImageViews);
    tknFree(swapchainAttachment.swapchainImages);
    vkDestroySwapchainKHR(vkDevice, swapchainAttachment.vkSwapchain, NULL);

    tknDestroyHashSet(pSwapchainAttachment->renderPassPtrHashSet);
    tknFree(pSwapchainAttachment);
    pTknGfxContext->pSwapchainAttachment = NULL;
}
static void updateSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext, VkExtent2D swapchainExtent)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    assertVkResult(vkDeviceWaitIdle(vkDevice));
    TknAttachment *pTknAttachment = pTknGfxContext->pSwapchainAttachment;
    SwapchainAttachment *pSwapchainAttachment = &pTknAttachment->attachmentUnion.swapchainAttachment;
    for (uint32_t i = 0; i < pSwapchainAttachment->swapchainImageCount; i++)
    {
        vkDestroyImageView(vkDevice, pSwapchainAttachment->swapchainImageViews[i], NULL);
    }
    vkDestroySwapchainKHR(vkDevice, pSwapchainAttachment->vkSwapchain, NULL);

    swapchainExtent.width = TKN_CLAMP(swapchainExtent.width, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.width, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.width);
    swapchainExtent.height = TKN_CLAMP(swapchainExtent.height, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.height, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.height);
    pSwapchainAttachment->swapchainExtent = swapchainExtent;

    VkSharingMode imageSharingMode = pTknGfxContext->gfxQueueFamilyIndex != pTknGfxContext->presentQueueFamilyIndex ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE;
    uint32_t queueFamilyIndexCount = pTknGfxContext->gfxQueueFamilyIndex != pTknGfxContext->presentQueueFamilyIndex ? 2 : 0;
    uint32_t pQueueFamilyIndices[] = {pTknGfxContext->gfxQueueFamilyIndex, pTknGfxContext->presentQueueFamilyIndex};
    VkSwapchainCreateInfoKHR swapchainCreateInfo =
        {
            .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .pNext = NULL,
            .flags = 0,
            .surface = pTknGfxContext->vkSurface,
            .minImageCount = pSwapchainAttachment->swapchainImageCount,
            .imageFormat = pTknGfxContext->surfaceFormat.format,
            .imageColorSpace = pTknGfxContext->surfaceFormat.colorSpace,
            .imageExtent = swapchainExtent,
            .imageArrayLayers = 1,
            .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = imageSharingMode,
            .queueFamilyIndexCount = queueFamilyIndexCount,
            .pQueueFamilyIndices = pQueueFamilyIndices,
            .preTransform = pTknGfxContext->vkSurfaceCapabilities.currentTransform,
            .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = pTknGfxContext->presentMode,
            .clipped = VK_TRUE,
            .oldSwapchain = VK_NULL_HANDLE,
        };
    assertVkResult(vkCreateSwapchainKHR(vkDevice, &swapchainCreateInfo, NULL, &pSwapchainAttachment->vkSwapchain));
    assertVkResult(vkGetSwapchainImagesKHR(vkDevice, pSwapchainAttachment->vkSwapchain, &pSwapchainAttachment->swapchainImageCount, pSwapchainAttachment->swapchainImages));
    for (uint32_t i = 0; i < pSwapchainAttachment->swapchainImageCount; i++)
    {
        VkComponentMapping components = {
            .r = VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = VK_COMPONENT_SWIZZLE_IDENTITY,
        };
        VkImageSubresourceRange subresourceRange = {
            .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
            .levelCount = 1,
            .baseMipLevel = 0,
            .layerCount = 1,
            .baseArrayLayer = 0,
        };
        VkImageViewCreateInfo imageViewCreateInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = NULL,
            .flags = 0,
            .image = pSwapchainAttachment->swapchainImages[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D,
            .format = pTknGfxContext->surfaceFormat.format,
            .components = components,
            .subresourceRange = subresourceRange,
        };
        assertVkResult(vkCreateImageView(vkDevice, &imageViewCreateInfo, NULL, &pSwapchainAttachment->swapchainImageViews[i]));
    }
}
static void populateSignals(TknGfxContext *pTknGfxContext)
{
    VkSemaphoreCreateInfo semaphoreCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
    };
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    VkFenceCreateInfo fenceCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .pNext = NULL,
        .flags = VK_FENCE_CREATE_SIGNALED_BIT,
    };
    assertVkResult(vkCreateSemaphore(vkDevice, &semaphoreCreateInfo, NULL, &pTknGfxContext->imageAvailableSemaphore));
    assertVkResult(vkCreateSemaphore(vkDevice, &semaphoreCreateInfo, NULL, &pTknGfxContext->renderFinishedSemaphore));
    assertVkResult(vkCreateFence(vkDevice, &fenceCreateInfo, NULL, &pTknGfxContext->renderFinishedFence));
}
static void cleanupSignals(TknGfxContext *pTknGfxContext)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroySemaphore(vkDevice, pTknGfxContext->imageAvailableSemaphore, NULL);
    vkDestroySemaphore(vkDevice, pTknGfxContext->renderFinishedSemaphore, NULL);
    vkDestroyFence(vkDevice, pTknGfxContext->renderFinishedFence, NULL);
}
static void populateCommandPools(TknGfxContext *pTknGfxContext)
{
    VkCommandPoolCreateInfo vkCommandPoolCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = NULL,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = pTknGfxContext->gfxQueueFamilyIndex,
    };
    assertVkResult(vkCreateCommandPool(pTknGfxContext->vkDevice, &vkCommandPoolCreateInfo, NULL, &pTknGfxContext->gfxVkCommandPool));
}
static void cleanupCommandPools(TknGfxContext *pTknGfxContext)
{
    vkDestroyCommandPool(pTknGfxContext->vkDevice, pTknGfxContext->gfxVkCommandPool, NULL);
}
static void populateVkCommandBuffers(TknGfxContext *pTknGfxContext)
{
    SwapchainAttachment *pSwapchainAttachment = &pTknGfxContext->pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    pTknGfxContext->gfxVkCommandBuffers = tknMalloc(sizeof(VkCommandBuffer) * pSwapchainAttachment->swapchainImageCount);
    VkCommandBufferAllocateInfo vkCommandBufferAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = NULL,
        .commandPool = pTknGfxContext->gfxVkCommandPool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = pSwapchainAttachment->swapchainImageCount,
    };
    assertVkResult(vkAllocateCommandBuffers(pTknGfxContext->vkDevice, &vkCommandBufferAllocateInfo, pTknGfxContext->gfxVkCommandBuffers));
}
static void cleanupVkCommandBuffers(TknGfxContext *pTknGfxContext)
{
    SwapchainAttachment *pSwapchainAttachment = &pTknGfxContext->pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    vkFreeCommandBuffers(pTknGfxContext->vkDevice, pTknGfxContext->gfxVkCommandPool, pSwapchainAttachment->swapchainImageCount, pTknGfxContext->gfxVkCommandBuffers);
    tknFree(pTknGfxContext->gfxVkCommandBuffers);
}
static void recordCommandBuffer(TknGfxContext *pTknGfxContext, uint32_t swapchainIndex)
{
    VkCommandBuffer vkCommandBuffer = pTknGfxContext->gfxVkCommandBuffers[swapchainIndex];
    VkCommandBufferBeginInfo vkCommandBufferBeginInfo =
        {
            .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = NULL,
            .flags = 0,
            .pInheritanceInfo = NULL,
        };
    assertVkResult(vkBeginCommandBuffer(vkCommandBuffer, &vkCommandBufferBeginInfo));
    TknMaterial *pGlobalMaterial = getGlobalMaterialPtr(pTknGfxContext);
    for (uint32_t renderPassIndex = 0; renderPassIndex < pTknGfxContext->renderPassPtrDynamicArray.count; renderPassIndex++)
    {
        TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->renderPassPtrDynamicArray, renderPassIndex);
        VkRenderPassBeginInfo renderPassBeginInfo = {
            .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .pNext = NULL,
            .renderPass = pTknRenderPass->vkRenderPass,
            .framebuffer = pTknRenderPass->vkFramebuffers[swapchainIndex],
            .renderArea = pTknRenderPass->renderArea,
            .clearValueCount = pTknRenderPass->attachmentCount,
            .pClearValues = pTknRenderPass->vkClearValues,
        };
        vkCmdBeginRenderPass(vkCommandBuffer, &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
        VkViewport vkViewport = {
            .x = 0.0f,
            .y = 0.0f,
            .width = pTknRenderPass->renderArea.extent.width,
            .height = pTknRenderPass->renderArea.extent.height,
            .minDepth = 0.0f,
            .maxDepth = 1.0f,
        };
        vkCmdSetViewport(vkCommandBuffer, 0, 1, &vkViewport);

        VkRect2D scissor = {
            .offset = {0, 0},
            .extent = pTknRenderPass->renderArea.extent,
        };
        vkCmdSetScissor(vkCommandBuffer, 0, 1, &scissor);
        for (uint32_t subpassIndex = 0; subpassIndex < pTknRenderPass->subpassCount; subpassIndex++)
        {
            if (subpassIndex > 0)
            {
                vkCmdNextSubpass(vkCommandBuffer, VK_SUBPASS_CONTENTS_INLINE);
            }
            struct Subpass *pSubpass = &pTknRenderPass->subpasses[subpassIndex];
            TknMaterial *pSubpassMaterial = getSubpassMaterialPtr(pTknGfxContext, pTknRenderPass, subpassIndex);
            TknPipeline *pCurrentPipeline = NULL;
            // Iterate all drawcalls in subpass order, switching pipelines as needed
            for (uint32_t drawCallIndex = 0; drawCallIndex < pSubpass->drawCallPtrDynamicArray.count; drawCallIndex++)
            {
                TknDrawCall *pTknDrawCall = *(TknDrawCall **)tknGetFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, drawCallIndex);
                TknPipeline *pTknPipeline = pTknDrawCall->pTknPipeline;
                // Switch pipeline if different from previous drawcall
                if (pTknPipeline != pCurrentPipeline)
                {
                    vkCmdBindPipeline(vkCommandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pTknPipeline->vkPipeline);
                    pCurrentPipeline = pTknPipeline;
                }
                VkDescriptorSet *vkDescriptorSets = tknMalloc(sizeof(VkDescriptorSet) * TKN_MAX_DESCRIPTOR_SET);
                vkDescriptorSets[TKN_GLOBAL_DESCRIPTOR_SET] = pGlobalMaterial->vkDescriptorSet;
                vkDescriptorSets[TKN_SUBPASS_DESCRIPTOR_SET] = pSubpassMaterial->vkDescriptorSet;
                if (pTknDrawCall->pTknMaterial != NULL)
                {
                    vkDescriptorSets[TKN_PIPELINE_DESCRIPTOR_SET] = pTknDrawCall->pTknMaterial->vkDescriptorSet;
                    vkCmdBindDescriptorSets(vkCommandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pTknPipeline->vkPipelineLayout, 0, TKN_MAX_DESCRIPTOR_SET, vkDescriptorSets, 0, NULL);
                }
                else
                {
                    vkCmdBindDescriptorSets(vkCommandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pTknPipeline->vkPipelineLayout, 0, TKN_MAX_DESCRIPTOR_SET - 1, vkDescriptorSets, 0, NULL);
                }
                tknFree(vkDescriptorSets);
                TknMesh *pTknMesh = pTknDrawCall->pTknMesh;
                if (pTknMesh != NULL)
                {
                    if (pTknDrawCall->pTknInstance != NULL && pTknDrawCall->pTknInstance->instanceCount > 0)
                    {
                        tknAssert(pTknDrawCall->pTknMesh->vertexCount > 0, "TknMesh has no vertices");
                        VkBuffer vertexBuffers[] = {pTknMesh->vertexVkBuffer, pTknDrawCall->pTknInstance->instanceVkBuffer};
                        VkDeviceSize offsets[] = {0, 0};
                        vkCmdBindVertexBuffers(vkCommandBuffer, 0, 2, vertexBuffers, offsets);
                        if (pTknMesh->indexCount > 0)
                        {
                            vkCmdBindIndexBuffer(vkCommandBuffer, pTknMesh->indexVkBuffer, 0, pTknMesh->vkIndexType);
                            vkCmdDrawIndexed(vkCommandBuffer, pTknMesh->indexCount, pTknDrawCall->pTknInstance->instanceCount, 0, 0, 0);
                        }
                        else
                        {
                            vkCmdDraw(vkCommandBuffer, pTknMesh->vertexCount, pTknDrawCall->pTknInstance->instanceCount, 0, 0);
                        }
                    }
                    else
                    {
                        // Simple case: only bind vertex buffer (no instancing)
                        VkBuffer vertexBuffers[] = {pTknMesh->vertexVkBuffer};
                        VkDeviceSize offsets[] = {0};
                        vkCmdBindVertexBuffers(vkCommandBuffer, 0, 1, vertexBuffers, offsets);

                        if (pTknMesh->indexCount > 0)
                        {
                            vkCmdBindIndexBuffer(vkCommandBuffer, pTknMesh->indexVkBuffer, 0, pTknMesh->vkIndexType);
                            vkCmdDrawIndexed(vkCommandBuffer, pTknMesh->indexCount, 1, 0, 0, 0);
                        }
                        else
                        {
                            vkCmdDraw(vkCommandBuffer, pTknMesh->vertexCount, 1, 0, 0);
                        }
                    }
                }
                else
                {
                    vkCmdDraw(vkCommandBuffer, 3, 1, 0, 0);
                }
            }
        }
        vkCmdEndRenderPass(vkCommandBuffer);
    }

    assertVkResult(vkEndCommandBuffer(vkCommandBuffer));
}
static void submitCommandBuffer(TknGfxContext *pTknGfxContext, uint32_t swapchainIndex)
{
    // Submit workflow...
    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = NULL,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = (VkSemaphore[]){pTknGfxContext->imageAvailableSemaphore},
        .pWaitDstStageMask = (VkPipelineStageFlags[]){VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
        .commandBufferCount = 1,
        .pCommandBuffers = &pTknGfxContext->gfxVkCommandBuffers[swapchainIndex],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = (VkSemaphore[]){pTknGfxContext->renderFinishedSemaphore},
    };

    assertVkResult(vkQueueSubmit(pTknGfxContext->vkGfxQueue, 1, &submitInfo, pTknGfxContext->renderFinishedFence));
}
static void present(TknGfxContext *pTknGfxContext, uint32_t swapchainIndex)
{
    SwapchainAttachment *pSwapchainAttachment = &pTknGfxContext->pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    VkPresentInfoKHR presentInfo = {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pNext = NULL,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = (VkSemaphore[]){pTknGfxContext->renderFinishedSemaphore},
        .swapchainCount = 1,
        .pSwapchains = (VkSwapchainKHR[]){pSwapchainAttachment->vkSwapchain},
        .pImageIndices = &swapchainIndex,
        .pResults = NULL,
    };
    VkResult result = vkQueuePresentKHR(pTknGfxContext->vkPresentQueue, &presentInfo);
    if (VK_ERROR_OUT_OF_DATE_KHR == result || VK_SUBOPTIMAL_KHR == result)
    {
        printf("Recreate swapchain because of the result: %d when presenting.\n", result);
        updateSwapchainAttachmentPtr(pTknGfxContext, pSwapchainAttachment->swapchainExtent);
        for (uint32_t renderPassIndex = 0; renderPassIndex < pTknGfxContext->renderPassPtrDynamicArray.count; renderPassIndex++)
        {
            TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->renderPassPtrDynamicArray, renderPassIndex);
            TknAttachment *pSwapchainAttachment = getSwapchainAttachmentPtr(pTknGfxContext);
            if (tknContainsInHashSet(&pSwapchainAttachment->renderPassPtrHashSet, &pTknRenderPass))
            {
                repopulateFramebuffers(pTknGfxContext, pTknRenderPass);
            }
            else
            {
                // Don't need to recreate framebuffers
            }
        }
    }
    else
    {
        assertVkResult(result);
    }
}
static void setupRenderPipelineAndResources(TknGfxContext *pTknGfxContext, uint32_t spvPathCount, const char **spvPaths)
{
    // Create empty resources for empty bindings
    uint32_t emptyData = 0;
    pTknGfxContext->pEmptyUniformBuffer = createUniformBufferPtr(pTknGfxContext, &emptyData, sizeof(emptyData));

    // Create empty sampler with default settings
    VkSamplerCreateInfo samplerCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = VK_FILTER_LINEAR,
        .minFilter = VK_FILTER_LINEAR,
        .addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeV = VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeW = VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .anisotropyEnable = VK_FALSE,
        .maxAnisotropy = 1.0f,
        .borderColor = VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = VK_FALSE,
        .compareEnable = VK_FALSE,
        .compareOp = VK_COMPARE_OP_ALWAYS,
        .mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR,
        .mipLodBias = 0.0f,
        .minLod = 0.0f,
        .maxLod = 0.0f,
    };

    pTknGfxContext->pEmptySampler = tknMalloc(sizeof(TknSampler));
    pTknGfxContext->pEmptySampler->bindingPtrHashSet = tknCreateHashSet(sizeof(Binding *));
    assertVkResult(vkCreateSampler(pTknGfxContext->vkDevice, &samplerCreateInfo, NULL, &pTknGfxContext->pEmptySampler->vkSampler));

    // Create empty image for input attachments, sampling, and storage
    VkExtent3D emptyImageExtent = {.width = 1, .height = 1, .depth = 1};
    pTknGfxContext->pEmptyImage = createImagePtr(
        pTknGfxContext,
        emptyImageExtent,
        VK_FORMAT_R8G8B8A8_UNORM,
        VK_IMAGE_TILING_OPTIMAL,
        VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_STORAGE_BIT,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        VK_IMAGE_ASPECT_COLOR_BIT,
        NULL,
        0);

    pTknGfxContext->dynamicAttachmentPtrHashSet = tknCreateHashSet(sizeof(TknAttachment *));
    pTknGfxContext->fixedAttachmentPtrHashSet = tknCreateHashSet(sizeof(TknAttachment *));
    pTknGfxContext->renderPassPtrDynamicArray = tknCreateDynamicArray(sizeof(TknRenderPass *), TKN_DEFAULT_COLLECTION_SIZE);
    SpvReflectShaderModule *spvReflectShaderModules = tknMalloc(sizeof(SpvReflectShaderModule) * spvPathCount);
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        spvReflectShaderModules[spvPathIndex] = createSpvReflectShaderModule(spvPaths[spvPathIndex]);
    }
    pTknGfxContext->pGlobalDescriptorSet = createDescriptorSetPtr(pTknGfxContext, spvPathCount, spvReflectShaderModules, TKN_GLOBAL_DESCRIPTOR_SET);
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        destroySpvReflectShaderModule(&spvReflectShaderModules[spvPathIndex]);
    }
    tknFree(spvReflectShaderModules);
    createMaterialPtr(pTknGfxContext, pTknGfxContext->pGlobalDescriptorSet);

    pTknGfxContext->vertexInputLayoutPtrHashSet = tknCreateHashSet(sizeof(TknVertexInputLayout *));
}
static void teardownRenderPipelineAndResources(TknGfxContext *pTknGfxContext)
{
    for (uint32_t i = 0; i < pTknGfxContext->renderPassPtrDynamicArray.count; i++)
    {
        TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->renderPassPtrDynamicArray, i);
        destroyRenderPassPtr(pTknGfxContext, pTknRenderPass);
    }
    tknClearDynamicArray(&pTknGfxContext->renderPassPtrDynamicArray);
    tknAssert(pTknGfxContext->renderPassPtrDynamicArray.count == 0, "Render pass dynamic array should be empty before destroying TknGfxContext.");
    tknDestroyDynamicArray(pTknGfxContext->renderPassPtrDynamicArray);

    destroyDescriptorSetPtr(pTknGfxContext, pTknGfxContext->pGlobalDescriptorSet);
    tknAssert(pTknGfxContext->vertexInputLayoutPtrHashSet.count == 0, "Vertex input layout hash set should be empty before destroying TknGfxContext.");
    tknDestroyHashSet(pTknGfxContext->vertexInputLayoutPtrHashSet);

    while (pTknGfxContext->dynamicAttachmentPtrHashSet.count > 0)
    {
        TknAttachment *pDynamicAttachment = NULL;
        for (uint32_t nodeIndex = 0; nodeIndex < pTknGfxContext->dynamicAttachmentPtrHashSet.capacity; nodeIndex++)
        {
            TknListNode *pNode = pTknGfxContext->dynamicAttachmentPtrHashSet.nodePtrs[nodeIndex];
            while (pNode)
            {
                pDynamicAttachment = *(TknAttachment **)pNode->data;
                pNode = pNode->pNextNode;
                destroyDynamicAttachmentPtr(pTknGfxContext, pDynamicAttachment);
            }
        }
    }
    tknAssert(0 == pTknGfxContext->dynamicAttachmentPtrHashSet.count, "Dynamic attachment hash set should be empty before destroying TknGfxContext.");
    tknDestroyHashSet(pTknGfxContext->dynamicAttachmentPtrHashSet);

    // Safely destroy all fixed attachments by repeatedly taking the first one
    while (pTknGfxContext->fixedAttachmentPtrHashSet.count > 0)
    {
        TknAttachment *pFixedAttachment = NULL;
        for (uint32_t nodeIndex = 0; nodeIndex < pTknGfxContext->fixedAttachmentPtrHashSet.capacity; nodeIndex++)
        {
            TknListNode *pNode = pTknGfxContext->fixedAttachmentPtrHashSet.nodePtrs[nodeIndex];
            while (pNode)
            {
                pFixedAttachment = *(TknAttachment **)pNode->data;
                pNode = pNode->pNextNode;
                destroyFixedAttachmentPtr(pTknGfxContext, pFixedAttachment);
            }
        }
    }
    tknAssert(0 == pTknGfxContext->fixedAttachmentPtrHashSet.count, "Fixed attachment hash set should be empty before destroying TknGfxContext.");
    tknDestroyHashSet(pTknGfxContext->fixedAttachmentPtrHashSet);

    if (pTknGfxContext->pEmptyUniformBuffer)
    {
        destroyUniformBufferPtr(pTknGfxContext, pTknGfxContext->pEmptyUniformBuffer);
        pTknGfxContext->pEmptyUniformBuffer = NULL;
    }

    if (pTknGfxContext->pEmptySampler)
    {
        vkDestroySampler(pTknGfxContext->vkDevice, pTknGfxContext->pEmptySampler->vkSampler, NULL);
        tknDestroyHashSet(pTknGfxContext->pEmptySampler->bindingPtrHashSet);
        tknFree(pTknGfxContext->pEmptySampler);
        pTknGfxContext->pEmptySampler = NULL;
    }

    if (pTknGfxContext->pEmptyImage)
    {
        destroyImagePtr(pTknGfxContext, pTknGfxContext->pEmptyImage);
        pTknGfxContext->pEmptyImage = NULL;
    }
}

TknGfxContext *createGfxContextPtr(int targetSwapchainImageCount, VkSurfaceFormatKHR targetVkSurfaceFormat, VkPresentModeKHR targetVkPresentMode, VkInstance vkInstance, VkSurfaceKHR vkSurface, VkExtent2D swapchainExtent, uint32_t spvPathCount, const char **spvPaths)
{
    TknGfxContext *pTknGfxContext = tknMalloc(sizeof(TknGfxContext));
    *pTknGfxContext = (TknGfxContext){
        .frameCount = 0,
        .vkInstance = vkInstance,
        .vkSurface = vkSurface,

        .vkPhysicalDevice = VK_NULL_HANDLE,
        .vkPhysicalDeviceProperties = {},
        .gfxQueueFamilyIndex = UINT32_MAX,
        .presentQueueFamilyIndex = UINT32_MAX,

        .surfaceFormat = {},
        .presentMode = VK_PRESENT_MODE_IMMEDIATE_KHR,

        .vkDevice = VK_NULL_HANDLE,
        .vkGfxQueue = VK_NULL_HANDLE,
        .vkPresentQueue = VK_NULL_HANDLE,

        .pSwapchainAttachment = NULL,

        .imageAvailableSemaphore = VK_NULL_HANDLE,
        .renderFinishedSemaphore = VK_NULL_HANDLE,
        .renderFinishedFence = VK_NULL_HANDLE,

        .gfxVkCommandPool = VK_NULL_HANDLE,
        .gfxVkCommandBuffers = NULL,

        .dynamicAttachmentPtrHashSet = {},
        .renderPassPtrDynamicArray = {},
        .pGlobalDescriptorSet = NULL,
    };
    pickPhysicalDevice(pTknGfxContext, targetVkSurfaceFormat, targetVkPresentMode);
    populateLogicalDevice(pTknGfxContext);
    createSwapchainAttachmentPtr(pTknGfxContext, swapchainExtent, targetSwapchainImageCount);
    populateSignals(pTknGfxContext);
    populateCommandPools(pTknGfxContext);
    populateVkCommandBuffers(pTknGfxContext);
    setupRenderPipelineAndResources(pTknGfxContext, spvPathCount, spvPaths);
    return pTknGfxContext;
}
void destroyGfxContextPtr(TknGfxContext *pTknGfxContext)
{
    assertVkResult(vkDeviceWaitIdle(pTknGfxContext->vkDevice));

    teardownRenderPipelineAndResources(pTknGfxContext);
    cleanupVkCommandBuffers(pTknGfxContext);
    cleanupCommandPools(pTknGfxContext);
    cleanupSignals(pTknGfxContext);
    destroySwapchainAttachmentPtr(pTknGfxContext);
    cleanupLogicalDevice(pTknGfxContext);
    tknFree(pTknGfxContext);
}
void updateGfxContextPtr(TknGfxContext *pTknGfxContext, VkExtent2D swapchainExtent)
{
    SwapchainAttachment *pSwapchainAttachment = &pTknGfxContext->pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    if (pTknGfxContext->renderPassPtrDynamicArray.count > 0)
    {
        pTknGfxContext->frameCount++;
        uint32_t swapchainIndex = pTknGfxContext->frameCount % pSwapchainAttachment->swapchainImageCount;
        VkDevice vkDevice = pTknGfxContext->vkDevice;

        if (swapchainExtent.width != pSwapchainAttachment->swapchainExtent.width || swapchainExtent.height != pSwapchainAttachment->swapchainExtent.height)
        {
            printf("Recreate swapchain because of a size change: (%d, %d) to (%d, %d) \n",
                   pSwapchainAttachment->swapchainExtent.width,
                   pSwapchainAttachment->swapchainExtent.height,
                   swapchainExtent.width,
                   swapchainExtent.height);
            updateSwapchainAttachmentPtr(pTknGfxContext, swapchainExtent);

            TknDynamicArray dirtyRenderPassPtrDynamicArray = tknCreateDynamicArray(sizeof(TknRenderPass *), TKN_DEFAULT_COLLECTION_SIZE);

            for (uint32_t i = 0; i < pTknGfxContext->dynamicAttachmentPtrHashSet.capacity; i++)
            {
                TknListNode *pDynamicAttachmentPtrNode = pTknGfxContext->dynamicAttachmentPtrHashSet.nodePtrs[i];
                while (pDynamicAttachmentPtrNode)
                {
                    TknAttachment *pDynamicAttachment = *(TknAttachment **)pDynamicAttachmentPtrNode->data;
                    resizeDynamicAttachmentPtr(pTknGfxContext, pDynamicAttachment);
                    for (uint32_t i = 0; i < pDynamicAttachment->renderPassPtrHashSet.capacity; i++)
                    {
                        TknListNode *renderPassPtrNode = pDynamicAttachment->renderPassPtrHashSet.nodePtrs[i];
                        while (renderPassPtrNode)
                        {
                            TknRenderPass *pTknRenderPass = *(TknRenderPass **)renderPassPtrNode->data;
                            if (!tknContainsInDynamicArray(&dirtyRenderPassPtrDynamicArray, &pTknRenderPass))
                            {
                                tknAddToDynamicArray(&dirtyRenderPassPtrDynamicArray, &pTknRenderPass);
                            }
                            renderPassPtrNode = renderPassPtrNode->pNextNode;
                        }
                    }
                    pDynamicAttachmentPtrNode = pDynamicAttachmentPtrNode->pNextNode;
                }
            }

            for (uint32_t i = 0; i < pTknGfxContext->pSwapchainAttachment->renderPassPtrHashSet.capacity; i++)
            {
                TknListNode *renderPassPtrNode = pTknGfxContext->pSwapchainAttachment->renderPassPtrHashSet.nodePtrs[i];
                while (renderPassPtrNode)
                {
                    TknRenderPass *pTknRenderPass = *(TknRenderPass **)renderPassPtrNode->data;
                    if (!tknContainsInDynamicArray(&dirtyRenderPassPtrDynamicArray, &pTknRenderPass))
                    {
                        tknAddToDynamicArray(&dirtyRenderPassPtrDynamicArray, &pTknRenderPass);
                    }
                    renderPassPtrNode = renderPassPtrNode->pNextNode;
                }
            }
            for (uint32_t renderPassIndex = 0; renderPassIndex < dirtyRenderPassPtrDynamicArray.count; renderPassIndex++)
            {
                TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&dirtyRenderPassPtrDynamicArray, renderPassIndex);
                repopulateFramebuffers(pTknGfxContext, pTknRenderPass);
            }
            tknDestroyDynamicArray(dirtyRenderPassPtrDynamicArray);
        }
        else
        {
            VkResult result = vkAcquireNextImageKHR(vkDevice, pSwapchainAttachment->vkSwapchain, UINT64_MAX, pTknGfxContext->imageAvailableSemaphore, VK_NULL_HANDLE, &swapchainIndex);
            if (result != VK_SUCCESS)
            {
                if (VK_ERROR_OUT_OF_DATE_KHR == result)
                {
                    printf("Recreate swapchain because of result: %d\n", result);
                    updateSwapchainAttachmentPtr(pTknGfxContext, pSwapchainAttachment->swapchainExtent);
                    for (uint32_t renderPassIndex = 0; renderPassIndex < pTknGfxContext->renderPassPtrDynamicArray.count; renderPassIndex++)
                    {
                        TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->renderPassPtrDynamicArray, renderPassIndex);
                        TknAttachment *pSwapchainAttachment = getSwapchainAttachmentPtr(pTknGfxContext);
                        if (tknContainsInHashSet(&pSwapchainAttachment->renderPassPtrHashSet, &pTknRenderPass))
                        {
                            repopulateFramebuffers(pTknGfxContext, pTknRenderPass);
                        }
                        else
                        {
                            // Don't need to recreate framebuffers
                        }
                    }
                }
                else if (VK_SUBOPTIMAL_KHR == result)
                {
                    assertVkResult(vkResetFences(vkDevice, 1, &pTknGfxContext->renderFinishedFence));
                    recordCommandBuffer(pTknGfxContext, swapchainIndex);
                    submitCommandBuffer(pTknGfxContext, swapchainIndex);
                    present(pTknGfxContext, swapchainIndex);
                }
                else
                {
                    assertVkResult(result);
                }
            }
            else
            {
                assertVkResult(vkResetFences(vkDevice, 1, &pTknGfxContext->renderFinishedFence));
                recordCommandBuffer(pTknGfxContext, swapchainIndex);
                submitCommandBuffer(pTknGfxContext, swapchainIndex);
                present(pTknGfxContext, swapchainIndex);
            }
        }
    }
    else
    {
        printf("No render passes available, skipping updateGfxContextPtr.\n");
    }
}
void waitGfxRenderFence(TknGfxContext *pTknGfxContext)
{
    assertVkResult(vkWaitForFences(pTknGfxContext->vkDevice, 1, &pTknGfxContext->renderFinishedFence, VK_TRUE, UINT64_MAX));
}
void waitGfxDeviceIdle(TknGfxContext *pTknGfxContext)
{
    assertVkResult(vkDeviceWaitIdle(pTknGfxContext->vkDevice));
}
