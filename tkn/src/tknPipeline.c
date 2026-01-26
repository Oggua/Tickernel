#include "tknGfxCore.h"
static uint32_t getSizeOfVkFormat(VkFormat format)
{
    switch (format)
    {
    case VK_FORMAT_UNDEFINED:
        return 0;
    case VK_FORMAT_R16_UINT:
    case VK_FORMAT_R16_SINT:
    case VK_FORMAT_R16_SFLOAT:
        return 2;
    case VK_FORMAT_R16G16_UINT:
    case VK_FORMAT_R16G16_SINT:
    case VK_FORMAT_R16G16_SFLOAT:
    case VK_FORMAT_R32_UINT:
    case VK_FORMAT_R32_SINT:
    case VK_FORMAT_R32_SFLOAT:
        return 4;
    case VK_FORMAT_R16G16B16_UINT:
    case VK_FORMAT_R16G16B16_SINT:
    case VK_FORMAT_R16G16B16_SFLOAT:
        return 6;
    case VK_FORMAT_R16G16B16A16_UINT:
    case VK_FORMAT_R16G16B16A16_SINT:
    case VK_FORMAT_R16G16B16A16_SFLOAT:
    case VK_FORMAT_R32G32_UINT:
    case VK_FORMAT_R32G32_SINT:
    case VK_FORMAT_R32G32_SFLOAT:
    case VK_FORMAT_R64_UINT:
    case VK_FORMAT_R64_SINT:
    case VK_FORMAT_R64_SFLOAT:
        return 8;
    case VK_FORMAT_R32G32B32_UINT:
    case VK_FORMAT_R32G32B32_SINT:
    case VK_FORMAT_R32G32B32_SFLOAT:
        return 12;
    case VK_FORMAT_R32G32B32A32_UINT:
    case VK_FORMAT_R32G32B32A32_SINT:
    case VK_FORMAT_R32G32B32A32_SFLOAT:
    case VK_FORMAT_R64G64_UINT:
    case VK_FORMAT_R64G64_SINT:
    case VK_FORMAT_R64G64_SFLOAT:
        return 16;
    case VK_FORMAT_R64G64B64_UINT:
    case VK_FORMAT_R64G64B64_SINT:
    case VK_FORMAT_R64G64B64_SFLOAT:
        return 24;
    case VK_FORMAT_R64G64B64A64_UINT:
    case VK_FORMAT_R64G64B64A64_SINT:
    case VK_FORMAT_R64G64B64A64_SFLOAT:
        return 32;
    default:
        tknError("getSizeOfVkFormat: unsupported VkFormat %d", format);
        return 0;
    }
}

static void updateVkVertexInputAttributeDescriptions(TknVertexInputLayout vertexInputLayout, uint32_t attributeIndex, SpvReflectInterfaceVariable spvReflectInterfaceVariable, uint32_t binding, VkVertexInputAttributeDescription *vkVertexInputAttributeDescriptions, uint32_t *pVkVertexInputAttributeDescriptionCount)
{
    SpvReflectTypeFlagBits typeFlags = spvReflectInterfaceVariable.type_description->type_flags;
    uint32_t location = spvReflectInterfaceVariable.location;
    VkFormat vkFormat = (VkFormat)spvReflectInterfaceVariable.format;
    if (typeFlags & SPV_REFLECT_TYPE_FLAG_ARRAY)
    {
        uint32_t itemCount = 1;
        for (uint32_t dimIndex = 0; dimIndex < spvReflectInterfaceVariable.array.dims_count; dimIndex++)
        {
            itemCount *= spvReflectInterfaceVariable.array.dims[dimIndex];
        }
        if (typeFlags & SPV_REFLECT_TYPE_FLAG_MATRIX)
        {
            uint32_t vectorCount = spvReflectInterfaceVariable.numeric.matrix.column_count * itemCount;
            for (uint32_t vectorIndex = 0; vectorIndex < vectorCount; vectorIndex++)
            {
                vkVertexInputAttributeDescriptions[*pVkVertexInputAttributeDescriptionCount] = (VkVertexInputAttributeDescription){
                    .location = location + vectorIndex,
                    .binding = binding,
                    .format = vkFormat,
                    .offset = vertexInputLayout.offsets[attributeIndex] + vectorIndex * getSizeOfVkFormat(vkFormat),
                };
                (*pVkVertexInputAttributeDescriptionCount)++;
            }
        }
        else
        {
            for (uint32_t itemIndex = 0; itemIndex < itemCount; itemIndex++)
            {
                vkVertexInputAttributeDescriptions[*pVkVertexInputAttributeDescriptionCount] = (VkVertexInputAttributeDescription){
                    .location = location + itemIndex,
                    .binding = binding,
                    .format = vkFormat,
                    .offset = vertexInputLayout.offsets[attributeIndex] + itemIndex * getSizeOfVkFormat(vkFormat),
                };
                (*pVkVertexInputAttributeDescriptionCount)++;
            }
        }
    }
    else
    {
        if (typeFlags & SPV_REFLECT_TYPE_FLAG_MATRIX)
        {
            uint32_t vectorCount = spvReflectInterfaceVariable.numeric.matrix.column_count;
            for (uint32_t vectorIndex = 0; vectorIndex < vectorCount; vectorIndex++)
            {
                vkVertexInputAttributeDescriptions[*pVkVertexInputAttributeDescriptionCount] = (VkVertexInputAttributeDescription){
                    .location = location + vectorIndex,
                    .binding = binding,
                    .format = vkFormat,
                    .offset = vertexInputLayout.offsets[attributeIndex] + vectorIndex * getSizeOfVkFormat(vkFormat),
                };
                (*pVkVertexInputAttributeDescriptionCount)++;
            }
        }
        else
        {
            vkVertexInputAttributeDescriptions[*pVkVertexInputAttributeDescriptionCount] = (VkVertexInputAttributeDescription){
                .location = location,
                .binding = binding,
                .format = vkFormat,
                .offset = vertexInputLayout.offsets[attributeIndex],
            };
            (*pVkVertexInputAttributeDescriptionCount)++;
        }
    }
}

TknPipeline *tknCreatePipelinePtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t spvPathCount, const char **spvPaths, TknVertexInputLayout *pTknMeshVertexInputLayout, TknVertexInputLayout *pTknInstanceVertexInputLayout, VkPipelineInputAssemblyStateCreateInfo vkPipelineInputAssemblyStateCreateInfo, VkPipelineViewportStateCreateInfo vkPipelineViewportStateCreateInfo, VkPipelineRasterizationStateCreateInfo vkPipelineRasterizationStateCreateInfo, VkPipelineMultisampleStateCreateInfo vkPipelineMultisampleStateCreateInfo, VkPipelineDepthStencilStateCreateInfo vkPipelineDepthStencilStateCreateInfo, VkPipelineColorBlendStateCreateInfo vkPipelineColorBlendStateCreateInfo, VkPipelineDynamicStateCreateInfo vkPipelineDynamicStateCreateInfo)
{
    TknPipeline *pTknPipeline = tknMalloc(sizeof(TknPipeline));
    SpvReflectShaderModule *spvReflectShaderModules = tknMalloc(sizeof(SpvReflectShaderModule) * spvPathCount);
    VkShaderStageFlagBits vkShaderStageFlagBits = 0;
    VkPipelineShaderStageCreateInfo *pipelineShaderStageCreateInfos = tknMalloc(sizeof(VkPipelineShaderStageCreateInfo) * spvPathCount);
    uint32_t vkVertexInputBindingDescriptionCount = 0;
    VkVertexInputBindingDescription *vkVertexInputBindingDescriptions = NULL;
    uint32_t vkVertexInputAttributeDescriptionCount = 0;
    VkVertexInputAttributeDescription *vkVertexInputAttributeDescriptions = NULL;
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        spvReflectShaderModules[spvPathIndex] = tknCreateSpvReflectShaderModule(spvPaths[spvPathIndex]);
        SpvReflectShaderModule spvReflectShaderModule = spvReflectShaderModules[spvPathIndex];

        if (VK_SHADER_STAGE_VERTEX_BIT == (VkShaderStageFlagBits)spvReflectShaderModule.shader_stage)
        {
            if (pTknMeshVertexInputLayout != NULL || pTknInstanceVertexInputLayout != NULL)
            {
                // Dynamically determine binding count based on what we actually have
                vkVertexInputBindingDescriptionCount = (pTknInstanceVertexInputLayout != NULL) ? 2 : 1;
                vkVertexInputBindingDescriptions = tknMalloc(sizeof(VkVertexInputBindingDescription) * vkVertexInputBindingDescriptionCount);
                // Always create vertex binding if mesh layout exists
                if (pTknMeshVertexInputLayout != NULL)
                {
                    vkVertexInputBindingDescriptions[TKN_VERTEX_BINDING_DESCRIPTION] = (VkVertexInputBindingDescription){
                        .binding = TKN_VERTEX_BINDING_DESCRIPTION,
                        .stride = pTknMeshVertexInputLayout->stride,
                        .inputRate = VK_VERTEX_INPUT_RATE_VERTEX,
                    };
                }

                // Only create instance binding if instance layout exists
                if (pTknInstanceVertexInputLayout != NULL)
                {
                    vkVertexInputBindingDescriptions[TKN_INSTANCE_BINDING_DESCRIPTION] = (VkVertexInputBindingDescription){
                        .binding = TKN_INSTANCE_BINDING_DESCRIPTION,
                        .stride = pTknInstanceVertexInputLayout->stride,
                        .inputRate = VK_VERTEX_INPUT_RATE_INSTANCE,
                    };
                }
                vkVertexInputAttributeDescriptions = tknMalloc(sizeof(VkVertexInputAttributeDescription) * pTknGfxContext->vkPhysicalDeviceProperties.limits.maxVertexInputAttributes);
                for (uint32_t inputVariableIndex = 0; inputVariableIndex < spvReflectShaderModule.input_variable_count; inputVariableIndex++)
                {
                    SpvReflectInterfaceVariable *pSpvReflectInterfaceVariable = spvReflectShaderModule.input_variables[inputVariableIndex];

                    uint32_t attributeIndex;
                    bool found = false;

                    // Search in mesh vertex input layout first
                    if (pTknMeshVertexInputLayout != NULL)
                    {
                        for (attributeIndex = 0; attributeIndex < pTknMeshVertexInputLayout->tknAttributeCount; attributeIndex++)
                        {
                            if (0 == strcmp(pSpvReflectInterfaceVariable->name, pTknMeshVertexInputLayout->names[attributeIndex]))
                            {
                                updateVkVertexInputAttributeDescriptions(*pTknMeshVertexInputLayout, attributeIndex, *pSpvReflectInterfaceVariable, TKN_VERTEX_BINDING_DESCRIPTION, vkVertexInputAttributeDescriptions, &vkVertexInputAttributeDescriptionCount);
                                found = true;
                                break;
                            }
                        }
                    }

                    // If not found in mesh layout, search in instance layout
                    if (!found && pTknInstanceVertexInputLayout != NULL)
                    {
                        for (attributeIndex = 0; attributeIndex < pTknInstanceVertexInputLayout->tknAttributeCount; attributeIndex++)
                        {
                            if (0 == strcmp(pSpvReflectInterfaceVariable->name, pTknInstanceVertexInputLayout->names[attributeIndex]))
                            {
                                updateVkVertexInputAttributeDescriptions(*pTknInstanceVertexInputLayout, attributeIndex, *pSpvReflectInterfaceVariable, TKN_INSTANCE_BINDING_DESCRIPTION, vkVertexInputAttributeDescriptions, &vkVertexInputAttributeDescriptionCount);
                                found = true;
                                break;
                            }
                        }
                    }

                    tknAssert(found, "Attribute '%s' not found in any vertex input layout", pSpvReflectInterfaceVariable->name);
                }
            }
            else
            {
                // Skip
            }
        }

        if ((vkShaderStageFlagBits & spvReflectShaderModule.shader_stage) != 0)
        {
            tknError("Duplicate shader stage: %d", spvReflectShaderModule.shader_stage);
        }
        else
        {
            vkShaderStageFlagBits |= spvReflectShaderModule.shader_stage;
            VkShaderModuleCreateInfo vkShaderModuleCreateInfo = {
                .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .pNext = NULL,
                .flags = 0,
                .codeSize = spvReflectGetCodeSize(&spvReflectShaderModule),
                .pCode = spvReflectGetCode(&spvReflectShaderModule),
            };
            VkShaderModule shaderModule;
            tknAssertVkResult(vkCreateShaderModule(vkDevice, &vkShaderModuleCreateInfo, NULL, &shaderModule));
            pipelineShaderStageCreateInfos[spvPathIndex] = (VkPipelineShaderStageCreateInfo){
                .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .pNext = NULL,
                .flags = 0,
                .stage = (VkShaderStageFlagBits)spvReflectShaderModule.shader_stage,
                .module = shaderModule,
                .pName = spvReflectShaderModule.entry_point_name,
                .pSpecializationInfo = NULL,
            };
        }
    }
    TknDescriptorSet *pTknPipelineDescriptorSet = tknCreateDescriptorSetPtr(pTknGfxContext, spvPathCount, spvReflectShaderModules, TKN_PIPELINE_DESCRIPTOR_SET);

    VkPipelineVertexInputStateCreateInfo vkPipelineVertexInputStateCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .vertexBindingDescriptionCount = vkVertexInputBindingDescriptionCount,
        .pVertexBindingDescriptions = vkVertexInputBindingDescriptions,
        .vertexAttributeDescriptionCount = vkVertexInputAttributeDescriptionCount,
        .pVertexAttributeDescriptions = vkVertexInputAttributeDescriptions,
    };
    VkPipelineLayout vkPipelineLayout;
    VkDescriptorSetLayout *vkDescriptorSetLayouts = tknMalloc(sizeof(VkDescriptorSetLayout) * TKN_MAX_DESCRIPTOR_SET);
    vkDescriptorSetLayouts[TKN_GLOBAL_DESCRIPTOR_SET] = pTknGfxContext->pTknGlobalDescriptorSet->vkDescriptorSetLayout;
    vkDescriptorSetLayouts[TKN_SUBPASS_DESCRIPTOR_SET] = pTknRenderPass->pTknSubpasses[subpassIndex].pTknSubpassDescriptorSet->vkDescriptorSetLayout;
    vkDescriptorSetLayouts[TKN_PIPELINE_DESCRIPTOR_SET] = pTknPipelineDescriptorSet->vkDescriptorSetLayout;
    VkPipelineLayoutCreateInfo vkPipelineLayoutCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .setLayoutCount = TKN_MAX_DESCRIPTOR_SET,
        .pSetLayouts = vkDescriptorSetLayouts,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = NULL,
    };
    tknAssertVkResult(vkCreatePipelineLayout(vkDevice, &vkPipelineLayoutCreateInfo, NULL, &vkPipelineLayout));
    VkPipeline vkPipeline = VK_NULL_HANDLE;
    VkGraphicsPipelineCreateInfo vkGraphicsPipelineCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .stageCount = spvPathCount,
        .pStages = pipelineShaderStageCreateInfos,
        .pVertexInputState = &vkPipelineVertexInputStateCreateInfo,
        .pInputAssemblyState = &vkPipelineInputAssemblyStateCreateInfo,
        .pTessellationState = NULL,
        .pViewportState = &vkPipelineViewportStateCreateInfo,
        .pRasterizationState = &vkPipelineRasterizationStateCreateInfo,
        .pMultisampleState = &vkPipelineMultisampleStateCreateInfo,
        .pDepthStencilState = &vkPipelineDepthStencilStateCreateInfo,
        .pColorBlendState = &vkPipelineColorBlendStateCreateInfo,
        .pDynamicState = &vkPipelineDynamicStateCreateInfo,
        .layout = vkPipelineLayout,
        .renderPass = pTknRenderPass->vkRenderPass,
        .subpass = subpassIndex,
        .basePipelineHandle = VK_NULL_HANDLE,
        .basePipelineIndex = 0,
    };
    tknAssertVkResult(vkCreateGraphicsPipelines(vkDevice, NULL, 1, &vkGraphicsPipelineCreateInfo, NULL, &vkPipeline));
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        tknDestroySpvReflectShaderModule(&spvReflectShaderModules[spvPathIndex]);
    }
    tknFree(spvReflectShaderModules);
    tknFree(vkVertexInputBindingDescriptions);
    tknFree(vkVertexInputAttributeDescriptions);
    for (uint32_t pipelineShaderStageCreateInfoIndex = 0; pipelineShaderStageCreateInfoIndex < spvPathCount; pipelineShaderStageCreateInfoIndex++)
    {
        vkDestroyShaderModule(vkDevice, pipelineShaderStageCreateInfos[pipelineShaderStageCreateInfoIndex].module, NULL);
    }
    tknFree(vkDescriptorSetLayouts);
    tknFree(pipelineShaderStageCreateInfos);
    TknHashSet tknDrawCallPtrHashSet = tknCreateHashSet(sizeof(TknDrawCall *));
    *pTknPipeline = (TknPipeline){
        .pTknPipelineDescriptorSet = pTknPipelineDescriptorSet,
        .vkPipeline = vkPipeline,
        .vkPipelineLayout = vkPipelineLayout,
        .pTknRenderPass = pTknRenderPass,
        .subpassIndex = subpassIndex,
        .pTknMeshVertexInputLayout = pTknMeshVertexInputLayout,
        .pTknInstanceVertexInputLayout = pTknInstanceVertexInputLayout,
        .tknDrawCallPtrHashSet = tknDrawCallPtrHashSet,
    };
    tknAddToHashSet(&pTknRenderPass->pTknSubpasses[subpassIndex].tknPipelinePtrHashSet, &pTknPipeline);
    if (NULL != pTknMeshVertexInputLayout)
        tknAddToHashSet(&pTknMeshVertexInputLayout->tknReferencePtrHashSet, &pTknPipeline);
    if (NULL != pTknInstanceVertexInputLayout)
        tknAddToHashSet(&pTknInstanceVertexInputLayout->tknReferencePtrHashSet, &pTknPipeline);

    return pTknPipeline;
}
void tknDestroyPipelinePtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline)
{
    for (size_t i = 0; i < pTknPipeline->tknDrawCallPtrHashSet.capacity; i++)
    {
        TknListNode *node = pTknPipeline->tknDrawCallPtrHashSet.nodePtrs[i];
        while (node)
        {
            TknListNode *nextNode = node->pNextNode;
            TknDrawCall *pTknDrawCall = *(TknDrawCall **)node->data;
            tknDestroyDrawCallPtr(pTknGfxContext, pTknDrawCall);
            node = nextNode;
        }
        pTknPipeline->tknDrawCallPtrHashSet.nodePtrs[i] = NULL;
    }
    pTknPipeline->tknDrawCallPtrHashSet.count = 0;

    VkDevice vkDevice = pTknGfxContext->vkDevice;
    tknRemoveFromHashSet(&pTknPipeline->pTknRenderPass->pTknSubpasses[pTknPipeline->subpassIndex].tknPipelinePtrHashSet, &pTknPipeline);
    if (pTknPipeline->pTknMeshVertexInputLayout != NULL)
        tknRemoveFromHashSet(&pTknPipeline->pTknMeshVertexInputLayout->tknReferencePtrHashSet, &pTknPipeline);

    if (pTknPipeline->pTknInstanceVertexInputLayout != NULL)
        tknRemoveFromHashSet(&pTknPipeline->pTknInstanceVertexInputLayout->tknReferencePtrHashSet, &pTknPipeline);

    tknDestroyHashSet(pTknPipeline->tknDrawCallPtrHashSet);
    tknDestroyDescriptorSetPtr(pTknGfxContext, pTknPipeline->pTknPipelineDescriptorSet);
    vkDestroyPipeline(vkDevice, pTknPipeline->vkPipeline, NULL);
    vkDestroyPipelineLayout(vkDevice, pTknPipeline->vkPipelineLayout, NULL);
    tknFree(pTknPipeline);
}
