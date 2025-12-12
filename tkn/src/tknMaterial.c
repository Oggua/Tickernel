#include "tknGfxCore.h"
TknMaterial *tknCreateMaterialPtr(TknGfxContext *pTknGfxContext, TknDescriptorSet *pTknDescriptorSet)
{
    TknMaterial *pTknMaterial = tknMalloc(sizeof(TknMaterial));
    VkDescriptorSet vkDescriptorSet = VK_NULL_HANDLE;
    uint32_t tknDescriptorCount = pTknDescriptorSet->tknDescriptorCount;
    TknBinding *bindings = tknMalloc(sizeof(TknBinding) * tknDescriptorCount);
    VkDescriptorPool vkDescriptorPool = VK_NULL_HANDLE;

    for (uint32_t descriptorIndex = 0; descriptorIndex < tknDescriptorCount; descriptorIndex++)
    {
        VkDescriptorType vkDescriptorType = pTknDescriptorSet->vkDescriptorTypes[descriptorIndex];
        
        // Initialize binding with explicit zero values
        bindings[descriptorIndex].vkDescriptorType = vkDescriptorType;
        bindings[descriptorIndex].pTknMaterial = pTknMaterial;
        bindings[descriptorIndex].binding = descriptorIndex;
        // Explicitly zero out the entire binding union
        memset(&bindings[descriptorIndex].tknBindingUnion, 0, sizeof(bindings[descriptorIndex].tknBindingUnion));
    }
    VkDescriptorPoolCreateInfo vkDescriptorPoolCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = pTknDescriptorSet->vkDescriptorPoolSizeDynamicArray.count,
        .pPoolSizes = pTknDescriptorSet->vkDescriptorPoolSizeDynamicArray.array,
        .maxSets = 1,
    };
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    tknAssertVkResult(vkCreateDescriptorPool(vkDevice, &vkDescriptorPoolCreateInfo, NULL, &vkDescriptorPool));

    VkDescriptorSetAllocateInfo vkDescriptorSetAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = vkDescriptorPool,
        .descriptorSetCount = 1,
        .pSetLayouts = &pTknDescriptorSet->vkDescriptorSetLayout,
    };

    tknAssertVkResult(vkAllocateDescriptorSets(vkDevice, &vkDescriptorSetAllocateInfo, &vkDescriptorSet));
    TknHashSet tknDrawCallPtrHashSet = tknCreateHashSet(sizeof(TknDrawCall *));
    *pTknMaterial = (TknMaterial){
        .vkDescriptorSet = vkDescriptorSet,
        .tknBindingCount = tknDescriptorCount,
        .pTknBindings = bindings,
        .vkDescriptorPool = vkDescriptorPool,
        .pTknDescriptorSet = pTknDescriptorSet,
        .tknDrawCallPtrHashSet = tknDrawCallPtrHashSet,
    };
    tknAddToHashSet(&pTknDescriptorSet->tknMaterialPtrHashSet, &pTknMaterial);
    
    // Initialize all bindings with empty resources using tknUpdateMaterialPtr
    uint32_t inputBindingCount = 0;
    TknInputBinding *tknInputBindings = tknMalloc(sizeof(TknInputBinding) * tknDescriptorCount);
    
    for (uint32_t i = 0; i < tknDescriptorCount; i++)
    {
        VkDescriptorType vkDescriptorType = bindings[i].vkDescriptorType;
        if (vkDescriptorType != VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
        {
            // Get empty binding for this descriptor type
            TknInputBindingUnion tknInputBindingUnion = tknGetEmptyInputBindingUnion(pTknGfxContext, vkDescriptorType);
            
            tknInputBindings[inputBindingCount] = (TknInputBinding){
                .binding = i,
                .vkDescriptorType = vkDescriptorType,
                .tknInputBindingUnion = tknInputBindingUnion,
            };
            inputBindingCount++;
        }
    }
    
    if (inputBindingCount > 0)
    {
        tknUpdateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindingCount, tknInputBindings);
    }
    tknFree(tknInputBindings);
    
    return pTknMaterial;
}

void tknDestroyMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    tknAssert(0 == pTknMaterial->tknDrawCallPtrHashSet.count, "TknMaterial still has draw calls attached!");
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    uint32_t inputBindingCount = 0;
    TknInputBinding *tknInputBindings = tknMalloc(sizeof(TknInputBinding) * pTknMaterial->tknBindingCount);
    for (uint32_t binding = 0; binding < pTknMaterial->tknBindingCount; binding++)
    {
        TknBinding *pTknBinding = &pTknMaterial->pTknBindings[binding];
        VkDescriptorType vkDescriptorType = pTknBinding->vkDescriptorType;
        if (vkDescriptorType != VK_DESCRIPTOR_TYPE_MAX_ENUM && vkDescriptorType != VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
        {
            if (VK_DESCRIPTOR_TYPE_SAMPLER == vkDescriptorType)
            {
                TknSampler *pTknSampler = pTknBinding->tknBindingUnion.tknSamplerBinding.pTknSampler;
                if (NULL == pTknSampler)
                {
                    // Nothing
                }
                else
                {
                    // Current sampler deref descriptor
                    tknRemoveFromHashSet(&pTknSampler->tknBindingPtrHashSet, &pTknBinding);
                }
            }
            else if (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER == vkDescriptorType)
            {
                TknSampler *pTknSampler = pTknBinding->tknBindingUnion.tknCombinedImageSamplerBinding.pTknSampler;
                TknImage *pTknImage = pTknBinding->tknBindingUnion.tknCombinedImageSamplerBinding.pTknImage;
                if (NULL == pTknSampler && NULL == pTknImage)
                {
                    // Nothing
                }
                else
                {
                    // Current sampler deref descriptor
                    tknRemoveFromHashSet(&pTknSampler->tknBindingPtrHashSet, &pTknBinding);
                    tknRemoveFromHashSet(&pTknImage->tknBindingPtrHashSet, &pTknBinding);
                }
            }
            else if (VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE == vkDescriptorType)
            {
                tknError("Sampled image not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_IMAGE == vkDescriptorType)
            {
                tknError("Storage image not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER == vkDescriptorType)
            {
                tknError("Uniform texel buffer not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER == vkDescriptorType)
            {
                tknError("Storage texel buffer not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER == vkDescriptorType)
            {
                TknUniformBuffer *pTknUniformBuffer = pTknBinding->tknBindingUnion.tknUniformBufferBinding.pTknUniformBuffer;
                if (NULL == pTknUniformBuffer)
                {
                    // Nothing
                }
                else
                {
                    // Current uniform buffer deref descriptor
                    tknRemoveFromHashSet(&pTknUniformBuffer->tknBindingPtrHashSet, &pTknBinding);
                }
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_BUFFER == vkDescriptorType)
            {
                tknError("Storage buffer not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC == vkDescriptorType)
            {
                tknError("Uniform buffer dynamic not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC == vkDescriptorType)
            {
                tknError("Storage buffer dynamic not yet implemented");
            }
            else
            {
                tknError("Unsupported descriptor type: %d", vkDescriptorType);
            }
        }
        else if (VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT == vkDescriptorType)
        {
            tknAssert(pTknBinding->tknBindingUnion.tknInputAttachmentBinding.pTknAttachment == NULL, "Input attachment bindings must be unbound before destroying a material");
        }
        else
        {
            // Skip
        }
    }
    if (inputBindingCount > 0)
    {
        tknUpdateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindingCount, tknInputBindings);
    }
    tknFree(tknInputBindings);

    tknRemoveFromHashSet(&pTknMaterial->pTknDescriptorSet->tknMaterialPtrHashSet, &pTknMaterial);
    tknDestroyHashSet(pTknMaterial->tknDrawCallPtrHashSet);
    // Destroying the descriptor pool automatically frees all descriptor sets allocated from it
    vkDestroyDescriptorPool(vkDevice, pTknMaterial->vkDescriptorPool, NULL);
    tknFree(pTknMaterial->pTknBindings);
    tknFree(pTknMaterial);
}

void tknBindAttachmentsToMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    uint32_t vkWriteDescriptorSetCount = 0;
    for (uint32_t binding = 0; binding < pTknMaterial->tknBindingCount; binding++)
    {
        TknBinding *pTknBinding = &pTknMaterial->pTknBindings[binding];
        if (pTknBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
        {
            vkWriteDescriptorSetCount++;
        }
        else
        {
            // Skip
        }
    }
    if (vkWriteDescriptorSetCount > 0)
    {
        uint32_t vkWriteDescriptorSetIndex = 0;
        VkWriteDescriptorSet *vkWriteDescriptorSets = tknMalloc(sizeof(VkWriteDescriptorSet) * vkWriteDescriptorSetCount);
        VkDescriptorImageInfo *vkDescriptorImageInfos = tknMalloc(sizeof(VkDescriptorImageInfo) * vkWriteDescriptorSetCount);
        VkDescriptorType vkDescriptorType = VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT;
        for (uint32_t binding = 0; binding < pTknMaterial->tknBindingCount; binding++)
        {
            TknBinding *pTknBinding = &pTknMaterial->pTknBindings[binding];
            if (pTknBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
            {
                TknAttachment *pInputAttachment = pTknBinding->tknBindingUnion.tknInputAttachmentBinding.pTknAttachment;
                tknAssert(pInputAttachment != NULL, "TknBinding %d is not bound to an attachment", binding);
                VkImageView vkImageView = VK_NULL_HANDLE;
                if (TKN_ATTACHMENT_TYPE_DYNAMIC == pInputAttachment->tknAttachmentType)
                {
                    vkImageView = pInputAttachment->tknAttachmentUnion.tknDynamicAttachment.vkImageView;
                    tknAddToHashSet(&pInputAttachment->tknAttachmentUnion.tknDynamicAttachment.tknBindingPtrHashSet, &pTknBinding);
                }
                else if (TKN_ATTACHMENT_TYPE_FIXED == pInputAttachment->tknAttachmentType)
                {
                    vkImageView = pInputAttachment->tknAttachmentUnion.tknFixedAttachment.vkImageView;
                    tknAddToHashSet(&pInputAttachment->tknAttachmentUnion.tknFixedAttachment.tknBindingPtrHashSet, &pTknBinding);
                }
                else
                {
                    tknError("Swapchain attachment cannot be used as input attachment (attachment type: %d)", pInputAttachment->tknAttachmentType);
                }

                vkDescriptorImageInfos[vkWriteDescriptorSetIndex] = (VkDescriptorImageInfo){
                    .sampler = VK_NULL_HANDLE,
                    .imageView = vkImageView,
                    .imageLayout = pTknBinding->tknBindingUnion.tknInputAttachmentBinding.vkImageLayout,
                };

                vkWriteDescriptorSets[vkWriteDescriptorSetIndex] = (VkWriteDescriptorSet){
                    .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                    .dstSet = pTknMaterial->vkDescriptorSet,
                    .dstBinding = binding,
                    .dstArrayElement = 0,
                    .descriptorCount = 1,
                    .descriptorType = vkDescriptorType,
                    .pImageInfo = &vkDescriptorImageInfos[vkWriteDescriptorSetIndex],
                    .pBufferInfo = VK_NULL_HANDLE,
                    .pTexelBufferView = VK_NULL_HANDLE,
                };
                vkWriteDescriptorSetIndex++;
            }
            else
            {
                // Skip
            }
        }
        VkDevice vkDevice = pTknGfxContext->vkDevice;
        vkUpdateDescriptorSets(vkDevice, vkWriteDescriptorSetCount, vkWriteDescriptorSets, 0, NULL);
        tknFree(vkDescriptorImageInfos);
        tknFree(vkWriteDescriptorSets);
    }
    else
    {
        return;
    }
}
void tknUnbindAttachmentsFromMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    uint32_t vkWriteDescriptorSetCount = 0;
    for (uint32_t binding = 0; binding < pTknMaterial->tknBindingCount; binding++)
    {
        TknBinding *pTknBinding = &pTknMaterial->pTknBindings[binding];
        if (pTknBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
        {
            vkWriteDescriptorSetCount++;
        }
        else
        {
            // Skip
        }
    }
    if (vkWriteDescriptorSetCount > 0)
    {
        uint32_t vkWriteDescriptorSetIndex = 0;
        VkWriteDescriptorSet *vkWriteDescriptorSets = tknMalloc(sizeof(VkWriteDescriptorSet) * vkWriteDescriptorSetCount);
        VkDescriptorImageInfo *vkDescriptorImageInfos = tknMalloc(sizeof(VkDescriptorImageInfo) * vkWriteDescriptorSetCount);
        for (uint32_t binding = 0; binding < pTknMaterial->tknBindingCount; binding++)
        {
            TknBinding *pTknBinding = &pTknMaterial->pTknBindings[binding];
            if (pTknBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
            {
                TknAttachment *pTknAttachment = pTknBinding->tknBindingUnion.tknInputAttachmentBinding.pTknAttachment;
                tknAssert(pTknAttachment != NULL, "TknBinding %d is not bound to an attachment", binding);
                pTknBinding->tknBindingUnion.tknInputAttachmentBinding.pTknAttachment = NULL;

                if (TKN_ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->tknAttachmentType)
                {
                    tknRemoveFromHashSet(&pTknAttachment->tknAttachmentUnion.tknDynamicAttachment.tknBindingPtrHashSet, &pTknBinding);
                }
                else if (TKN_ATTACHMENT_TYPE_FIXED == pTknAttachment->tknAttachmentType)
                {
                    tknRemoveFromHashSet(&pTknAttachment->tknAttachmentUnion.tknFixedAttachment.tknBindingPtrHashSet, &pTknBinding);
                }
                else
                {
                    tknError("Swapchain attachment cannot be used as input attachment (attachment type: %d)", pTknAttachment->tknAttachmentType);
                }
                VkImageView vkImageView = pTknGfxContext->pTknEmptyImage->vkImageView;
                vkDescriptorImageInfos[vkWriteDescriptorSetIndex] = (VkDescriptorImageInfo){
                    .sampler = VK_NULL_HANDLE,
                    .imageView = vkImageView,
                    .imageLayout = VK_IMAGE_LAYOUT_GENERAL,
                };
                vkWriteDescriptorSets[vkWriteDescriptorSetIndex] = (VkWriteDescriptorSet){
                    .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                    .dstSet = pTknMaterial->vkDescriptorSet,
                    .dstBinding = binding,
                    .dstArrayElement = 0,
                    .descriptorCount = 1,
                    .descriptorType = VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT,
                    .pImageInfo = &vkDescriptorImageInfos[vkWriteDescriptorSetIndex],
                    .pBufferInfo = VK_NULL_HANDLE,
                    .pTexelBufferView = VK_NULL_HANDLE,
                };
                vkWriteDescriptorSetIndex++;
            }
            else
            {
                // Skip
            }
        }
        VkDevice vkDevice = pTknGfxContext->vkDevice;
        vkUpdateDescriptorSets(vkDevice, vkWriteDescriptorSetCount, vkWriteDescriptorSets, 0, NULL);
        tknFree(vkDescriptorImageInfos);
        tknFree(vkWriteDescriptorSets);
    }
    else
    {
        return;
    }
}
void tknUpdateAttachmentOfMaterialPtr(TknGfxContext *pTknGfxContext, TknBinding *pTknBinding)
{
    tknAssert(pTknBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, "TknBinding is not an input attachment");
    tknAssert(pTknBinding->tknBindingUnion.tknInputAttachmentBinding.pTknAttachment != NULL, "TknBinding is not bound to an attachment");

    TknAttachment *pTknAttachment = pTknBinding->tknBindingUnion.tknInputAttachmentBinding.pTknAttachment;
    VkImageView vkImageView = VK_NULL_HANDLE;

    if (TKN_ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->tknAttachmentType)
    {
        vkImageView = pTknAttachment->tknAttachmentUnion.tknDynamicAttachment.vkImageView;
    }
    else if (TKN_ATTACHMENT_TYPE_FIXED == pTknAttachment->tknAttachmentType)
    {
        vkImageView = pTknAttachment->tknAttachmentUnion.tknFixedAttachment.vkImageView;
    }
    else
    {
        tknError("Swapchain attachment cannot be used as input attachment (attachment type: %d)", pTknAttachment->tknAttachmentType);
    }

    VkDescriptorImageInfo vkDescriptorImageInfo = {
        .sampler = VK_NULL_HANDLE,
        .imageView = vkImageView,
        .imageLayout = pTknBinding->tknBindingUnion.tknInputAttachmentBinding.vkImageLayout,
    };
    VkWriteDescriptorSet vkWriteDescriptorSet = {
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = pTknBinding->pTknMaterial->vkDescriptorSet,
        .dstBinding = pTknBinding->binding,
        .dstArrayElement = 0,
        .descriptorCount = 1,
        .descriptorType = VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT,
        .pImageInfo = &vkDescriptorImageInfo,
        .pBufferInfo = VK_NULL_HANDLE,
        .pTexelBufferView = VK_NULL_HANDLE,
    };
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkUpdateDescriptorSets(vkDevice, 1, &vkWriteDescriptorSet, 0, NULL);
}

TknMaterial *tknGetGlobalMaterialPtr(TknGfxContext *pTknGfxContext)
{
    tknAssert(pTknGfxContext->pTknGlobalDescriptorSet != NULL, "Global descriptor set is NULL");
    TknHashSet tknMaterialPtrHashSet = pTknGfxContext->pTknGlobalDescriptorSet->tknMaterialPtrHashSet;
    tknAssert(tknMaterialPtrHashSet.count == 1, "TknMaterial pointer hashset count is not 1");
    for (uint32_t nodeIndex = 0; nodeIndex < tknMaterialPtrHashSet.capacity; nodeIndex++)
    {
        TknListNode *node = tknMaterialPtrHashSet.nodePtrs[nodeIndex];
        if (node)
        {
            TknMaterial *pTknMaterial = *(TknMaterial **)node->data;
            return pTknMaterial;
        }
        else
        {
            // Continue searching
        }
    }
    tknError("Failed to find global material");
    return NULL;
}
TknMaterial *tknGetSubpassMaterialPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass, uint32_t tknSubpassIndex)
{
    tknAssert(pTknRenderPass != NULL, "Render pass is NULL");
    tknAssert(tknSubpassIndex < pTknRenderPass->tknSubpassCount, "Subpass index is out of bounds");
    tknAssert(pTknRenderPass->pTknSubpasses[tknSubpassIndex].pTknSubpassDescriptorSet != NULL, "Subpass descriptor set is NULL");
    tknAssert(pTknRenderPass->pTknSubpasses[tknSubpassIndex].pTknSubpassDescriptorSet->tknMaterialPtrHashSet.count == 1, "TknMaterial pointer hashset count is not 1");
    TknHashSet tknMaterialPtrHashSet = pTknRenderPass->pTknSubpasses[tknSubpassIndex].pTknSubpassDescriptorSet->tknMaterialPtrHashSet;
    for (uint32_t nodeIndex = 0; nodeIndex < tknMaterialPtrHashSet.capacity; nodeIndex++)
    {
        TknListNode *node = tknMaterialPtrHashSet.nodePtrs[nodeIndex];
        if (node)
        {
            TknMaterial *pTknMaterial = *(TknMaterial **)node->data;
            return pTknMaterial;
        }
        else
        {
            // Continue searching
        }
    }
    tknError("Failed to find subpass material");
    return NULL;
}
TknMaterial *tknCreatePipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline)
{
    TknMaterial *pTknMaterial = tknCreateMaterialPtr(pTknGfxContext, pTknPipeline->pTknPipelineDescriptorSet);
    return pTknMaterial;
}
void tknDestroyPipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    tknDestroyMaterialPtr(pTknGfxContext, pTknMaterial);
}

void tknUpdateMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial, uint32_t inputBindingCount, TknInputBinding *tknInputBindings)
{
    if (inputBindingCount > 0)
    {
        tknAssert(NULL != pTknMaterial, "TknMaterial must not be NULL");
        uint32_t vkWriteDescriptorSetCount = 0;
        VkWriteDescriptorSet *vkWriteDescriptorSets = tknMalloc(sizeof(VkWriteDescriptorSet) * inputBindingCount);
        VkDescriptorImageInfo *vkDescriptorImageInfos = tknMalloc(sizeof(VkDescriptorImageInfo) * inputBindingCount);
        VkDescriptorBufferInfo *vkDescriptorBufferInfos = tknMalloc(sizeof(VkDescriptorBufferInfo) * inputBindingCount);
        for (uint32_t bindingIndex = 0; bindingIndex < inputBindingCount; bindingIndex++)
        {
            TknInputBinding tknInputBinding = tknInputBindings[bindingIndex];
            uint32_t binding = tknInputBinding.binding;
            tknAssert(binding < pTknMaterial->tknBindingCount, "Invalid binding index");
            VkDescriptorType vkDescriptorType = pTknMaterial->pTknBindings[binding].vkDescriptorType;
            tknAssert(vkDescriptorType == tknInputBinding.vkDescriptorType, "Incompatible descriptor type");
            TknBinding *pTknBinding = &pTknMaterial->pTknBindings[binding];
            // VK_DESCRIPTOR_TYPE_SAMPLER = 0,
            // VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER = 1,
            // VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE = 2,
            // VK_DESCRIPTOR_TYPE_STORAGE_IMAGE = 3,
            // VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER = 4,
            // VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER = 5,
            // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6,
            // VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7,
            // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC = 8,
            // VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC = 9,
            // VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT = 10
            if (VK_DESCRIPTOR_TYPE_SAMPLER == vkDescriptorType)
            {
                TknSampler *pInputSampler = tknInputBinding.tknInputBindingUnion.tknSamplerBinding.pTknSampler;
                TknSampler *pTknSampler = pTknBinding->tknBindingUnion.tknSamplerBinding.pTknSampler;
                if (pInputSampler == pTknSampler)
                {
                    // No change, skip
                }
                else
                {
                    if (NULL == pTknSampler)
                    {
                        // Nothing
                    }
                    else
                    {
                        // Current sampler deref descriptor
                        tknRemoveFromHashSet(&pTknSampler->tknBindingPtrHashSet, &pTknBinding);
                    }

                    pTknBinding->tknBindingUnion.tknSamplerBinding.pTknSampler = pInputSampler;
                    if (NULL == pInputSampler)
                    {
                        tknError("Cannot bind NULL sampler");
                    }
                    else
                    {
                        // New sampler ref descriptor
                        tknAddToHashSet(&pInputSampler->tknBindingPtrHashSet, &pTknBinding);
                        vkDescriptorImageInfos[vkWriteDescriptorSetCount] = (VkDescriptorImageInfo){
                            .sampler = pInputSampler->vkSampler,
                            .imageView = VK_NULL_HANDLE,
                            .imageLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                        };
                    }
                    VkWriteDescriptorSet vkWriteDescriptorSet = {
                        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                        .dstSet = pTknMaterial->vkDescriptorSet,
                        .dstBinding = binding,
                        .dstArrayElement = 0,
                        .descriptorCount = 1,
                        .descriptorType = vkDescriptorType,
                        .pImageInfo = &vkDescriptorImageInfos[vkWriteDescriptorSetCount],
                        .pBufferInfo = NULL,
                        .pTexelBufferView = NULL,
                    };
                    vkWriteDescriptorSets[vkWriteDescriptorSetCount] = vkWriteDescriptorSet;
                    vkWriteDescriptorSetCount++;
                }
            }
            else if (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER == vkDescriptorType)
            {
                TknSampler *pInputSampler = tknInputBinding.tknInputBindingUnion.tknCombinedImageSamplerBinding.pTknSampler;
                TknImage *pInputImage = tknInputBinding.tknInputBindingUnion.tknCombinedImageSamplerBinding.pTknImage;
                TknSampler *pTknSampler = pTknBinding->tknBindingUnion.tknCombinedImageSamplerBinding.pTknSampler;
                TknImage *pTknImage = pTknBinding->tknBindingUnion.tknCombinedImageSamplerBinding.pTknImage;
                
                if (pInputSampler == pTknSampler && pInputImage == pTknImage)
                {
                    // No change, skip
                }
                else
                {
                    // Remove old references
                    if (NULL != pTknSampler)
                    {
                        tknRemoveFromHashSet(&pTknSampler->tknBindingPtrHashSet, &pTknBinding);
                    }
                    if (NULL != pTknImage)
                    {
                        tknRemoveFromHashSet(&pTknImage->tknBindingPtrHashSet, &pTknBinding);
                    }

                    // Update bindings
                    pTknBinding->tknBindingUnion.tknCombinedImageSamplerBinding.pTknSampler = pInputSampler;
                    pTknBinding->tknBindingUnion.tknCombinedImageSamplerBinding.pTknImage = pInputImage;
                    
                    if (NULL == pInputSampler || NULL == pInputImage)
                    {
                        tknError("Cannot bind NULL sampler or image in combined image sampler");
                    }
                    else
                    {
                        // Add new references
                        tknAddToHashSet(&pInputSampler->tknBindingPtrHashSet, &pTknBinding);
                        tknAddToHashSet(&pInputImage->tknBindingPtrHashSet, &pTknBinding);
                        
                        vkDescriptorImageInfos[vkWriteDescriptorSetCount] = (VkDescriptorImageInfo){
                            .sampler = pInputSampler->vkSampler,
                            .imageView = pInputImage->vkImageView,
                            .imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                        };
                    }
                    VkWriteDescriptorSet vkWriteDescriptorSet = {
                        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                        .dstSet = pTknMaterial->vkDescriptorSet,
                        .dstBinding = binding,
                        .dstArrayElement = 0,
                        .descriptorCount = 1,
                        .descriptorType = vkDescriptorType,
                        .pImageInfo = &vkDescriptorImageInfos[vkWriteDescriptorSetCount],
                        .pBufferInfo = NULL,
                        .pTexelBufferView = NULL,
                    };
                    vkWriteDescriptorSets[vkWriteDescriptorSetCount] = vkWriteDescriptorSet;
                    vkWriteDescriptorSetCount++;
                }
            }
            else if (VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE == vkDescriptorType)
            {
                tknError("Sampled image not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_IMAGE == vkDescriptorType)
            {
                tknError("Storage image not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER == vkDescriptorType)
            {
                tknError("Uniform texel buffer not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER == vkDescriptorType)
            {
                tknError("Storage texel buffer not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER == vkDescriptorType)
            {
                TknUniformBuffer *pInputUniformBuffer = tknInputBinding.tknInputBindingUnion.tknUniformBufferBinding.pTknUniformBuffer;
                TknUniformBuffer *pTknUniformBuffer = pTknBinding->tknBindingUnion.tknUniformBufferBinding.pTknUniformBuffer;
                if (pInputUniformBuffer == pTknUniformBuffer)
                {
                    // No change, skip
                }
                else
                {
                    if (NULL == pTknUniformBuffer)
                    {
                        // Nothing
                    }
                    else
                    {
                        // Current uniform buffer deref descriptor
                        tknRemoveFromHashSet(&pTknUniformBuffer->tknBindingPtrHashSet, &pTknBinding);
                    }
                    pTknBinding->tknBindingUnion.tknUniformBufferBinding.pTknUniformBuffer = pInputUniformBuffer;
                    if (NULL == pInputUniformBuffer)
                    {
                        tknError("Cannot bind NULL uniform buffer");
                    }
                    else
                    {
                        // New uniform buffer ref descriptor
                        tknAddToHashSet(&pInputUniformBuffer->tknBindingPtrHashSet, &pTknBinding);
                        vkDescriptorBufferInfos[vkWriteDescriptorSetCount] = (VkDescriptorBufferInfo){
                            .buffer = pInputUniformBuffer->vkBuffer,
                            .offset = 0,
                            .range = pInputUniformBuffer->size,
                        };
                    }
                    VkWriteDescriptorSet vkWriteDescriptorSet = {
                        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                        .dstSet = pTknMaterial->vkDescriptorSet,
                        .dstBinding = binding,
                        .dstArrayElement = 0,
                        .descriptorCount = 1,
                        .descriptorType = vkDescriptorType,
                        .pImageInfo = NULL,
                        .pBufferInfo = &vkDescriptorBufferInfos[vkWriteDescriptorSetCount],
                        .pTexelBufferView = NULL,
                    };
                    vkWriteDescriptorSets[vkWriteDescriptorSetCount] = vkWriteDescriptorSet;
                    vkWriteDescriptorSetCount++;
                }
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_BUFFER == vkDescriptorType)
            {
                tknError("Storage buffer not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC == vkDescriptorType)
            {
                tknError("Uniform buffer dynamic not yet implemented");
            }
            else if (VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC == vkDescriptorType)
            {
                tknError("Storage buffer dynamic not yet implemented");
            }
            else
            {
                tknError("Unsupported descriptor type: %d", vkDescriptorType);
            }
        }
        if (vkWriteDescriptorSetCount > 0)
        {
            VkDevice vkDevice = pTknGfxContext->vkDevice;
            vkUpdateDescriptorSets(vkDevice, vkWriteDescriptorSetCount, vkWriteDescriptorSets, 0, NULL);
        }
        tknFree(vkDescriptorBufferInfos);
        tknFree(vkDescriptorImageInfos);
        tknFree(vkWriteDescriptorSets);
    }
    else
    {
        tknWarning("No bindings to update");
        return;
    }
}

TknInputBindingUnion tknGetEmptyInputBindingUnion(TknGfxContext *pTknGfxContext, VkDescriptorType vkDescriptorType)
{
    TknInputBindingUnion emptyUnion;
    // Explicitly zero out the entire union
    memset(&emptyUnion, 0, sizeof(emptyUnion));
    
    // Create appropriate empty binding union based on descriptor type
    switch (vkDescriptorType)
    {
    case VK_DESCRIPTOR_TYPE_SAMPLER:
        emptyUnion.tknSamplerBinding.pTknSampler = pTknGfxContext->pTknEmptySampler;
        break;
    case VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER:
        emptyUnion.tknCombinedImageSamplerBinding.pTknSampler = pTknGfxContext->pTknEmptySampler;
        emptyUnion.tknCombinedImageSamplerBinding.pTknImage = pTknGfxContext->pTknEmptyImage;
        break;
    case VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER:
        emptyUnion.tknUniformBufferBinding.pTknUniformBuffer = pTknGfxContext->pTknEmptyUniformBuffer;
        break;

    default:
        // For unsupported types, default to uniform buffer as a safe fallback
        emptyUnion.tknUniformBufferBinding.pTknUniformBuffer = pTknGfxContext->pTknEmptyUniformBuffer;
        tknWarning("Unsupported descriptor type %d in tknGetEmptyInputBindingUnion, using uniform buffer fallback", vkDescriptorType);
        break;
    }

    return emptyUnion;
}
