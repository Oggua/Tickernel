#include "tknGfxCore.h"

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
        tknAssertVkResult(vkGetPhysicalDeviceSurfaceSupportKHR(vkPhysicalDevice, queueFamilyPropertiesIndex, vkSurface, &pSupported));
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
    tknAssertVkResult(vkEnumeratePhysicalDevices(pTknGfxContext->vkInstance, &deviceCount, NULL));
    if (deviceCount <= 0)
    {
        printf("failed to find GPUs with Vulkan support!");
    }
    else
    {
        VkPhysicalDevice *devices = tknMalloc(deviceCount * sizeof(VkPhysicalDevice));
        tknAssertVkResult(vkEnumeratePhysicalDevices(pTknGfxContext->vkInstance, &deviceCount, devices));
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
            tknAssertVkResult(vkEnumerateDeviceExtensionProperties(vkPhysicalDevice, NULL, &extensionCount, NULL));
            VkExtensionProperties *extensionProperties = tknMalloc(extensionCount * sizeof(VkExtensionProperties));
            tknAssertVkResult(vkEnumerateDeviceExtensionProperties(vkPhysicalDevice, NULL, &extensionCount, extensionProperties));
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

            uint32_t tknGfxQueueFamilyIndex;
            uint32_t tknPresentQueueFamilyIndex;
            getGfxAndPresentQueueFamilyIndices(pTknGfxContext, vkPhysicalDevice, &tknGfxQueueFamilyIndex, &tknPresentQueueFamilyIndex);
            if (UINT32_MAX == tknGfxQueueFamilyIndex || UINT32_MAX == tknPresentQueueFamilyIndex)
            {
                // No gfx or present queue family index
                continue;
            }

            uint32_t surfaceFormatCount;
            tknAssertVkResult(vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &surfaceFormatCount, NULL));
            VkSurfaceFormatKHR *supportedSurfaceFormats = tknMalloc(surfaceFormatCount * sizeof(VkSurfaceFormatKHR));
            tknAssertVkResult(vkGetPhysicalDeviceSurfaceFormatsKHR(vkPhysicalDevice, vkSurface, &surfaceFormatCount, supportedSurfaceFormats));
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
            tknAssertVkResult(vkGetPhysicalDeviceSurfacePresentModesKHR(vkPhysicalDevice, vkSurface, &presentModeCount, NULL));
            VkPresentModeKHR *supportedPresentModes = tknMalloc(presentModeCount * sizeof(VkPresentModeKHR));
            tknAssertVkResult(vkGetPhysicalDeviceSurfacePresentModesKHR(vkPhysicalDevice, vkSurface, &presentModeCount, supportedPresentModes));
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
                pTknGfxContext->tknGfxQueueFamilyIndex = tknGfxQueueFamilyIndex;
                pTknGfxContext->tknPresentQueueFamilyIndex = tknPresentQueueFamilyIndex;
                pTknGfxContext->vkPhysicalDeviceProperties = deviceProperties;
                pTknGfxContext->tknSurfaceFormat = targetVkSurfaceFormat;
                pTknGfxContext->tknPresentMode = targetVkPresentMode;
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
    uint32_t tknGfxQueueFamilyIndex = pTknGfxContext->tknGfxQueueFamilyIndex;
    uint32_t tknPresentQueueFamilyIndex = pTknGfxContext->tknPresentQueueFamilyIndex;
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo *queueCreateInfos;
    uint32_t queueCount;
    if (tknGfxQueueFamilyIndex == tknPresentQueueFamilyIndex)
    {
        queueCount = 1;
        queueCreateInfos = tknMalloc(sizeof(VkDeviceQueueCreateInfo) * queueCount);
        VkDeviceQueueCreateInfo gfxCreateInfo =
            {
                .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .pNext = NULL,
                .flags = 0,
                .queueFamilyIndex = tknGfxQueueFamilyIndex,
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
                .queueFamilyIndex = tknGfxQueueFamilyIndex,
                .queueCount = 1,
                .pQueuePriorities = &queuePriority,
            };
        VkDeviceQueueCreateInfo presentCreateInfo = {
            .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = NULL,
            .flags = 0,
            .queueFamilyIndex = tknPresentQueueFamilyIndex,
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
    tknAssertVkResult(vkCreateDevice(vkPhysicalDevice, &vkDeviceCreateInfo, NULL, &pTknGfxContext->vkDevice));
    vkGetDeviceQueue(pTknGfxContext->vkDevice, tknGfxQueueFamilyIndex, 0, &pTknGfxContext->vkGfxQueue);
    vkGetDeviceQueue(pTknGfxContext->vkDevice, tknPresentQueueFamilyIndex, 0, &pTknGfxContext->vkPresentQueue);
    tknFree(queueCreateInfos);
}
static void cleanupLogicalDevice(TknGfxContext *pTknGfxContext)
{
    vkDestroyDevice(pTknGfxContext->vkDevice, NULL);
}
static void createSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext, VkExtent2D targetSwapchainExtent, uint32_t targetSwapchainImageCount)
{
    TknAttachment *pTknSwapchainAttachment = tknMalloc(sizeof(TknAttachment));

    VkPhysicalDevice vkPhysicalDevice = pTknGfxContext->vkPhysicalDevice;
    VkSurfaceKHR vkSurface = pTknGfxContext->vkSurface;
    VkDevice vkDevice = pTknGfxContext->vkDevice;

    tknAssertVkResult(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vkPhysicalDevice, vkSurface, &pTknGfxContext->vkSurfaceCapabilities));

    uint32_t tknSwapchainImageCount = TKN_CLAMP(targetSwapchainImageCount, pTknGfxContext->vkSurfaceCapabilities.minImageCount, pTknGfxContext->vkSurfaceCapabilities.maxImageCount);

    VkExtent2D tknSwapchainExtent;
    tknSwapchainExtent.width = TKN_CLAMP(targetSwapchainExtent.width, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.width, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.width);
    tknSwapchainExtent.height = TKN_CLAMP(targetSwapchainExtent.height, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.height, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.height);

    VkSharingMode imageSharingMode = pTknGfxContext->tknGfxQueueFamilyIndex != pTknGfxContext->tknPresentQueueFamilyIndex ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE;
    uint32_t queueFamilyIndexCount = pTknGfxContext->tknGfxQueueFamilyIndex != pTknGfxContext->tknPresentQueueFamilyIndex ? 2 : 0;
    uint32_t pQueueFamilyIndices[] = {pTknGfxContext->tknGfxQueueFamilyIndex, pTknGfxContext->tknPresentQueueFamilyIndex};

    VkSwapchainCreateInfoKHR swapchainCreateInfo =
        {
            .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .pNext = NULL,
            .flags = 0,
            .surface = vkSurface,
            .minImageCount = tknSwapchainImageCount,
            .imageFormat = pTknGfxContext->tknSurfaceFormat.format,
            .imageColorSpace = pTknGfxContext->tknSurfaceFormat.colorSpace,
            .imageExtent = tknSwapchainExtent,
            .imageArrayLayers = 1,
            .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = imageSharingMode,
            .queueFamilyIndexCount = queueFamilyIndexCount,
            .pQueueFamilyIndices = pQueueFamilyIndices,
            .preTransform = pTknGfxContext->vkSurfaceCapabilities.currentTransform,
            .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = pTknGfxContext->tknPresentMode,
            .clipped = VK_TRUE,
            .oldSwapchain = VK_NULL_HANDLE,
        };
    VkSwapchainKHR vkSwapchain;
    tknAssertVkResult(vkCreateSwapchainKHR(vkDevice, &swapchainCreateInfo, NULL, &vkSwapchain));

    VkImage *tknSwapchainImages = tknMalloc(tknSwapchainImageCount * sizeof(VkImage));
    tknAssertVkResult(vkGetSwapchainImagesKHR(vkDevice, vkSwapchain, &tknSwapchainImageCount, tknSwapchainImages));
    VkImageView *tknSwapchainImageViews = tknMalloc(tknSwapchainImageCount * sizeof(VkImageView));
    for (uint32_t i = 0; i < tknSwapchainImageCount; i++)
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
            .image = tknSwapchainImages[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D,
            .format = pTknGfxContext->tknSurfaceFormat.format,
            .components = components,
            .subresourceRange = subresourceRange,
        };
        tknAssertVkResult(vkCreateImageView(vkDevice, &imageViewCreateInfo, NULL, &tknSwapchainImageViews[i]));
    }
    *pTknSwapchainAttachment = (TknAttachment){
        .tknAttachmentType = TKN_ATTACHMENT_TYPE_SWAPCHAIN,
        .tknAttachmentUnion.tknSwapchainAttachment = {
            .tknSwapchainExtent = tknSwapchainExtent,
            .vkSwapchain = vkSwapchain,
            .tknSwapchainImageCount = tknSwapchainImageCount,
            .tknSwapchainImages = tknSwapchainImages,
            .tknSwapchainImageViews = tknSwapchainImageViews,
        },
        .vkFormat = pTknGfxContext->tknSurfaceFormat.format,
        .tknRenderPassPtrHashSet = tknCreateHashSet(sizeof(TknRenderPass *)),
    };
    pTknGfxContext->pTknSwapchainAttachment = pTknSwapchainAttachment;
};
static void destroySwapchainAttachmentPtr(TknGfxContext *pTknGfxContext)
{
    TknAttachment *pTknSwapchainAttachment = pTknGfxContext->pTknSwapchainAttachment;
    tknAssert(0 == pTknSwapchainAttachment->tknRenderPassPtrHashSet.count, "TknRenderPass hash set should be empty before destroying TknSwapchainAttachment.");

    VkDevice vkDevice = pTknGfxContext->vkDevice;
    TknSwapchainAttachment swapchainAttachment = pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    for (uint32_t i = 0; i < swapchainAttachment.tknSwapchainImageCount; i++)
    {
        vkDestroyImageView(vkDevice, swapchainAttachment.tknSwapchainImageViews[i], NULL);
    }
    tknFree(swapchainAttachment.tknSwapchainImageViews);
    tknFree(swapchainAttachment.tknSwapchainImages);
    vkDestroySwapchainKHR(vkDevice, swapchainAttachment.vkSwapchain, NULL);

    tknDestroyHashSet(pTknSwapchainAttachment->tknRenderPassPtrHashSet);
    tknFree(pTknSwapchainAttachment);
    pTknGfxContext->pTknSwapchainAttachment = NULL;
}
static void updateSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext, VkExtent2D tknSwapchainExtent)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    tknAssertVkResult(vkDeviceWaitIdle(vkDevice));
    TknAttachment *pTknAttachment = pTknGfxContext->pTknSwapchainAttachment;
    TknSwapchainAttachment *pTknSwapchainAttachment = &pTknAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    for (uint32_t i = 0; i < pTknSwapchainAttachment->tknSwapchainImageCount; i++)
    {
        vkDestroyImageView(vkDevice, pTknSwapchainAttachment->tknSwapchainImageViews[i], NULL);
    }
    vkDestroySwapchainKHR(vkDevice, pTknSwapchainAttachment->vkSwapchain, NULL);

    tknSwapchainExtent.width = TKN_CLAMP(tknSwapchainExtent.width, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.width, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.width);
    tknSwapchainExtent.height = TKN_CLAMP(tknSwapchainExtent.height, pTknGfxContext->vkSurfaceCapabilities.minImageExtent.height, pTknGfxContext->vkSurfaceCapabilities.maxImageExtent.height);
    pTknSwapchainAttachment->tknSwapchainExtent = tknSwapchainExtent;

    VkSharingMode imageSharingMode = pTknGfxContext->tknGfxQueueFamilyIndex != pTknGfxContext->tknPresentQueueFamilyIndex ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE;
    uint32_t queueFamilyIndexCount = pTknGfxContext->tknGfxQueueFamilyIndex != pTknGfxContext->tknPresentQueueFamilyIndex ? 2 : 0;
    uint32_t pQueueFamilyIndices[] = {pTknGfxContext->tknGfxQueueFamilyIndex, pTknGfxContext->tknPresentQueueFamilyIndex};
    VkSwapchainCreateInfoKHR swapchainCreateInfo =
        {
            .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .pNext = NULL,
            .flags = 0,
            .surface = pTknGfxContext->vkSurface,
            .minImageCount = pTknSwapchainAttachment->tknSwapchainImageCount,
            .imageFormat = pTknGfxContext->tknSurfaceFormat.format,
            .imageColorSpace = pTknGfxContext->tknSurfaceFormat.colorSpace,
            .imageExtent = tknSwapchainExtent,
            .imageArrayLayers = 1,
            .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = imageSharingMode,
            .queueFamilyIndexCount = queueFamilyIndexCount,
            .pQueueFamilyIndices = pQueueFamilyIndices,
            .preTransform = pTknGfxContext->vkSurfaceCapabilities.currentTransform,
            .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = pTknGfxContext->tknPresentMode,
            .clipped = VK_TRUE,
            .oldSwapchain = VK_NULL_HANDLE,
        };
    tknAssertVkResult(vkCreateSwapchainKHR(vkDevice, &swapchainCreateInfo, NULL, &pTknSwapchainAttachment->vkSwapchain));
    tknAssertVkResult(vkGetSwapchainImagesKHR(vkDevice, pTknSwapchainAttachment->vkSwapchain, &pTknSwapchainAttachment->tknSwapchainImageCount, pTknSwapchainAttachment->tknSwapchainImages));
    for (uint32_t i = 0; i < pTknSwapchainAttachment->tknSwapchainImageCount; i++)
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
            .image = pTknSwapchainAttachment->tknSwapchainImages[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D,
            .format = pTknGfxContext->tknSurfaceFormat.format,
            .components = components,
            .subresourceRange = subresourceRange,
        };
        tknAssertVkResult(vkCreateImageView(vkDevice, &imageViewCreateInfo, NULL, &pTknSwapchainAttachment->tknSwapchainImageViews[i]));
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
    tknAssertVkResult(vkCreateSemaphore(vkDevice, &semaphoreCreateInfo, NULL, &pTknGfxContext->vkImageAvailableSemaphore));
    tknAssertVkResult(vkCreateSemaphore(vkDevice, &semaphoreCreateInfo, NULL, &pTknGfxContext->vkRenderFinishedSemaphore));
    tknAssertVkResult(vkCreateFence(vkDevice, &fenceCreateInfo, NULL, &pTknGfxContext->vkRenderFinishedFence));
}
static void cleanupSignals(TknGfxContext *pTknGfxContext)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroySemaphore(vkDevice, pTknGfxContext->vkImageAvailableSemaphore, NULL);
    vkDestroySemaphore(vkDevice, pTknGfxContext->vkRenderFinishedSemaphore, NULL);
    vkDestroyFence(vkDevice, pTknGfxContext->vkRenderFinishedFence, NULL);
}
static void populateCommandPools(TknGfxContext *pTknGfxContext)
{
    VkCommandPoolCreateInfo vkCommandPoolCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = NULL,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = pTknGfxContext->tknGfxQueueFamilyIndex,
    };
    tknAssertVkResult(vkCreateCommandPool(pTknGfxContext->vkDevice, &vkCommandPoolCreateInfo, NULL, &pTknGfxContext->vkGfxCommandPool));
}
static void cleanupCommandPools(TknGfxContext *pTknGfxContext)
{
    vkDestroyCommandPool(pTknGfxContext->vkDevice, pTknGfxContext->vkGfxCommandPool, NULL);
}
static void populateVkCommandBuffers(TknGfxContext *pTknGfxContext)
{
    TknSwapchainAttachment *pTknSwapchainAttachment = &pTknGfxContext->pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    pTknGfxContext->vkGfxCommandBuffers = tknMalloc(sizeof(VkCommandBuffer) * pTknSwapchainAttachment->tknSwapchainImageCount);
    VkCommandBufferAllocateInfo vkCommandBufferAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = NULL,
        .commandPool = pTknGfxContext->vkGfxCommandPool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = pTknSwapchainAttachment->tknSwapchainImageCount,
    };
    tknAssertVkResult(vkAllocateCommandBuffers(pTknGfxContext->vkDevice, &vkCommandBufferAllocateInfo, pTknGfxContext->vkGfxCommandBuffers));
}
static void cleanupVkCommandBuffers(TknGfxContext *pTknGfxContext)
{
    TknSwapchainAttachment *pTknSwapchainAttachment = &pTknGfxContext->pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    vkFreeCommandBuffers(pTknGfxContext->vkDevice, pTknGfxContext->vkGfxCommandPool, pTknSwapchainAttachment->tknSwapchainImageCount, pTknGfxContext->vkGfxCommandBuffers);
    tknFree(pTknGfxContext->vkGfxCommandBuffers);
}
static void recordCommandBuffer(TknGfxContext *pTknGfxContext, uint32_t swapchainIndex)
{
    VkCommandBuffer vkCommandBuffer = pTknGfxContext->vkGfxCommandBuffers[swapchainIndex];
    VkCommandBufferBeginInfo vkCommandBufferBeginInfo =
        {
            .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = NULL,
            .flags = 0,
            .pInheritanceInfo = NULL,
        };
    tknAssertVkResult(vkBeginCommandBuffer(vkCommandBuffer, &vkCommandBufferBeginInfo));
    TknMaterial *pGlobalMaterial = tknGetGlobalMaterialPtr(pTknGfxContext);
    for (uint32_t renderPassIndex = 0; renderPassIndex < pTknGfxContext->tknRenderPassPtrDynamicArray.count; renderPassIndex++)
    {
        TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->tknRenderPassPtrDynamicArray, renderPassIndex);
        VkRenderPassBeginInfo renderPassBeginInfo = {
            .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .pNext = NULL,
            .renderPass = pTknRenderPass->vkRenderPass,
            .framebuffer = pTknRenderPass->vkFramebuffers[swapchainIndex],
            .renderArea = pTknRenderPass->tknRenderArea,
            .clearValueCount = pTknRenderPass->tknAttachmentCount,
            .pClearValues = pTknRenderPass->vkClearValues,
        };
        vkCmdBeginRenderPass(vkCommandBuffer, &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
        VkViewport vkViewport = {
            .x = 0.0f,
            .y = 0.0f,
            .width = pTknRenderPass->tknRenderArea.extent.width,
            .height = pTknRenderPass->tknRenderArea.extent.height,
            .minDepth = 0.0f,
            .maxDepth = 1.0f,
        };
        vkCmdSetViewport(vkCommandBuffer, 0, 1, &vkViewport);

        VkRect2D scissor = {
            .offset = {0, 0},
            .extent = pTknRenderPass->tknRenderArea.extent,
        };
        vkCmdSetScissor(vkCommandBuffer, 0, 1, &scissor);
        for (uint32_t tknSubpassIndex = 0; tknSubpassIndex < pTknRenderPass->tknSubpassCount; tknSubpassIndex++)
        {
            if (tknSubpassIndex > 0)
            {
                vkCmdNextSubpass(vkCommandBuffer, VK_SUBPASS_CONTENTS_INLINE);
            }
            struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[tknSubpassIndex];
            TknMaterial *pSubpassMaterial = tknGetSubpassMaterialPtr(pTknGfxContext, pTknRenderPass, tknSubpassIndex);
            TknPipeline *pCurrentPipeline = NULL;
            // Iterate all drawcalls in subpass order, switching pipelines as needed
            for (uint32_t drawCallIndex = 0; drawCallIndex < pTknSubpass->tknDrawCallPtrDynamicArray.count; drawCallIndex++)
            {
                TknDrawCall *pTknDrawCall = *(TknDrawCall **)tknGetFromDynamicArray(&pTknSubpass->tknDrawCallPtrDynamicArray, drawCallIndex);
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
                    if (pTknDrawCall->pTknInstance != NULL && pTknDrawCall->pTknInstance->tknInstanceCount > 0)
                    {
                        tknAssert(pTknDrawCall->pTknMesh->tknVertexCount > 0, "TknMesh has no vertices");
                        VkBuffer vertexBuffers[] = {pTknMesh->tknVertexVkBuffer, pTknDrawCall->pTknInstance->tknInstanceVkBuffer};
                        VkDeviceSize offsets[] = {0, 0};
                        vkCmdBindVertexBuffers(vkCommandBuffer, 0, 2, vertexBuffers, offsets);
                        if (pTknMesh->tknIndexCount > 0)
                        {
                            vkCmdBindIndexBuffer(vkCommandBuffer, pTknMesh->tknIndexVkBuffer, 0, pTknMesh->vkIndexType);
                            vkCmdDrawIndexed(vkCommandBuffer, pTknMesh->tknIndexCount, pTknDrawCall->pTknInstance->tknInstanceCount, 0, 0, 0);
                        }
                        else
                        {
                            vkCmdDraw(vkCommandBuffer, pTknMesh->tknVertexCount, pTknDrawCall->pTknInstance->tknInstanceCount, 0, 0);
                        }
                    }
                    else
                    {
                        // Simple case: only bind vertex buffer (no instancing)
                        VkBuffer vertexBuffers[] = {pTknMesh->tknVertexVkBuffer};
                        VkDeviceSize offsets[] = {0};
                        vkCmdBindVertexBuffers(vkCommandBuffer, 0, 1, vertexBuffers, offsets);

                        if (pTknMesh->tknIndexCount > 0)
                        {
                            vkCmdBindIndexBuffer(vkCommandBuffer, pTknMesh->tknIndexVkBuffer, 0, pTknMesh->vkIndexType);
                            vkCmdDrawIndexed(vkCommandBuffer, pTknMesh->tknIndexCount, 1, 0, 0, 0);
                        }
                        else
                        {
                            vkCmdDraw(vkCommandBuffer, pTknMesh->tknVertexCount, 1, 0, 0);
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

    tknAssertVkResult(vkEndCommandBuffer(vkCommandBuffer));
}
static void submitCommandBuffer(TknGfxContext *pTknGfxContext, uint32_t swapchainIndex)
{
    // Submit workflow...
    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = NULL,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = (VkSemaphore[]){pTknGfxContext->vkImageAvailableSemaphore},
        .pWaitDstStageMask = (VkPipelineStageFlags[]){VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
        .commandBufferCount = 1,
        .pCommandBuffers = &pTknGfxContext->vkGfxCommandBuffers[swapchainIndex],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = (VkSemaphore[]){pTknGfxContext->vkRenderFinishedSemaphore},
    };

    tknAssertVkResult(vkQueueSubmit(pTknGfxContext->vkGfxQueue, 1, &submitInfo, pTknGfxContext->vkRenderFinishedFence));
}
static void present(TknGfxContext *pTknGfxContext, uint32_t swapchainIndex)
{
    TknSwapchainAttachment *pTknSwapchainAttachment = &pTknGfxContext->pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    VkPresentInfoKHR presentInfo = {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pNext = NULL,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = (VkSemaphore[]){pTknGfxContext->vkRenderFinishedSemaphore},
        .swapchainCount = 1,
        .pSwapchains = (VkSwapchainKHR[]){pTknSwapchainAttachment->vkSwapchain},
        .pImageIndices = &swapchainIndex,
        .pResults = NULL,
    };
    VkResult result = vkQueuePresentKHR(pTknGfxContext->vkPresentQueue, &presentInfo);
    if (VK_ERROR_OUT_OF_DATE_KHR == result || VK_SUBOPTIMAL_KHR == result)
    {
        printf("Recreate swapchain because of the result: %d when presenting.\n", result);
        updateSwapchainAttachmentPtr(pTknGfxContext, pTknSwapchainAttachment->tknSwapchainExtent);
        for (uint32_t renderPassIndex = 0; renderPassIndex < pTknGfxContext->tknRenderPassPtrDynamicArray.count; renderPassIndex++)
        {
            TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->tknRenderPassPtrDynamicArray, renderPassIndex);
            TknAttachment *pTknSwapchainAttachment = tknGetSwapchainAttachmentPtr(pTknGfxContext);
            if (tknContainsInHashSet(&pTknSwapchainAttachment->tknRenderPassPtrHashSet, &pTknRenderPass))
            {
                tknRepopulateFramebuffers(pTknGfxContext, pTknRenderPass);
            }
            else
            {
                // Don't need to recreate framebuffers
            }
        }
    }
    else
    {
        tknAssertVkResult(result);
    }
}
static void setupRenderPipelineAndResources(TknGfxContext *pTknGfxContext, uint32_t spvPathCount, const char **spvPaths)
{
    // Create empty resources for empty bindings
    uint32_t emptyData = 0;
    pTknGfxContext->pTknEmptyUniformBuffer = tknCreateUniformBufferPtr(pTknGfxContext, &emptyData, sizeof(emptyData));

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

    pTknGfxContext->pTknEmptySampler = tknMalloc(sizeof(TknSampler));
    pTknGfxContext->pTknEmptySampler->tknBindingPtrHashSet = tknCreateHashSet(sizeof(TknBinding *));
    tknAssertVkResult(vkCreateSampler(pTknGfxContext->vkDevice, &samplerCreateInfo, NULL, &pTknGfxContext->pTknEmptySampler->vkSampler));

    // Create empty image for input attachments, sampling, and storage
    VkExtent3D emptyImageExtent = {.width = 1, .height = 1, .depth = 1};
    pTknGfxContext->pTknEmptyImage = tknCreateImagePtr(
        pTknGfxContext,
        emptyImageExtent,
        VK_FORMAT_R8G8B8A8_UNORM,
        VK_IMAGE_TILING_OPTIMAL,
        VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_STORAGE_BIT,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        VK_IMAGE_ASPECT_COLOR_BIT,
        NULL,
        0);

    pTknGfxContext->tknDynamicAttachmentPtrHashSet = tknCreateHashSet(sizeof(TknAttachment *));
    pTknGfxContext->tknFixedAttachmentPtrHashSet = tknCreateHashSet(sizeof(TknAttachment *));
    pTknGfxContext->tknRenderPassPtrDynamicArray = tknCreateDynamicArray(sizeof(TknRenderPass *), TKN_DEFAULT_COLLECTION_SIZE);
    SpvReflectShaderModule *spvReflectShaderModules = tknMalloc(sizeof(SpvReflectShaderModule) * spvPathCount);
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        spvReflectShaderModules[spvPathIndex] = tknCreateSpvReflectShaderModule(spvPaths[spvPathIndex]);
    }
    pTknGfxContext->pTknGlobalDescriptorSet = tknCreateDescriptorSetPtr(pTknGfxContext, spvPathCount, spvReflectShaderModules, TKN_GLOBAL_DESCRIPTOR_SET);
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        tknDestroySpvReflectShaderModule(&spvReflectShaderModules[spvPathIndex]);
    }
    tknFree(spvReflectShaderModules);
    tknCreateMaterialPtr(pTknGfxContext, pTknGfxContext->pTknGlobalDescriptorSet);

    pTknGfxContext->tknVertexInputLayoutPtrHashSet = tknCreateHashSet(sizeof(TknVertexInputLayout *));
}
static void teardownRenderPipelineAndResources(TknGfxContext *pTknGfxContext)
{
    for (uint32_t i = 0; i < pTknGfxContext->tknRenderPassPtrDynamicArray.count; i++)
    {
        TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->tknRenderPassPtrDynamicArray, i);
        tknDestroyRenderPassPtr(pTknGfxContext, pTknRenderPass);
    }
    tknClearDynamicArray(&pTknGfxContext->tknRenderPassPtrDynamicArray);
    tknAssert(pTknGfxContext->tknRenderPassPtrDynamicArray.count == 0, "Render pass dynamic array should be empty before destroying TknGfxContext.");
    tknDestroyDynamicArray(pTknGfxContext->tknRenderPassPtrDynamicArray);

    tknDestroyDescriptorSetPtr(pTknGfxContext, pTknGfxContext->pTknGlobalDescriptorSet);
    tknAssert(pTknGfxContext->tknVertexInputLayoutPtrHashSet.count == 0, "Vertex input layout hash set should be empty before destroying TknGfxContext.");
    tknDestroyHashSet(pTknGfxContext->tknVertexInputLayoutPtrHashSet);

    while (pTknGfxContext->tknDynamicAttachmentPtrHashSet.count > 0)
    {
        TknAttachment *pDynamicAttachment = NULL;
        for (uint32_t nodeIndex = 0; nodeIndex < pTknGfxContext->tknDynamicAttachmentPtrHashSet.capacity; nodeIndex++)
        {
            TknListNode *pNode = pTknGfxContext->tknDynamicAttachmentPtrHashSet.nodePtrs[nodeIndex];
            while (pNode)
            {
                pDynamicAttachment = *(TknAttachment **)pNode->data;
                pNode = pNode->pNextNode;
                tknDestroyDynamicAttachmentPtr(pTknGfxContext, pDynamicAttachment);
            }
        }
    }
    tknAssert(0 == pTknGfxContext->tknDynamicAttachmentPtrHashSet.count, "Dynamic attachment hash set should be empty before destroying TknGfxContext.");
    tknDestroyHashSet(pTknGfxContext->tknDynamicAttachmentPtrHashSet);

    // Safely destroy all fixed attachments by repeatedly taking the first one
    while (pTknGfxContext->tknFixedAttachmentPtrHashSet.count > 0)
    {
        TknAttachment *pFixedAttachment = NULL;
        for (uint32_t nodeIndex = 0; nodeIndex < pTknGfxContext->tknFixedAttachmentPtrHashSet.capacity; nodeIndex++)
        {
            TknListNode *pNode = pTknGfxContext->tknFixedAttachmentPtrHashSet.nodePtrs[nodeIndex];
            while (pNode)
            {
                pFixedAttachment = *(TknAttachment **)pNode->data;
                pNode = pNode->pNextNode;
                tknDestroyFixedAttachmentPtr(pTknGfxContext, pFixedAttachment);
            }
        }
    }
    tknAssert(0 == pTknGfxContext->tknFixedAttachmentPtrHashSet.count, "Fixed attachment hash set should be empty before destroying TknGfxContext.");
    tknDestroyHashSet(pTknGfxContext->tknFixedAttachmentPtrHashSet);

    if (pTknGfxContext->pTknEmptyUniformBuffer)
    {
        tknDestroyUniformBufferPtr(pTknGfxContext, pTknGfxContext->pTknEmptyUniformBuffer);
        pTknGfxContext->pTknEmptyUniformBuffer = NULL;
    }

    if (pTknGfxContext->pTknEmptySampler)
    {
        vkDestroySampler(pTknGfxContext->vkDevice, pTknGfxContext->pTknEmptySampler->vkSampler, NULL);
        tknDestroyHashSet(pTknGfxContext->pTknEmptySampler->tknBindingPtrHashSet);
        tknFree(pTknGfxContext->pTknEmptySampler);
        pTknGfxContext->pTknEmptySampler = NULL;
    }

    if (pTknGfxContext->pTknEmptyImage)
    {
        tknDestroyImagePtr(pTknGfxContext, pTknGfxContext->pTknEmptyImage);
        pTknGfxContext->pTknEmptyImage = NULL;
    }
}

TknGfxContext *tknCreateGfxContextPtr(int targetSwapchainImageCount, VkSurfaceFormatKHR targetVkSurfaceFormat, VkPresentModeKHR targetVkPresentMode, VkInstance vkInstance, VkSurfaceKHR vkSurface, VkExtent2D tknSwapchainExtent, uint32_t spvPathCount, const char **spvPaths)
{
    TknGfxContext *pTknGfxContext = tknMalloc(sizeof(TknGfxContext));
    *pTknGfxContext = (TknGfxContext){
        .tknFrameCount = 0,
        .vkInstance = vkInstance,
        .vkSurface = vkSurface,

        .vkPhysicalDevice = VK_NULL_HANDLE,
        .vkPhysicalDeviceProperties = {},
        .tknGfxQueueFamilyIndex = UINT32_MAX,
        .tknPresentQueueFamilyIndex = UINT32_MAX,

        .tknSurfaceFormat = {},
        .tknPresentMode = VK_PRESENT_MODE_IMMEDIATE_KHR,

        .vkDevice = VK_NULL_HANDLE,
        .vkGfxQueue = VK_NULL_HANDLE,
        .vkPresentQueue = VK_NULL_HANDLE,

        .pTknSwapchainAttachment = NULL,

        .vkImageAvailableSemaphore = VK_NULL_HANDLE,
        .vkRenderFinishedSemaphore = VK_NULL_HANDLE,
        .vkRenderFinishedFence = VK_NULL_HANDLE,

        .vkGfxCommandPool = VK_NULL_HANDLE,
        .vkGfxCommandBuffers = NULL,

        .tknDynamicAttachmentPtrHashSet = {},
        .tknRenderPassPtrDynamicArray = {},
        .pTknGlobalDescriptorSet = NULL,
    };
    pickPhysicalDevice(pTknGfxContext, targetVkSurfaceFormat, targetVkPresentMode);
    populateLogicalDevice(pTknGfxContext);
    createSwapchainAttachmentPtr(pTknGfxContext, tknSwapchainExtent, targetSwapchainImageCount);
    populateSignals(pTknGfxContext);
    populateCommandPools(pTknGfxContext);
    populateVkCommandBuffers(pTknGfxContext);
    setupRenderPipelineAndResources(pTknGfxContext, spvPathCount, spvPaths);
    return pTknGfxContext;
}
void tknDestroyGfxContextPtr(TknGfxContext *pTknGfxContext)
{
    tknAssertVkResult(vkDeviceWaitIdle(pTknGfxContext->vkDevice));

    teardownRenderPipelineAndResources(pTknGfxContext);
    cleanupVkCommandBuffers(pTknGfxContext);
    cleanupCommandPools(pTknGfxContext);
    cleanupSignals(pTknGfxContext);
    destroySwapchainAttachmentPtr(pTknGfxContext);
    cleanupLogicalDevice(pTknGfxContext);
    tknFree(pTknGfxContext);
}
void tknUpdateGfxContextPtr(TknGfxContext *pTknGfxContext, VkExtent2D tknSwapchainExtent)
{
    TknSwapchainAttachment *pTknSwapchainAttachment = &pTknGfxContext->pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    if (pTknGfxContext->tknRenderPassPtrDynamicArray.count > 0)
    {
        pTknGfxContext->tknFrameCount++;
        uint32_t swapchainIndex = pTknGfxContext->tknFrameCount % pTknSwapchainAttachment->tknSwapchainImageCount;
        VkDevice vkDevice = pTknGfxContext->vkDevice;

        if (tknSwapchainExtent.width != pTknSwapchainAttachment->tknSwapchainExtent.width || tknSwapchainExtent.height != pTknSwapchainAttachment->tknSwapchainExtent.height)
        {
            printf("Recreate swapchain because of a size change: (%d, %d) to (%d, %d) \n",
                   pTknSwapchainAttachment->tknSwapchainExtent.width,
                   pTknSwapchainAttachment->tknSwapchainExtent.height,
                   tknSwapchainExtent.width,
                   tknSwapchainExtent.height);
            updateSwapchainAttachmentPtr(pTknGfxContext, tknSwapchainExtent);

            TknDynamicArray dirtyRenderPassPtrDynamicArray = tknCreateDynamicArray(sizeof(TknRenderPass *), TKN_DEFAULT_COLLECTION_SIZE);

            for (uint32_t i = 0; i < pTknGfxContext->tknDynamicAttachmentPtrHashSet.capacity; i++)
            {
                TknListNode *pDynamicAttachmentPtrNode = pTknGfxContext->tknDynamicAttachmentPtrHashSet.nodePtrs[i];
                while (pDynamicAttachmentPtrNode)
                {
                    TknAttachment *pDynamicAttachment = *(TknAttachment **)pDynamicAttachmentPtrNode->data;
                    tknResizeDynamicAttachmentPtr(pTknGfxContext, pDynamicAttachment);
                    for (uint32_t i = 0; i < pDynamicAttachment->tknRenderPassPtrHashSet.capacity; i++)
                    {
                        TknListNode *renderPassPtrNode = pDynamicAttachment->tknRenderPassPtrHashSet.nodePtrs[i];
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

            for (uint32_t i = 0; i < pTknGfxContext->pTknSwapchainAttachment->tknRenderPassPtrHashSet.capacity; i++)
            {
                TknListNode *renderPassPtrNode = pTknGfxContext->pTknSwapchainAttachment->tknRenderPassPtrHashSet.nodePtrs[i];
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
                tknRepopulateFramebuffers(pTknGfxContext, pTknRenderPass);
            }
            tknDestroyDynamicArray(dirtyRenderPassPtrDynamicArray);
        }
        else
        {
            VkResult result = vkAcquireNextImageKHR(vkDevice, pTknSwapchainAttachment->vkSwapchain, UINT64_MAX, pTknGfxContext->vkImageAvailableSemaphore, VK_NULL_HANDLE, &swapchainIndex);
            if (result != VK_SUCCESS)
            {
                if (VK_ERROR_OUT_OF_DATE_KHR == result)
                {
                    printf("Recreate swapchain because of result: %d\n", result);
                    updateSwapchainAttachmentPtr(pTknGfxContext, pTknSwapchainAttachment->tknSwapchainExtent);
                    for (uint32_t renderPassIndex = 0; renderPassIndex < pTknGfxContext->tknRenderPassPtrDynamicArray.count; renderPassIndex++)
                    {
                        TknRenderPass *pTknRenderPass = *(TknRenderPass **)tknGetFromDynamicArray(&pTknGfxContext->tknRenderPassPtrDynamicArray, renderPassIndex);
                        TknAttachment *pTknSwapchainAttachment = tknGetSwapchainAttachmentPtr(pTknGfxContext);
                        if (tknContainsInHashSet(&pTknSwapchainAttachment->tknRenderPassPtrHashSet, &pTknRenderPass))
                        {
                            tknRepopulateFramebuffers(pTknGfxContext, pTknRenderPass);
                        }
                        else
                        {
                            // Don't need to recreate framebuffers
                        }
                    }
                }
                else if (VK_SUBOPTIMAL_KHR == result)
                {
                    tknAssertVkResult(vkResetFences(vkDevice, 1, &pTknGfxContext->vkRenderFinishedFence));
                    recordCommandBuffer(pTknGfxContext, swapchainIndex);
                    submitCommandBuffer(pTknGfxContext, swapchainIndex);
                    present(pTknGfxContext, swapchainIndex);
                }
                else
                {
                    tknAssertVkResult(result);
                }
            }
            else
            {
                tknAssertVkResult(vkResetFences(vkDevice, 1, &pTknGfxContext->vkRenderFinishedFence));
                recordCommandBuffer(pTknGfxContext, swapchainIndex);
                submitCommandBuffer(pTknGfxContext, swapchainIndex);
                present(pTknGfxContext, swapchainIndex);
            }
        }
    }
    else
    {
        printf("No render passes available, skipping tknUpdateGfxContextPtr.\n");
    }
}
void tknWaitGfxRenderFence(TknGfxContext *pTknGfxContext)
{
    tknAssertVkResult(vkWaitForFences(pTknGfxContext->vkDevice, 1, &pTknGfxContext->vkRenderFinishedFence, VK_TRUE, UINT64_MAX));
}
void tknWaitGfxDeviceIdle(TknGfxContext *pTknGfxContext)
{
    tknAssertVkResult(vkDeviceWaitIdle(pTknGfxContext->vkDevice));
}
