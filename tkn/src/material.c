#include "gfxCore.h"
TknMaterial *createMaterialPtr(TknGfxContext *pTknGfxContext, DescriptorSet *pDescriptorSet)
{
    TknMaterial *pTknMaterial = tknMalloc(sizeof(TknMaterial));
    VkDescriptorSet vkDescriptorSet = VK_NULL_HANDLE;
    uint32_t descriptorCount = pDescriptorSet->descriptorCount;
    Binding *bindings = tknMalloc(sizeof(Binding) * descriptorCount);
    VkDescriptorPool vkDescriptorPool = VK_NULL_HANDLE;

    for (uint32_t descriptorIndex = 0; descriptorIndex < descriptorCount; descriptorIndex++)
    {
        VkDescriptorType vkDescriptorType = pDescriptorSet->vkDescriptorTypes[descriptorIndex];
        
        // Initialize binding with explicit zero values
        bindings[descriptorIndex].vkDescriptorType = vkDescriptorType;
        bindings[descriptorIndex].pTknMaterial = pTknMaterial;
        bindings[descriptorIndex].binding = descriptorIndex;
        // Explicitly zero out the entire binding union
        memset(&bindings[descriptorIndex].bindingUnion, 0, sizeof(bindings[descriptorIndex].bindingUnion));
    }
    VkDescriptorPoolCreateInfo vkDescriptorPoolCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = pDescriptorSet->vkDescriptorPoolSizeDynamicArray.count,
        .pPoolSizes = pDescriptorSet->vkDescriptorPoolSizeDynamicArray.array,
        .maxSets = 1,
    };
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    assertVkResult(vkCreateDescriptorPool(vkDevice, &vkDescriptorPoolCreateInfo, NULL, &vkDescriptorPool));

    VkDescriptorSetAllocateInfo vkDescriptorSetAllocateInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = vkDescriptorPool,
        .descriptorSetCount = 1,
        .pSetLayouts = &pDescriptorSet->vkDescriptorSetLayout,
    };

    assertVkResult(vkAllocateDescriptorSets(vkDevice, &vkDescriptorSetAllocateInfo, &vkDescriptorSet));
    TknHashSet drawCallPtrHashSet = tknCreateHashSet(sizeof(TknDrawCall *));
    *pTknMaterial = (TknMaterial){
        .vkDescriptorSet = vkDescriptorSet,
        .bindingCount = descriptorCount,
        .bindings = bindings,
        .vkDescriptorPool = vkDescriptorPool,
        .pDescriptorSet = pDescriptorSet,
        .drawCallPtrHashSet = drawCallPtrHashSet,
    };
    tknAddToHashSet(&pDescriptorSet->materialPtrHashSet, &pTknMaterial);
    
    // Initialize all bindings with empty resources using updateMaterialPtr
    uint32_t inputBindingCount = 0;
    TknInputBinding *tknInputBindings = tknMalloc(sizeof(TknInputBinding) * descriptorCount);
    
    for (uint32_t i = 0; i < descriptorCount; i++)
    {
        VkDescriptorType vkDescriptorType = bindings[i].vkDescriptorType;
        if (vkDescriptorType != VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
        {
            // Get empty binding for this descriptor type
            TknInputBindingUnion tknInputBindingUnion = getEmptyInputBindingUnion(pTknGfxContext, vkDescriptorType);
            
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
        updateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindingCount, tknInputBindings);
    }
    tknFree(tknInputBindings);
    
    return pTknMaterial;
}

void destroyMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    tknAssert(0 == pTknMaterial->drawCallPtrHashSet.count, "TknMaterial still has draw calls attached!");
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    uint32_t inputBindingCount = 0;
    TknInputBinding *tknInputBindings = tknMalloc(sizeof(TknInputBinding) * pTknMaterial->bindingCount);
    for (uint32_t binding = 0; binding < pTknMaterial->bindingCount; binding++)
    {
        Binding *pBinding = &pTknMaterial->bindings[binding];
        VkDescriptorType vkDescriptorType = pBinding->vkDescriptorType;
        if (vkDescriptorType != VK_DESCRIPTOR_TYPE_MAX_ENUM && vkDescriptorType != VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
        {
            if (VK_DESCRIPTOR_TYPE_SAMPLER == vkDescriptorType)
            {
                TknSampler *pTknSampler = pBinding->bindingUnion.tknSamplerBinding.pTknSampler;
                if (NULL == pTknSampler)
                {
                    // Nothing
                }
                else
                {
                    // Current sampler deref descriptor
                    tknRemoveFromHashSet(&pTknSampler->bindingPtrHashSet, &pBinding);
                }
            }
            else if (VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER == vkDescriptorType)
            {
                TknSampler *pTknSampler = pBinding->bindingUnion.tknCombinedImageSamplerBinding.pTknSampler;
                TknImage *pTknImage = pBinding->bindingUnion.tknCombinedImageSamplerBinding.pTknImage;
                if (NULL == pTknSampler && NULL == pTknImage)
                {
                    // Nothing
                }
                else
                {
                    // Current sampler deref descriptor
                    tknRemoveFromHashSet(&pTknSampler->bindingPtrHashSet, &pBinding);
                    tknRemoveFromHashSet(&pTknImage->bindingPtrHashSet, &pBinding);
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
                TknUniformBuffer *pTknUniformBuffer = pBinding->bindingUnion.tknUniformBufferBinding.pTknUniformBuffer;
                if (NULL == pTknUniformBuffer)
                {
                    // Nothing
                }
                else
                {
                    // Current uniform buffer deref descriptor
                    tknRemoveFromHashSet(&pTknUniformBuffer->bindingPtrHashSet, &pBinding);
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
            tknAssert(pBinding->bindingUnion.inputAttachmentBinding.pTknAttachment == NULL, "Input attachment bindings must be unbound before destroying a material");
        }
        else
        {
            // Skip
        }
    }
    if (inputBindingCount > 0)
    {
        updateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindingCount, tknInputBindings);
    }
    tknFree(tknInputBindings);

    tknRemoveFromHashSet(&pTknMaterial->pDescriptorSet->materialPtrHashSet, &pTknMaterial);
    tknDestroyHashSet(pTknMaterial->drawCallPtrHashSet);
    // Destroying the descriptor pool automatically frees all descriptor sets allocated from it
    vkDestroyDescriptorPool(vkDevice, pTknMaterial->vkDescriptorPool, NULL);
    tknFree(pTknMaterial->bindings);
    tknFree(pTknMaterial);
}

void bindAttachmentsToMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    uint32_t vkWriteDescriptorSetCount = 0;
    for (uint32_t binding = 0; binding < pTknMaterial->bindingCount; binding++)
    {
        Binding *pBinding = &pTknMaterial->bindings[binding];
        if (pBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
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
        for (uint32_t binding = 0; binding < pTknMaterial->bindingCount; binding++)
        {
            Binding *pBinding = &pTknMaterial->bindings[binding];
            if (pBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
            {
                TknAttachment *pInputAttachment = pBinding->bindingUnion.inputAttachmentBinding.pTknAttachment;
                tknAssert(pInputAttachment != NULL, "Binding %d is not bound to an attachment", binding);
                VkImageView vkImageView = VK_NULL_HANDLE;
                if (ATTACHMENT_TYPE_DYNAMIC == pInputAttachment->attachmentType)
                {
                    vkImageView = pInputAttachment->attachmentUnion.dynamicAttachment.vkImageView;
                    tknAddToHashSet(&pInputAttachment->attachmentUnion.dynamicAttachment.bindingPtrHashSet, &pBinding);
                }
                else if (ATTACHMENT_TYPE_FIXED == pInputAttachment->attachmentType)
                {
                    vkImageView = pInputAttachment->attachmentUnion.fixedAttachment.vkImageView;
                    tknAddToHashSet(&pInputAttachment->attachmentUnion.fixedAttachment.bindingPtrHashSet, &pBinding);
                }
                else
                {
                    tknError("Swapchain attachment cannot be used as input attachment (attachment type: %d)", pInputAttachment->attachmentType);
                }

                vkDescriptorImageInfos[vkWriteDescriptorSetIndex] = (VkDescriptorImageInfo){
                    .sampler = VK_NULL_HANDLE,
                    .imageView = vkImageView,
                    .imageLayout = pBinding->bindingUnion.inputAttachmentBinding.vkImageLayout,
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
void unbindAttachmentsFromMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    uint32_t vkWriteDescriptorSetCount = 0;
    for (uint32_t binding = 0; binding < pTknMaterial->bindingCount; binding++)
    {
        Binding *pBinding = &pTknMaterial->bindings[binding];
        if (pBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
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
        for (uint32_t binding = 0; binding < pTknMaterial->bindingCount; binding++)
        {
            Binding *pBinding = &pTknMaterial->bindings[binding];
            if (pBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT)
            {
                TknAttachment *pTknAttachment = pBinding->bindingUnion.inputAttachmentBinding.pTknAttachment;
                tknAssert(pTknAttachment != NULL, "Binding %d is not bound to an attachment", binding);
                pBinding->bindingUnion.inputAttachmentBinding.pTknAttachment = NULL;

                if (ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->attachmentType)
                {
                    tknRemoveFromHashSet(&pTknAttachment->attachmentUnion.dynamicAttachment.bindingPtrHashSet, &pBinding);
                }
                else if (ATTACHMENT_TYPE_FIXED == pTknAttachment->attachmentType)
                {
                    tknRemoveFromHashSet(&pTknAttachment->attachmentUnion.fixedAttachment.bindingPtrHashSet, &pBinding);
                }
                else
                {
                    tknError("Swapchain attachment cannot be used as input attachment (attachment type: %d)", pTknAttachment->attachmentType);
                }
                VkImageView vkImageView = pTknGfxContext->pEmptyImage->vkImageView;
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
void updateAttachmentOfMaterialPtr(TknGfxContext *pTknGfxContext, Binding *pBinding)
{
    tknAssert(pBinding->vkDescriptorType == VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, "Binding is not an input attachment");
    tknAssert(pBinding->bindingUnion.inputAttachmentBinding.pTknAttachment != NULL, "Binding is not bound to an attachment");

    TknAttachment *pTknAttachment = pBinding->bindingUnion.inputAttachmentBinding.pTknAttachment;
    VkImageView vkImageView = VK_NULL_HANDLE;

    if (ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->attachmentType)
    {
        vkImageView = pTknAttachment->attachmentUnion.dynamicAttachment.vkImageView;
    }
    else if (ATTACHMENT_TYPE_FIXED == pTknAttachment->attachmentType)
    {
        vkImageView = pTknAttachment->attachmentUnion.fixedAttachment.vkImageView;
    }
    else
    {
        tknError("Swapchain attachment cannot be used as input attachment (attachment type: %d)", pTknAttachment->attachmentType);
    }

    VkDescriptorImageInfo vkDescriptorImageInfo = {
        .sampler = VK_NULL_HANDLE,
        .imageView = vkImageView,
        .imageLayout = pBinding->bindingUnion.inputAttachmentBinding.vkImageLayout,
    };
    VkWriteDescriptorSet vkWriteDescriptorSet = {
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = pBinding->pTknMaterial->vkDescriptorSet,
        .dstBinding = pBinding->binding,
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

TknMaterial *getGlobalMaterialPtr(TknGfxContext *pTknGfxContext)
{
    tknAssert(pTknGfxContext->pGlobalDescriptorSet != NULL, "Global descriptor set is NULL");
    TknHashSet materialPtrHashSet = pTknGfxContext->pGlobalDescriptorSet->materialPtrHashSet;
    tknAssert(materialPtrHashSet.count == 1, "TknMaterial pointer hashset count is not 1");
    for (uint32_t nodeIndex = 0; nodeIndex < materialPtrHashSet.capacity; nodeIndex++)
    {
        TknListNode *node = materialPtrHashSet.nodePtrs[nodeIndex];
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
TknMaterial *getSubpassMaterialPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass, uint32_t subpassIndex)
{
    tknAssert(pTknRenderPass != NULL, "Render pass is NULL");
    tknAssert(subpassIndex < pTknRenderPass->subpassCount, "Subpass index is out of bounds");
    tknAssert(pTknRenderPass->subpasses[subpassIndex].pSubpassDescriptorSet != NULL, "Subpass descriptor set is NULL");
    tknAssert(pTknRenderPass->subpasses[subpassIndex].pSubpassDescriptorSet->materialPtrHashSet.count == 1, "TknMaterial pointer hashset count is not 1");
    TknHashSet materialPtrHashSet = pTknRenderPass->subpasses[subpassIndex].pSubpassDescriptorSet->materialPtrHashSet;
    for (uint32_t nodeIndex = 0; nodeIndex < materialPtrHashSet.capacity; nodeIndex++)
    {
        TknListNode *node = materialPtrHashSet.nodePtrs[nodeIndex];
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
TknMaterial *createPipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline)
{
    TknMaterial *pTknMaterial = createMaterialPtr(pTknGfxContext, pTknPipeline->pPipelineDescriptorSet);
    return pTknMaterial;
}
void destroyPipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial)
{
    destroyMaterialPtr(pTknGfxContext, pTknMaterial);
}

void updateMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial, uint32_t inputBindingCount, TknInputBinding *tknInputBindings)
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
            tknAssert(binding < pTknMaterial->bindingCount, "Invalid binding index");
            VkDescriptorType vkDescriptorType = pTknMaterial->bindings[binding].vkDescriptorType;
            tknAssert(vkDescriptorType == tknInputBinding.vkDescriptorType, "Incompatible descriptor type");
            Binding *pBinding = &pTknMaterial->bindings[binding];
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
                TknSampler *pTknSampler = pBinding->bindingUnion.tknSamplerBinding.pTknSampler;
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
                        tknRemoveFromHashSet(&pTknSampler->bindingPtrHashSet, &pBinding);
                    }

                    pBinding->bindingUnion.tknSamplerBinding.pTknSampler = pInputSampler;
                    if (NULL == pInputSampler)
                    {
                        tknError("Cannot bind NULL sampler");
                    }
                    else
                    {
                        // New sampler ref descriptor
                        tknAddToHashSet(&pInputSampler->bindingPtrHashSet, &pBinding);
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
                TknSampler *pTknSampler = pBinding->bindingUnion.tknCombinedImageSamplerBinding.pTknSampler;
                TknImage *pTknImage = pBinding->bindingUnion.tknCombinedImageSamplerBinding.pTknImage;
                
                if (pInputSampler == pTknSampler && pInputImage == pTknImage)
                {
                    // No change, skip
                }
                else
                {
                    // Remove old references
                    if (NULL != pTknSampler)
                    {
                        tknRemoveFromHashSet(&pTknSampler->bindingPtrHashSet, &pBinding);
                    }
                    if (NULL != pTknImage)
                    {
                        tknRemoveFromHashSet(&pTknImage->bindingPtrHashSet, &pBinding);
                    }

                    // Update bindings
                    pBinding->bindingUnion.tknCombinedImageSamplerBinding.pTknSampler = pInputSampler;
                    pBinding->bindingUnion.tknCombinedImageSamplerBinding.pTknImage = pInputImage;
                    
                    if (NULL == pInputSampler || NULL == pInputImage)
                    {
                        tknError("Cannot bind NULL sampler or image in combined image sampler");
                    }
                    else
                    {
                        // Add new references
                        tknAddToHashSet(&pInputSampler->bindingPtrHashSet, &pBinding);
                        tknAddToHashSet(&pInputImage->bindingPtrHashSet, &pBinding);
                        
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
                TknUniformBuffer *pTknUniformBuffer = pBinding->bindingUnion.tknUniformBufferBinding.pTknUniformBuffer;
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
                        tknRemoveFromHashSet(&pTknUniformBuffer->bindingPtrHashSet, &pBinding);
                    }
                    pBinding->bindingUnion.tknUniformBufferBinding.pTknUniformBuffer = pInputUniformBuffer;
                    if (NULL == pInputUniformBuffer)
                    {
                        tknError("Cannot bind NULL uniform buffer");
                    }
                    else
                    {
                        // New uniform buffer ref descriptor
                        tknAddToHashSet(&pInputUniformBuffer->bindingPtrHashSet, &pBinding);
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

TknInputBindingUnion getEmptyInputBindingUnion(TknGfxContext *pTknGfxContext, VkDescriptorType vkDescriptorType)
{
    TknInputBindingUnion emptyUnion;
    // Explicitly zero out the entire union
    memset(&emptyUnion, 0, sizeof(emptyUnion));
    
    // Create appropriate empty binding union based on descriptor type
    switch (vkDescriptorType)
    {
    case VK_DESCRIPTOR_TYPE_SAMPLER:
        emptyUnion.tknSamplerBinding.pTknSampler = pTknGfxContext->pEmptySampler;
        break;
    case VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER:
        emptyUnion.tknCombinedImageSamplerBinding.pTknSampler = pTknGfxContext->pEmptySampler;
        emptyUnion.tknCombinedImageSamplerBinding.pTknImage = pTknGfxContext->pEmptyImage;
        break;
    case VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER:
        emptyUnion.tknUniformBufferBinding.pTknUniformBuffer = pTknGfxContext->pEmptyUniformBuffer;
        break;

    default:
        // For unsupported types, default to uniform buffer as a safe fallback
        emptyUnion.tknUniformBufferBinding.pTknUniformBuffer = pTknGfxContext->pEmptyUniformBuffer;
        tknWarning("Unsupported descriptor type %d in getEmptyInputBindingUnion, using uniform buffer fallback", vkDescriptorType);
        break;
    }

    return emptyUnion;
}
