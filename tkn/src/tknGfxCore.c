#include "tknGfxCore.h"

void tknAssertVkResult(VkResult vkResult)
{
    tknAssert(vkResult == VK_SUCCESS, "Vulkan error: %d", vkResult);
}

SpvReflectShaderModule tknCreateSpvReflectShaderModule(const char *filePath)
{
    FILE *file = fopen(filePath, "rb");
    if (!file)
    {
        tknError("Failed to open file: %s\n", filePath);
    }
    else
    {
        // File opened successfully
    }
    fseek(file, 0, SEEK_END);
    size_t shaderSize = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (shaderSize % 4 != 0)
    {
        fclose(file);
        tknError("Invalid SPIR-V file size: %s\n", filePath);
    }
    else
    {
        // Valid SPIR-V file size
    }
    void *shaderCode = tknMalloc(shaderSize);
    size_t bytesRead = fread(shaderCode, 1, shaderSize, file);

    fclose(file);

    if (bytesRead != shaderSize)
    {
        tknError("Failed to read entire file: %s\n", filePath);
    }
    else
    {
        // File read successfully
    }
    SpvReflectShaderModule spvReflectShaderModule;
    SpvReflectResult spvReflectResult = spvReflectCreateShaderModule(shaderSize, shaderCode, &spvReflectShaderModule);
    tknAssert(spvReflectResult == SPV_REFLECT_RESULT_SUCCESS, "Failed to reflect shader module: %s", filePath);
    tknFree(shaderCode);

    return spvReflectShaderModule;
}
void tknDestroySpvReflectShaderModule(SpvReflectShaderModule *pSpvReflectShaderModule)
{
    spvReflectDestroyShaderModule(pSpvReflectShaderModule);
}

static uint32_t getMemoryTypeIndex(VkPhysicalDevice vkPhysicalDevice, uint32_t typeFilter, VkMemoryPropertyFlags memoryPropertyFlags)
{
    VkPhysicalDeviceMemoryProperties physicalDeviceMemoryProperties;
    vkGetPhysicalDeviceMemoryProperties(vkPhysicalDevice, &physicalDeviceMemoryProperties);
    for (uint32_t i = 0; i < physicalDeviceMemoryProperties.memoryTypeCount; i++)
    {
        if ((typeFilter & (1 << i)) && (physicalDeviceMemoryProperties.memoryTypes[i].propertyFlags & memoryPropertyFlags) == memoryPropertyFlags)
        {
            return i;
        }
        else
        {
            // Memory type doesn't match requirements
        }
    }
    tknError("Failed to get suitable memory type!");
    return UINT32_MAX;
}

void tknClearBindingPtrHashSet(TknGfxContext *pTknGfxContext, TknHashSet tknBindingPtrHashSet)
{
    for (uint32_t i = 0; i < tknBindingPtrHashSet.capacity; i++)
    {
        TknListNode *node = tknBindingPtrHashSet.nodePtrs[i];
        while (node)
        {
            TknBinding *pTknBinding = *(TknBinding **)node->data;
            node = node->pNextNode;
            TknInputBinding tknInputBinding = {
                .vkDescriptorType = pTknBinding->vkDescriptorType,
                .tknInputBindingUnion = tknGetEmptyInputBindingUnion(pTknGfxContext, pTknBinding->vkDescriptorType),
                .binding = pTknBinding->binding,
            };
            tknUpdateMaterialPtr(pTknGfxContext, pTknBinding->pTknMaterial, 1, &tknInputBinding);
        }
    }
}

void tknCreateVkImage(TknGfxContext *pTknGfxContext, VkExtent3D vkExtent3D, VkFormat vkFormat, VkImageTiling vkImageTiling, VkImageUsageFlags vkImageUsageFlags, VkMemoryPropertyFlags vkMemoryPropertyFlags, VkImageAspectFlags vkImageAspectFlags, VkImage *pVkImage, VkDeviceMemory *pVkDeviceMemory, VkImageView *pVkImageView)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    VkPhysicalDevice vkPhysicalDevice = pTknGfxContext->vkPhysicalDevice;
    VkImageCreateInfo imageCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .imageType = VK_IMAGE_TYPE_2D,
        .format = vkFormat,
        .extent = vkExtent3D,
        .mipLevels = 1,
        .arrayLayers = 1,
        .samples = VK_SAMPLE_COUNT_1_BIT,
        .tiling = vkImageTiling,
        .usage = vkImageUsageFlags,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = 0,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
    };
    tknAssertVkResult(vkCreateImage(vkDevice, &imageCreateInfo, NULL, pVkImage));
    VkMemoryRequirements memoryRequirements;
    vkGetImageMemoryRequirements(vkDevice, *pVkImage, &memoryRequirements);
    uint32_t memoryTypeIndex = getMemoryTypeIndex(vkPhysicalDevice, memoryRequirements.memoryTypeBits, vkMemoryPropertyFlags);
    VkMemoryAllocateInfo memoryAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = NULL,
        .allocationSize = memoryRequirements.size,
        .memoryTypeIndex = memoryTypeIndex,
    };
    tknAssertVkResult(vkAllocateMemory(vkDevice, &memoryAllocateInfo, NULL, pVkDeviceMemory));
    tknAssertVkResult(vkBindImageMemory(vkDevice, *pVkImage, *pVkDeviceMemory, 0));

    VkComponentMapping components = {
        .r = VK_COMPONENT_SWIZZLE_IDENTITY,
        .g = VK_COMPONENT_SWIZZLE_IDENTITY,
        .b = VK_COMPONENT_SWIZZLE_IDENTITY,
        .a = VK_COMPONENT_SWIZZLE_IDENTITY,
    };
    VkImageSubresourceRange subresourceRange = {
        .aspectMask = vkImageAspectFlags,
        .levelCount = 1,
        .baseMipLevel = 0,
        .layerCount = 1,
        .baseArrayLayer = 0,
    };
    VkImageViewCreateInfo imageViewCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .image = *pVkImage,
        .viewType = VK_IMAGE_VIEW_TYPE_2D,
        .format = vkFormat,
        .components = components,
        .subresourceRange = subresourceRange,
    };
    tknAssertVkResult(vkCreateImageView(vkDevice, &imageViewCreateInfo, NULL, pVkImageView));
}
void tknDestroyVkImage(TknGfxContext *pTknGfxContext, VkImage vkImage, VkDeviceMemory vkDeviceMemory, VkImageView vkImageView)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroyImageView(vkDevice, vkImageView, NULL);
    vkDestroyImage(vkDevice, vkImage, NULL);
    vkFreeMemory(vkDevice, vkDeviceMemory, NULL);
}

void tknCreateVkBuffer(TknGfxContext *pTknGfxContext, VkDeviceSize bufferSize, VkBufferUsageFlags bufferUsageFlags, VkMemoryPropertyFlags memoryPropertyFlags, VkBuffer *pVkBuffer, VkDeviceMemory *pVkDeviceMemory)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    VkPhysicalDevice vkPhysicalDevice = pTknGfxContext->vkPhysicalDevice;
    VkBufferCreateInfo bufferCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .size = bufferSize,
        .usage = bufferUsageFlags,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = 0,
    };
    tknAssertVkResult(vkCreateBuffer(vkDevice, &bufferCreateInfo, NULL, pVkBuffer));
    VkMemoryRequirements memoryRequirements;
    vkGetBufferMemoryRequirements(vkDevice, *pVkBuffer, &memoryRequirements);
    uint32_t memoryTypeIndex = getMemoryTypeIndex(vkPhysicalDevice, memoryRequirements.memoryTypeBits, memoryPropertyFlags);
    VkMemoryAllocateInfo memoryAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = NULL,
        .allocationSize = memoryRequirements.size,
        .memoryTypeIndex = memoryTypeIndex,
    };
    tknAssertVkResult(vkAllocateMemory(vkDevice, &memoryAllocateInfo, NULL, pVkDeviceMemory));
    tknAssertVkResult(vkBindBufferMemory(vkDevice, *pVkBuffer, *pVkDeviceMemory, 0));
}
void tknDestroyVkBuffer(TknGfxContext *pTknGfxContext, VkBuffer vkBuffer, VkDeviceMemory vkDeviceMemory)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroyBuffer(vkDevice, vkBuffer, NULL);
    vkFreeMemory(vkDevice, vkDeviceMemory, NULL);
}
TknVertexInputLayout *tknCreateVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, uint32_t tknAttributeCount, const char **names, uint32_t *sizes)
{
    TknVertexInputLayout *pTknVertexInputLayout = tknMalloc(sizeof(TknVertexInputLayout));
    const char **namesCopy = tknMalloc(sizeof(char *) * tknAttributeCount);
    // Deep copy the strings, not just the pointers
    for (uint32_t i = 0; i < tknAttributeCount; i++)
    {
        size_t nameLen = strlen(names[i]) + 1;
        char *nameCopy = tknMalloc(nameLen);
        memcpy(nameCopy, names[i], nameLen);
        namesCopy[i] = nameCopy;
    }
    uint32_t *sizesCopy = tknMalloc(sizeof(uint32_t) * tknAttributeCount);
    memcpy(sizesCopy, sizes, sizeof(uint32_t) * tknAttributeCount);
    uint32_t *offsets = tknMalloc(sizeof(uint32_t) * tknAttributeCount);
    uint32_t stride = 0;
    for (uint32_t i = 0; i < tknAttributeCount; i++)
    {
        offsets[i] = stride;
        stride += sizes[i];
    }
    *pTknVertexInputLayout = (TknVertexInputLayout){
        .tknAttributeCount = tknAttributeCount,
        .names = namesCopy,
        .sizes = sizesCopy,
        .offsets = offsets,
        .stride = stride,
        .tknReferencePtrHashSet = tknCreateHashSet(sizeof(void *)),
    };
    tknAddToHashSet(&pTknGfxContext->tknVertexInputLayoutPtrHashSet, &pTknVertexInputLayout);
    return pTknVertexInputLayout;
}
void tknDestroyVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout)
{
    tknAssert(0 == pTknVertexInputLayout->tknReferencePtrHashSet.count, "Cannot destroy vertex input layout with meshes | instance attached!");
    tknRemoveFromHashSet(&pTknGfxContext->tknVertexInputLayoutPtrHashSet, &pTknVertexInputLayout);
    tknDestroyHashSet(pTknVertexInputLayout->tknReferencePtrHashSet);

    // Free the deep-copied strings
    for (uint32_t i = 0; i < pTknVertexInputLayout->tknAttributeCount; i++)
    {
        tknFree((void *)pTknVertexInputLayout->names[i]);
    }
    tknFree(pTknVertexInputLayout->names);
    tknFree(pTknVertexInputLayout->sizes);
    tknFree(pTknVertexInputLayout->offsets);
    tknFree(pTknVertexInputLayout);
}

TknDescriptorSet *tknCreateDescriptorSetPtr(TknGfxContext *pTknGfxContext, uint32_t spvReflectShaderModuleCount, SpvReflectShaderModule *spvReflectShaderModules, uint32_t set)
{
    TknDescriptorSet *pTknDescriptorSet = tknMalloc(sizeof(TknDescriptorSet));

    TknHashSet tknMaterialPtrHashSet = tknCreateHashSet(sizeof(TknMaterial *));
    VkDescriptorSetLayout vkDescriptorSetLayout = VK_NULL_HANDLE;
    TknDynamicArray vkDescriptorPoolSizeDynamicArray = tknCreateDynamicArray(sizeof(VkDescriptorPoolSize), TKN_DEFAULT_COLLECTION_SIZE);
    uint32_t tknBindingCount = 0;
    VkDescriptorType *vkDescriptorTypes = NULL;

    for (uint32_t spvReflectShaderModuleIndex = 0; spvReflectShaderModuleIndex < spvReflectShaderModuleCount; spvReflectShaderModuleIndex++)
    {
        SpvReflectShaderModule spvReflectShaderModule = spvReflectShaderModules[spvReflectShaderModuleIndex];
        for (uint32_t setIndex = 0; setIndex < spvReflectShaderModule.descriptor_set_count; setIndex++)
        {
            SpvReflectDescriptorSet spvReflectDescriptorSet = spvReflectShaderModule.descriptor_sets[setIndex];
            if (set == spvReflectDescriptorSet.set)
            {
                for (uint32_t bindingIndex = 0; bindingIndex < spvReflectDescriptorSet.binding_count; bindingIndex++)
                {
                    SpvReflectDescriptorBinding *pSpvReflectDescriptorBinding = spvReflectDescriptorSet.bindings[bindingIndex];
                    if (pSpvReflectDescriptorBinding->binding < tknBindingCount)
                    {
                        // Skip, already counted
                    }
                    else
                    {
                        tknBindingCount = pSpvReflectDescriptorBinding->binding + 1;
                    }
                }
                // Skip other sets.
                break;
            }
            else
            {
                //  Skip
            }
        }
    }

    vkDescriptorTypes = tknMalloc(sizeof(VkDescriptorType) * tknBindingCount);
    VkDescriptorSetLayoutBinding *vkDescriptorSetLayoutBindings = tknMalloc(sizeof(VkDescriptorSetLayoutBinding) * tknBindingCount);
    for (uint32_t binding = 0; binding < tknBindingCount; binding++)
    {
        vkDescriptorTypes[binding] = VK_DESCRIPTOR_TYPE_MAX_ENUM;
        vkDescriptorSetLayoutBindings[binding] = (VkDescriptorSetLayoutBinding){
            .binding = 0,
            .descriptorType = VK_DESCRIPTOR_TYPE_MAX_ENUM,
            .descriptorCount = 0,
            .stageFlags = 0,
            .pImmutableSamplers = NULL,
        };
    }
    for (uint32_t moduleIndex = 0; moduleIndex < spvReflectShaderModuleCount; moduleIndex++)
    {
        SpvReflectShaderModule spvReflectShaderModule = spvReflectShaderModules[moduleIndex];
        for (uint32_t setIndex = 0; setIndex < spvReflectShaderModule.descriptor_set_count; setIndex++)
        {
            SpvReflectDescriptorSet spvReflectDescriptorSet = spvReflectShaderModule.descriptor_sets[setIndex];
            if (set == spvReflectDescriptorSet.set)
            {
                for (uint32_t bindingIndex = 0; bindingIndex < spvReflectDescriptorSet.binding_count; bindingIndex++)
                {
                    SpvReflectDescriptorBinding *pSpvReflectDescriptorBinding = spvReflectDescriptorSet.bindings[bindingIndex];
                    uint32_t binding = pSpvReflectDescriptorBinding->binding;
                    if (VK_DESCRIPTOR_TYPE_MAX_ENUM == vkDescriptorSetLayoutBindings[binding].descriptorType)
                    {
                        VkDescriptorType vkDescriptorType = (VkDescriptorType)pSpvReflectDescriptorBinding->descriptor_type;

                        VkDescriptorSetLayoutBinding vkDescriptorSetLayoutBinding = {
                            .binding = binding,
                            .descriptorType = vkDescriptorType,
                            .descriptorCount = pSpvReflectDescriptorBinding->count,
                            .stageFlags = (VkShaderStageFlags)spvReflectShaderModule.shader_stage,
                            .pImmutableSamplers = NULL,
                        };
                        vkDescriptorSetLayoutBindings[binding] = vkDescriptorSetLayoutBinding;
                        vkDescriptorTypes[binding] = vkDescriptorType;

                        uint32_t poolSizeIndex;
                        for (poolSizeIndex = 0; poolSizeIndex < vkDescriptorPoolSizeDynamicArray.count; poolSizeIndex++)
                        {
                            VkDescriptorPoolSize *pVkDescriptorPoolSize = tknGetFromDynamicArray(&vkDescriptorPoolSizeDynamicArray, poolSizeIndex);
                            if (vkDescriptorType == pVkDescriptorPoolSize->type)
                            {
                                pVkDescriptorPoolSize->descriptorCount += vkDescriptorSetLayoutBinding.descriptorCount;
                                break;
                            }
                            else
                            {
                                // Skip
                            }
                        }
                        if (poolSizeIndex < vkDescriptorPoolSizeDynamicArray.count)
                        {
                            // Pool size already exists, skip adding
                        }
                        else
                        {
                            VkDescriptorPoolSize vkDescriptorPoolSize = {
                                .type = vkDescriptorSetLayoutBinding.descriptorType,
                                .descriptorCount = vkDescriptorSetLayoutBinding.descriptorCount,
                            };
                            tknAddToDynamicArray(&vkDescriptorPoolSizeDynamicArray, &vkDescriptorPoolSize);
                        }
                    }
                    else
                    {
                        tknAssert(vkDescriptorSetLayoutBindings[binding].descriptorType == (VkDescriptorType)pSpvReflectDescriptorBinding->descriptor_type, "Incompatible descriptor binding");
                        vkDescriptorSetLayoutBindings[binding].stageFlags |= (VkShaderStageFlags)spvReflectShaderModule.shader_stage;
                        vkDescriptorSetLayoutBindings[binding].descriptorCount = pSpvReflectDescriptorBinding->count > vkDescriptorSetLayoutBindings[binding].descriptorCount ? pSpvReflectDescriptorBinding->count : vkDescriptorSetLayoutBindings[binding].descriptorCount;
                    }
                }
                // Skip other sets.
                break;
            }
            else
            {
                // Skip
            }
        }
    }

    VkDevice vkDevice = pTknGfxContext->vkDevice;
    VkDescriptorSetLayoutCreateInfo vkDescriptorSetLayoutCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = tknBindingCount,
        .pBindings = vkDescriptorSetLayoutBindings,
    };
    tknAssertVkResult(vkCreateDescriptorSetLayout(vkDevice, &vkDescriptorSetLayoutCreateInfo, NULL, &vkDescriptorSetLayout));
    tknFree(vkDescriptorSetLayoutBindings);

    *pTknDescriptorSet = (TknDescriptorSet){
        .vkDescriptorSetLayout = vkDescriptorSetLayout,
        .vkDescriptorPoolSizeDynamicArray = vkDescriptorPoolSizeDynamicArray,
        .tknDescriptorCount = tknBindingCount,
        .vkDescriptorTypes = vkDescriptorTypes,
        .tknMaterialPtrHashSet = tknMaterialPtrHashSet,
    };
    return pTknDescriptorSet;
}
void tknDestroyDescriptorSetPtr(TknGfxContext *pTknGfxContext, TknDescriptorSet *pTknDescriptorSet)
{
    // Safely destroy all materials by repeatedly taking the first one
    while (pTknDescriptorSet->tknMaterialPtrHashSet.count > 0)
    {
        TknMaterial *pTknMaterial = NULL;
        for (uint32_t nodeIndex = 0; nodeIndex < pTknDescriptorSet->tknMaterialPtrHashSet.capacity; nodeIndex++)
        {
            TknListNode *pNode = pTknDescriptorSet->tknMaterialPtrHashSet.nodePtrs[nodeIndex];
            if (pNode)
            {
                pTknMaterial = *(TknMaterial **)pNode->data;
                break;
            }
            else
            {
                // No node at this index
            }
        }
        if (pTknMaterial)
        {
            tknDestroyMaterialPtr(pTknGfxContext, pTknMaterial);
        }
        else
        {
            break; // Safety check to avoid infinite loop
        }
    }
    tknDestroyHashSet(pTknDescriptorSet->tknMaterialPtrHashSet);
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroyDescriptorSetLayout(vkDevice, pTknDescriptorSet->vkDescriptorSetLayout, NULL);
    tknDestroyDynamicArray(pTknDescriptorSet->vkDescriptorPoolSizeDynamicArray);
    tknFree(pTknDescriptorSet->vkDescriptorTypes);
    tknFree(pTknDescriptorSet);
}

VkFormat tknGetSupportedFormat(TknGfxContext *pTknGfxContext, uint32_t candidateCount, VkFormat *candidates, VkImageTiling tiling, VkFormatFeatureFlags features)
{
    for (uint32_t i = 0; i < candidateCount; i++)
    {
        VkFormat format = candidates[i];
        VkFormatProperties props;
        vkGetPhysicalDeviceFormatProperties(pTknGfxContext->vkPhysicalDevice, format, &props);
        if (VK_IMAGE_TILING_LINEAR == tiling)
        {
            if ((props.linearTilingFeatures & features) == features)
            {
                return format;
            }
            else
            {
                // Linear tiling features don't match
            }
        }
        else if (VK_IMAGE_TILING_OPTIMAL == tiling)
        {
            if ((props.optimalTilingFeatures & features) == features)
            {
                return format;
            }
            else
            {
                // Optimal tiling features don't match
            }
        }
        else
        {
            // Unknown tiling mode
        }
    }
    fprintf(stderr, "Error: No supported format found for the given requirements\n");
    return VK_FORMAT_MAX_ENUM;
}

VkCommandBuffer tknBeginSingleTimeCommands(TknGfxContext *pTknGfxContext)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;

    VkCommandBufferAllocateInfo vkCommandBufferAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = pTknGfxContext->vkGfxCommandPool,
        .commandBufferCount = 1};

    VkCommandBuffer vkCommandBuffer;
    tknAssertVkResult(vkAllocateCommandBuffers(vkDevice, &vkCommandBufferAllocateInfo, &vkCommandBuffer));

    VkCommandBufferBeginInfo vkCommandBufferBeginInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    tknAssertVkResult(vkBeginCommandBuffer(vkCommandBuffer, &vkCommandBufferBeginInfo));
    return vkCommandBuffer;
}

void tknEndSingleTimeCommands(TknGfxContext *pTknGfxContext, VkCommandBuffer vkCommandBuffer)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;

    tknAssertVkResult(vkEndCommandBuffer(vkCommandBuffer));

    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &vkCommandBuffer};
    
    tknAssertVkResult(vkQueueSubmit(pTknGfxContext->vkGfxQueue, 1, &submitInfo, VK_NULL_HANDLE));
    tknAssertVkResult(vkQueueWaitIdle(pTknGfxContext->vkGfxQueue));

    vkFreeCommandBuffers(vkDevice, pTknGfxContext->vkGfxCommandPool, 1, &vkCommandBuffer);
}