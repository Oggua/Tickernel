#include "tknGfxCore.h"

static struct TknSubpass createSubpass(TknGfxContext *pTknGfxContext, uint32_t tknSubpassIndex, uint32_t tknAttachmentCount, TknAttachment **tknAttachmentPtrs, uint32_t inputVkAttachmentReferenceCount, const VkAttachmentReference *inputVkAttachmentReferences, uint32_t spvPathCount, const char **spvPaths)
{
    VkImageLayout *inputAttachmentIndexToVkImageLayout = tknMalloc(sizeof(VkImageLayout) * inputVkAttachmentReferenceCount);
    for (uint32_t inputVkAttachmentReferenceIndex = 0; inputVkAttachmentReferenceIndex < inputVkAttachmentReferenceCount; inputVkAttachmentReferenceIndex++)
    {
        tknAssert(inputVkAttachmentReferences[inputVkAttachmentReferenceIndex].attachment < tknAttachmentCount, "Input attachment reference index %u out of bounds", inputVkAttachmentReferenceIndex);

        inputAttachmentIndexToVkImageLayout[inputVkAttachmentReferenceIndex] = inputVkAttachmentReferences[inputVkAttachmentReferenceIndex].layout;
    }
    SpvReflectShaderModule *spvReflectShaderModules = tknMalloc(sizeof(SpvReflectShaderModule) * spvPathCount);
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        spvReflectShaderModules[spvPathIndex] = tknCreateSpvReflectShaderModule(spvPaths[spvPathIndex]);
    }
    TknDescriptorSet *pTknSubpassDescriptorSet = tknCreateDescriptorSetPtr(pTknGfxContext, spvPathCount, spvReflectShaderModules, TKN_SUBPASS_DESCRIPTOR_SET);
    TknMaterial *pTknMaterial = tknCreateMaterialPtr(pTknGfxContext, pTknSubpassDescriptorSet);
    // Bind attachments
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        SpvReflectShaderModule spvReflectShaderModule = spvReflectShaderModules[spvPathIndex];
        for (uint32_t setIndex = 0; setIndex < spvReflectShaderModule.descriptor_set_count; setIndex++)
        {
            SpvReflectDescriptorSet spvReflectDescriptorSet = spvReflectShaderModule.descriptor_sets[setIndex];
            if (TKN_SUBPASS_DESCRIPTOR_SET == spvReflectDescriptorSet.set)
            {
                for (uint32_t bindingIndex = 0; bindingIndex < spvReflectDescriptorSet.binding_count; bindingIndex++)
                {
                    SpvReflectDescriptorBinding *pSpvReflectDescriptorBinding = spvReflectDescriptorSet.bindings[bindingIndex];
                    if (SPV_REFLECT_DESCRIPTOR_TYPE_INPUT_ATTACHMENT == pSpvReflectDescriptorBinding->descriptor_type)
                    {
                        uint32_t binding = pSpvReflectDescriptorBinding->binding;
                        uint32_t inputAttachmentIndex = pSpvReflectDescriptorBinding->input_attachment_index;
                        tknAssert(inputAttachmentIndex < inputVkAttachmentReferenceCount, "Input attachment index %u out of bounds (max %u)", inputAttachmentIndex, inputVkAttachmentReferenceCount);
                        
                        uint32_t realAttachmentIndex = inputVkAttachmentReferences[inputAttachmentIndex].attachment;
                        TknAttachment *pInputAttachment = tknAttachmentPtrs[realAttachmentIndex];
                        if (NULL == pTknMaterial->pTknBindings[binding].tknBindingUnion.tknInputAttachmentBinding.pTknAttachment)
                        {
                            pTknMaterial->pTknBindings[binding].tknBindingUnion.tknInputAttachmentBinding.pTknAttachment = pInputAttachment;
                            pTknMaterial->pTknBindings[binding].tknBindingUnion.tknInputAttachmentBinding.vkImageLayout = inputAttachmentIndexToVkImageLayout[inputAttachmentIndex];
                        }
                        else
                        {
                            tknAssert(pTknMaterial->pTknBindings[binding].tknBindingUnion.tknInputAttachmentBinding.pTknAttachment == pInputAttachment,
                                      "Input attachment %u already set for binding %u in subpass descriptor set", inputAttachmentIndex, binding);
                        }
                    }
                    else
                    {
                        // Skip
                    }
                }
            }
        }
        tknDestroySpvReflectShaderModule(&spvReflectShaderModules[spvPathIndex]);
    }
    tknFree(spvReflectShaderModules);
    tknFree(inputAttachmentIndexToVkImageLayout);

    tknBindAttachmentsToMaterialPtr(pTknGfxContext, pTknMaterial);

    TknHashSet tknPipelinePtrHashSet = tknCreateHashSet(sizeof(TknPipeline *));
    TknDynamicArray tknDrawCallPtrDynamicArray = tknCreateDynamicArray(sizeof(TknDrawCall *), TKN_DEFAULT_COLLECTION_SIZE);
    struct TknSubpass subpass = {
        .pTknSubpassDescriptorSet = pTknSubpassDescriptorSet,
        .tknPipelinePtrHashSet = tknPipelinePtrHashSet,
        .tknDrawCallPtrDynamicArray = tknDrawCallPtrDynamicArray,
    };
    return subpass;
}
static void destroySubpass(TknGfxContext *pTknGfxContext, struct TknSubpass subpass)
{
    for (uint32_t i = 0; i < subpass.tknPipelinePtrHashSet.capacity; i++)
    {
        TknListNode *node = subpass.tknPipelinePtrHashSet.nodePtrs[i];
        while (node)
        {
            TknListNode *nextNode = node->pNextNode;
            TknPipeline *pTknPipeline = *(TknPipeline **)node->data;
            tknDestroyPipelinePtr(pTknGfxContext, pTknPipeline);
            node = nextNode;
        }
    }
    tknAssert(subpass.pTknSubpassDescriptorSet->tknMaterialPtrHashSet.count == 1, "Subpass must have exactly one material");
    for (uint32_t i = 0; i < subpass.pTknSubpassDescriptorSet->tknMaterialPtrHashSet.capacity; i++)
    {
        TknListNode *node = subpass.pTknSubpassDescriptorSet->tknMaterialPtrHashSet.nodePtrs[i];
        if (node != NULL)
        {
            TknMaterial *pTknMaterial = *(TknMaterial **)node->data;
            tknUnbindAttachmentsFromMaterialPtr(pTknGfxContext, pTknMaterial);
            break;
        }
        else
        {
            // Skip
        }
    }
    tknDestroyDescriptorSetPtr(pTknGfxContext, subpass.pTknSubpassDescriptorSet);
    tknDestroyHashSet(subpass.tknPipelinePtrHashSet);
    tknDestroyDynamicArray(subpass.tknDrawCallPtrDynamicArray);
}

TknRenderPass *tknCreateRenderPassPtr(TknGfxContext *pTknGfxContext, uint32_t tknAttachmentCount, VkAttachmentDescription *vkAttachmentDescriptions, TknAttachment **inputAttachmentPtrs, VkClearValue *vkClearValues, uint32_t tknSubpassCount, VkSubpassDescription *vkSubpassDescriptions, uint32_t *spvPathCounts, const char ***spvPathsArray, uint32_t vkSubpassDependencyCount, VkSubpassDependency *vkSubpassDependencies, uint32_t renderPassIndex)
{
    TknRenderPass *pTknRenderPass = tknMalloc(sizeof(TknRenderPass));
    TknAttachment **tknAttachmentPtrs = tknMalloc(sizeof(TknAttachment *) * tknAttachmentCount);
    struct TknSubpass *subpasses = tknMalloc(sizeof(struct TknSubpass) * tknSubpassCount);
    VkRenderPass vkRenderPass = VK_NULL_HANDLE;
    // Create vkRenderPass
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    for (uint32_t attachmentIndex = 0; attachmentIndex < tknAttachmentCount; attachmentIndex++)
    {
        TknAttachment *pTknAttachment = inputAttachmentPtrs[attachmentIndex];
        tknAttachmentPtrs[attachmentIndex] = pTknAttachment;
        vkAttachmentDescriptions[attachmentIndex].format = pTknAttachment->vkFormat;
        tknAddToHashSet(&pTknAttachment->tknRenderPassPtrHashSet, &pTknRenderPass);
    }

    VkRenderPassCreateInfo vkRenderPassCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .attachmentCount = tknAttachmentCount,
        .pAttachments = vkAttachmentDescriptions,
        .subpassCount = tknSubpassCount,
        .pSubpasses = vkSubpassDescriptions,
        .dependencyCount = vkSubpassDependencyCount,
        .pDependencies = vkSubpassDependencies,
    };
    tknAssertVkResult(vkCreateRenderPass(vkDevice, &vkRenderPassCreateInfo, NULL, &vkRenderPass));
    VkClearValue *clearValues = tknMalloc(sizeof(VkClearValue) * tknAttachmentCount);
    memcpy(clearValues, vkClearValues, sizeof(VkClearValue) * tknAttachmentCount);
    *pTknRenderPass = (TknRenderPass){
        .vkRenderPass = vkRenderPass,
        .tknAttachmentCount = tknAttachmentCount,
        .tknAttachmentPtrs = tknAttachmentPtrs,
        .vkClearValues = clearValues,
        .vkFramebufferCount = 0,
        .vkFramebuffers = NULL,
        .tknRenderArea = {0},
        .tknSubpassCount = tknSubpassCount,
        .pTknSubpasses = subpasses,
    };

    // Create framebuffers and subpasses
    tknPopulateFramebuffers(pTknGfxContext, pTknRenderPass);
    for (uint32_t tknSubpassIndex = 0; tknSubpassIndex < pTknRenderPass->tknSubpassCount; tknSubpassIndex++)
    {
        pTknRenderPass->pTknSubpasses[tknSubpassIndex] = createSubpass(pTknGfxContext, tknSubpassIndex, tknAttachmentCount, tknAttachmentPtrs, vkSubpassDescriptions[tknSubpassIndex].inputAttachmentCount, vkSubpassDescriptions[tknSubpassIndex].pInputAttachments, spvPathCounts[tknSubpassIndex], spvPathsArray[tknSubpassIndex]);
    }
    tknInsertIntoDynamicArray(&pTknGfxContext->tknRenderPassPtrDynamicArray, &pTknRenderPass, renderPassIndex);
    return pTknRenderPass;
}
void tknDestroyRenderPassPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    tknRemoveFromDynamicArray(&pTknGfxContext->tknRenderPassPtrDynamicArray, &pTknRenderPass);
    tknCleanupFramebuffers(pTknGfxContext, pTknRenderPass);
    vkDestroyRenderPass(pTknGfxContext->vkDevice, pTknRenderPass->vkRenderPass, NULL);
    for (uint32_t i = 0; i < pTknRenderPass->tknSubpassCount; i++)
    {
        struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[i];
        destroySubpass(pTknGfxContext, *pTknSubpass);
    }
    for (uint32_t i = 0; i < pTknRenderPass->tknAttachmentCount; i++)
    {
        TknAttachment *pTknAttachment = pTknRenderPass->tknAttachmentPtrs[i];
        tknRemoveFromHashSet(&pTknAttachment->tknRenderPassPtrHashSet, &pTknRenderPass);
    }
    tknFree(pTknRenderPass->vkClearValues);
    tknFree(pTknRenderPass->pTknSubpasses);
    tknFree(pTknRenderPass->tknAttachmentPtrs);
    tknFree(pTknRenderPass);
}