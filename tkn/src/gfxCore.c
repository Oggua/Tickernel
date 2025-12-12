#include "gfxCore.h"

void assertVkResult(VkResult vkResult)
{
    tknAssert(vkResult == VK_SUCCESS, "Vulkan error: %d", vkResult);
}

SpvReflectShaderModule createSpvReflectShaderModule(const char *filePath)
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
void destroySpvReflectShaderModule(SpvReflectShaderModule *pSpvReflectShaderModule)
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

void clearBindingPtrHashSet(TknGfxContext *pTknGfxContext, TknHashSet bindingPtrHashSet)
{
    for (uint32_t i = 0; i < bindingPtrHashSet.capacity; i++)
    {
        TknListNode *node = bindingPtrHashSet.nodePtrs[i];
        while (node)
        {
            Binding *pBinding = *(Binding **)node->data;
            node = node->pNextNode;
            TknInputBinding tknInputBinding = {
                .vkDescriptorType = pBinding->vkDescriptorType,
                .tknInputBindingUnion = getEmptyInputBindingUnion(pTknGfxContext, pBinding->vkDescriptorType),
                .binding = pBinding->binding,
            };
            updateMaterialPtr(pTknGfxContext, pBinding->pTknMaterial, 1, &tknInputBinding);
        }
    }
}

void createVkImage(TknGfxContext *pTknGfxContext, VkExtent3D vkExtent3D, VkFormat vkFormat, VkImageTiling vkImageTiling, VkImageUsageFlags vkImageUsageFlags, VkMemoryPropertyFlags vkMemoryPropertyFlags, VkImageAspectFlags vkImageAspectFlags, VkImage *pVkImage, VkDeviceMemory *pVkDeviceMemory, VkImageView *pVkImageView)
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
    assertVkResult(vkCreateImage(vkDevice, &imageCreateInfo, NULL, pVkImage));
    VkMemoryRequirements memoryRequirements;
    vkGetImageMemoryRequirements(vkDevice, *pVkImage, &memoryRequirements);
    uint32_t memoryTypeIndex = getMemoryTypeIndex(vkPhysicalDevice, memoryRequirements.memoryTypeBits, vkMemoryPropertyFlags);
    VkMemoryAllocateInfo memoryAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = NULL,
        .allocationSize = memoryRequirements.size,
        .memoryTypeIndex = memoryTypeIndex,
    };
    assertVkResult(vkAllocateMemory(vkDevice, &memoryAllocateInfo, NULL, pVkDeviceMemory));
    assertVkResult(vkBindImageMemory(vkDevice, *pVkImage, *pVkDeviceMemory, 0));

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
    assertVkResult(vkCreateImageView(vkDevice, &imageViewCreateInfo, NULL, pVkImageView));
}
void destroyVkImage(TknGfxContext *pTknGfxContext, VkImage vkImage, VkDeviceMemory vkDeviceMemory, VkImageView vkImageView)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroyImageView(vkDevice, vkImageView, NULL);
    vkDestroyImage(vkDevice, vkImage, NULL);
    vkFreeMemory(vkDevice, vkDeviceMemory, NULL);
}

void createVkBuffer(TknGfxContext *pTknGfxContext, VkDeviceSize bufferSize, VkBufferUsageFlags bufferUsageFlags, VkMemoryPropertyFlags memoryPropertyFlags, VkBuffer *pVkBuffer, VkDeviceMemory *pVkDeviceMemory)
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
    assertVkResult(vkCreateBuffer(vkDevice, &bufferCreateInfo, NULL, pVkBuffer));
    VkMemoryRequirements memoryRequirements;
    vkGetBufferMemoryRequirements(vkDevice, *pVkBuffer, &memoryRequirements);
    uint32_t memoryTypeIndex = getMemoryTypeIndex(vkPhysicalDevice, memoryRequirements.memoryTypeBits, memoryPropertyFlags);
    VkMemoryAllocateInfo memoryAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = NULL,
        .allocationSize = memoryRequirements.size,
        .memoryTypeIndex = memoryTypeIndex,
    };
    assertVkResult(vkAllocateMemory(vkDevice, &memoryAllocateInfo, NULL, pVkDeviceMemory));
    assertVkResult(vkBindBufferMemory(vkDevice, *pVkBuffer, *pVkDeviceMemory, 0));
}
void destroyVkBuffer(TknGfxContext *pTknGfxContext, VkBuffer vkBuffer, VkDeviceMemory vkDeviceMemory)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroyBuffer(vkDevice, vkBuffer, NULL);
    vkFreeMemory(vkDevice, vkDeviceMemory, NULL);
}
TknVertexInputLayout *createVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, uint32_t attributeCount, const char **names, uint32_t *sizes)
{
    TknVertexInputLayout *pTknVertexInputLayout = tknMalloc(sizeof(TknVertexInputLayout));
    const char **namesCopy = tknMalloc(sizeof(char *) * attributeCount);
    // Deep copy the strings, not just the pointers
    for (uint32_t i = 0; i < attributeCount; i++)
    {
        size_t nameLen = strlen(names[i]) + 1;
        char *nameCopy = tknMalloc(nameLen);
        memcpy(nameCopy, names[i], nameLen);
        namesCopy[i] = nameCopy;
    }
    uint32_t *sizesCopy = tknMalloc(sizeof(uint32_t) * attributeCount);
    memcpy(sizesCopy, sizes, sizeof(uint32_t) * attributeCount);
    uint32_t *offsets = tknMalloc(sizeof(uint32_t) * attributeCount);
    uint32_t stride = 0;
    for (uint32_t i = 0; i < attributeCount; i++)
    {
        offsets[i] = stride;
        stride += sizes[i];
    }
    *pTknVertexInputLayout = (TknVertexInputLayout){
        .attributeCount = attributeCount,
        .names = namesCopy,
        .sizes = sizesCopy,
        .offsets = offsets,
        .stride = stride,
        .referencePtrHashSet = tknCreateHashSet(sizeof(void *)),
    };
    tknAddToHashSet(&pTknGfxContext->vertexInputLayoutPtrHashSet, &pTknVertexInputLayout);
    return pTknVertexInputLayout;
}
void destroyVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout)
{
    tknAssert(0 == pTknVertexInputLayout->referencePtrHashSet.count, "Cannot destroy vertex input layout with meshes | instance attached!");
    tknRemoveFromHashSet(&pTknGfxContext->vertexInputLayoutPtrHashSet, &pTknVertexInputLayout);
    tknDestroyHashSet(pTknVertexInputLayout->referencePtrHashSet);

    // Free the deep-copied strings
    for (uint32_t i = 0; i < pTknVertexInputLayout->attributeCount; i++)
    {
        tknFree((void *)pTknVertexInputLayout->names[i]);
    }
    tknFree(pTknVertexInputLayout->names);
    tknFree(pTknVertexInputLayout->sizes);
    tknFree(pTknVertexInputLayout->offsets);
    tknFree(pTknVertexInputLayout);
}

DescriptorSet *createDescriptorSetPtr(TknGfxContext *pTknGfxContext, uint32_t spvReflectShaderModuleCount, SpvReflectShaderModule *spvReflectShaderModules, uint32_t set)
{
    DescriptorSet *pDescriptorSet = tknMalloc(sizeof(DescriptorSet));

    TknHashSet materialPtrHashSet = tknCreateHashSet(sizeof(TknMaterial *));
    VkDescriptorSetLayout vkDescriptorSetLayout = VK_NULL_HANDLE;
    TknDynamicArray vkDescriptorPoolSizeDynamicArray = tknCreateDynamicArray(sizeof(VkDescriptorPoolSize), TKN_DEFAULT_COLLECTION_SIZE);
    uint32_t bindingCount = 0;
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
                    if (pSpvReflectDescriptorBinding->binding < bindingCount)
                    {
                        // Skip, already counted
                    }
                    else
                    {
                        bindingCount = pSpvReflectDescriptorBinding->binding + 1;
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

    vkDescriptorTypes = tknMalloc(sizeof(VkDescriptorType) * bindingCount);
    VkDescriptorSetLayoutBinding *vkDescriptorSetLayoutBindings = tknMalloc(sizeof(VkDescriptorSetLayoutBinding) * bindingCount);
    for (uint32_t binding = 0; binding < bindingCount; binding++)
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
        .bindingCount = bindingCount,
        .pBindings = vkDescriptorSetLayoutBindings,
    };
    assertVkResult(vkCreateDescriptorSetLayout(vkDevice, &vkDescriptorSetLayoutCreateInfo, NULL, &vkDescriptorSetLayout));
    tknFree(vkDescriptorSetLayoutBindings);

    *pDescriptorSet = (DescriptorSet){
        .vkDescriptorSetLayout = vkDescriptorSetLayout,
        .vkDescriptorPoolSizeDynamicArray = vkDescriptorPoolSizeDynamicArray,
        .descriptorCount = bindingCount,
        .vkDescriptorTypes = vkDescriptorTypes,
        .materialPtrHashSet = materialPtrHashSet,
    };
    return pDescriptorSet;
}
void destroyDescriptorSetPtr(TknGfxContext *pTknGfxContext, DescriptorSet *pDescriptorSet)
{
    // Safely destroy all materials by repeatedly taking the first one
    while (pDescriptorSet->materialPtrHashSet.count > 0)
    {
        TknMaterial *pTknMaterial = NULL;
        for (uint32_t nodeIndex = 0; nodeIndex < pDescriptorSet->materialPtrHashSet.capacity; nodeIndex++)
        {
            TknListNode *pNode = pDescriptorSet->materialPtrHashSet.nodePtrs[nodeIndex];
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
            destroyMaterialPtr(pTknGfxContext, pTknMaterial);
        }
        else
        {
            break; // Safety check to avoid infinite loop
        }
    }
    tknDestroyHashSet(pDescriptorSet->materialPtrHashSet);
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkDestroyDescriptorSetLayout(vkDevice, pDescriptorSet->vkDescriptorSetLayout, NULL);
    tknDestroyDynamicArray(pDescriptorSet->vkDescriptorPoolSizeDynamicArray);
    tknFree(pDescriptorSet->vkDescriptorTypes);
    tknFree(pDescriptorSet);
}

VkFormat getSupportedFormat(TknGfxContext *pTknGfxContext, uint32_t candidateCount, VkFormat *candidates, VkImageTiling tiling, VkFormatFeatureFlags features)
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

VkCommandBuffer beginSingleTimeCommands(TknGfxContext *pTknGfxContext)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;

    VkCommandBufferAllocateInfo vkCommandBufferAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = pTknGfxContext->gfxVkCommandPool,
        .commandBufferCount = 1};

    VkCommandBuffer vkCommandBuffer;
    assertVkResult(vkAllocateCommandBuffers(vkDevice, &vkCommandBufferAllocateInfo, &vkCommandBuffer));

    VkCommandBufferBeginInfo vkCommandBufferBeginInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    assertVkResult(vkBeginCommandBuffer(vkCommandBuffer, &vkCommandBufferBeginInfo));
    return vkCommandBuffer;
}

void endSingleTimeCommands(TknGfxContext *pTknGfxContext, VkCommandBuffer vkCommandBuffer)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;

    assertVkResult(vkEndCommandBuffer(vkCommandBuffer));

    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &vkCommandBuffer};

    assertVkResult(vkQueueSubmit(pTknGfxContext->vkGfxQueue, 1, &submitInfo, VK_NULL_HANDLE));
    assertVkResult(vkQueueWaitIdle(pTknGfxContext->vkGfxQueue));

    vkFreeCommandBuffers(vkDevice, pTknGfxContext->gfxVkCommandPool, 1, &vkCommandBuffer);
}