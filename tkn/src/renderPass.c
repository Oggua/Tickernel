#include "gfxCore.h"

static struct Subpass createSubpass(TknGfxContext *pTknGfxContext, uint32_t subpassIndex, uint32_t attachmentCount, TknAttachment **attachmentPtrs, uint32_t inputVkAttachmentReferenceCount, const VkAttachmentReference *inputVkAttachmentReferences, uint32_t spvPathCount, const char **spvPaths)
{
    VkImageLayout *inputAttachmentIndexToVkImageLayout = tknMalloc(sizeof(VkImageLayout) * inputVkAttachmentReferenceCount);
    for (uint32_t inputVkAttachmentReferenceIndex = 0; inputVkAttachmentReferenceIndex < inputVkAttachmentReferenceCount; inputVkAttachmentReferenceIndex++)
    {
        tknAssert(inputVkAttachmentReferences[inputVkAttachmentReferenceIndex].attachment < attachmentCount, "Input attachment reference index %u out of bounds", inputVkAttachmentReferenceIndex);

        inputAttachmentIndexToVkImageLayout[inputVkAttachmentReferenceIndex] = inputVkAttachmentReferences[inputVkAttachmentReferenceIndex].layout;
    }
    SpvReflectShaderModule *spvReflectShaderModules = tknMalloc(sizeof(SpvReflectShaderModule) * spvPathCount);
    for (uint32_t spvPathIndex = 0; spvPathIndex < spvPathCount; spvPathIndex++)
    {
        spvReflectShaderModules[spvPathIndex] = createSpvReflectShaderModule(spvPaths[spvPathIndex]);
    }
    DescriptorSet *pSubpassDescriptorSet = createDescriptorSetPtr(pTknGfxContext, spvPathCount, spvReflectShaderModules, TKN_SUBPASS_DESCRIPTOR_SET);
    TknMaterial *pTknMaterial = createMaterialPtr(pTknGfxContext, pSubpassDescriptorSet);
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
                        TknAttachment *pInputAttachment = attachmentPtrs[realAttachmentIndex];
                        if (NULL == pTknMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.pTknAttachment)
                        {
                            pTknMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.pTknAttachment = pInputAttachment;
                            pTknMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.vkImageLayout = inputAttachmentIndexToVkImageLayout[inputAttachmentIndex];
                        }
                        else
                        {
                            tknAssert(pTknMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.pTknAttachment == pInputAttachment,
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
        destroySpvReflectShaderModule(&spvReflectShaderModules[spvPathIndex]);
    }
    tknFree(spvReflectShaderModules);
    tknFree(inputAttachmentIndexToVkImageLayout);

    bindAttachmentsToMaterialPtr(pTknGfxContext, pTknMaterial);

    TknHashSet pipelinePtrHashSet = tknCreateHashSet(sizeof(TknPipeline *));
    TknDynamicArray drawCallPtrDynamicArray = tknCreateDynamicArray(sizeof(TknDrawCall *), TKN_DEFAULT_COLLECTION_SIZE);
    struct Subpass subpass = {
        .pSubpassDescriptorSet = pSubpassDescriptorSet,
        .pipelinePtrHashSet = pipelinePtrHashSet,
        .drawCallPtrDynamicArray = drawCallPtrDynamicArray,
    };
    return subpass;
}
static void destroySubpass(TknGfxContext *pTknGfxContext, struct Subpass subpass)
{
    for (uint32_t i = 0; i < subpass.pipelinePtrHashSet.capacity; i++)
    {
        TknListNode *node = subpass.pipelinePtrHashSet.nodePtrs[i];
        while (node)
        {
            TknListNode *nextNode = node->pNextNode;
            TknPipeline *pTknPipeline = *(TknPipeline **)node->data;
            destroyPipelinePtr(pTknGfxContext, pTknPipeline);
            node = nextNode;
        }
    }
    tknAssert(subpass.pSubpassDescriptorSet->materialPtrHashSet.count == 1, "Subpass must have exactly one material");
    for (uint32_t i = 0; i < subpass.pSubpassDescriptorSet->materialPtrHashSet.capacity; i++)
    {
        TknListNode *node = subpass.pSubpassDescriptorSet->materialPtrHashSet.nodePtrs[i];
        if (node != NULL)
        {
            TknMaterial *pTknMaterial = *(TknMaterial **)node->data;
            unbindAttachmentsFromMaterialPtr(pTknGfxContext, pTknMaterial);
            break;
        }
        else
        {
            // Skip
        }
    }
    destroyDescriptorSetPtr(pTknGfxContext, subpass.pSubpassDescriptorSet);
    tknDestroyHashSet(subpass.pipelinePtrHashSet);
    tknDestroyDynamicArray(subpass.drawCallPtrDynamicArray);
}

TknRenderPass *createRenderPassPtr(TknGfxContext *pTknGfxContext, uint32_t attachmentCount, VkAttachmentDescription *vkAttachmentDescriptions, TknAttachment **inputAttachmentPtrs, VkClearValue *vkClearValues, uint32_t subpassCount, VkSubpassDescription *vkSubpassDescriptions, uint32_t *spvPathCounts, const char ***spvPathsArray, uint32_t vkSubpassDependencyCount, VkSubpassDependency *vkSubpassDependencies, uint32_t renderPassIndex)
{
    TknRenderPass *pTknRenderPass = tknMalloc(sizeof(TknRenderPass));
    TknAttachment **attachmentPtrs = tknMalloc(sizeof(TknAttachment *) * attachmentCount);
    struct Subpass *subpasses = tknMalloc(sizeof(struct Subpass) * subpassCount);
    VkRenderPass vkRenderPass = VK_NULL_HANDLE;
    // Create vkRenderPass
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    for (uint32_t attachmentIndex = 0; attachmentIndex < attachmentCount; attachmentIndex++)
    {
        TknAttachment *pTknAttachment = inputAttachmentPtrs[attachmentIndex];
        attachmentPtrs[attachmentIndex] = pTknAttachment;
        vkAttachmentDescriptions[attachmentIndex].format = pTknAttachment->vkFormat;
        tknAddToHashSet(&pTknAttachment->renderPassPtrHashSet, &pTknRenderPass);
    }

    VkRenderPassCreateInfo vkRenderPassCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .attachmentCount = attachmentCount,
        .pAttachments = vkAttachmentDescriptions,
        .subpassCount = subpassCount,
        .pSubpasses = vkSubpassDescriptions,
        .dependencyCount = vkSubpassDependencyCount,
        .pDependencies = vkSubpassDependencies,
    };
    assertVkResult(vkCreateRenderPass(vkDevice, &vkRenderPassCreateInfo, NULL, &vkRenderPass));
    VkClearValue *clearValues = tknMalloc(sizeof(VkClearValue) * attachmentCount);
    memcpy(clearValues, vkClearValues, sizeof(VkClearValue) * attachmentCount);
    *pTknRenderPass = (TknRenderPass){
        .vkRenderPass = vkRenderPass,
        .attachmentCount = attachmentCount,
        .attachmentPtrs = attachmentPtrs,
        .vkClearValues = clearValues,
        .vkFramebufferCount = 0,
        .vkFramebuffers = NULL,
        .renderArea = {0},
        .subpassCount = subpassCount,
        .subpasses = subpasses,
    };

    // Create framebuffers and subpasses
    populateFramebuffers(pTknGfxContext, pTknRenderPass);
    for (uint32_t subpassIndex = 0; subpassIndex < pTknRenderPass->subpassCount; subpassIndex++)
    {
        pTknRenderPass->subpasses[subpassIndex] = createSubpass(pTknGfxContext, subpassIndex, attachmentCount, attachmentPtrs, vkSubpassDescriptions[subpassIndex].inputAttachmentCount, vkSubpassDescriptions[subpassIndex].pInputAttachments, spvPathCounts[subpassIndex], spvPathsArray[subpassIndex]);
    }
    tknInsertIntoDynamicArray(&pTknGfxContext->renderPassPtrDynamicArray, &pTknRenderPass, renderPassIndex);
    return pTknRenderPass;
}
void destroyRenderPassPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    tknRemoveFromDynamicArray(&pTknGfxContext->renderPassPtrDynamicArray, &pTknRenderPass);
    cleanupFramebuffers(pTknGfxContext, pTknRenderPass);
    vkDestroyRenderPass(pTknGfxContext->vkDevice, pTknRenderPass->vkRenderPass, NULL);
    for (uint32_t i = 0; i < pTknRenderPass->subpassCount; i++)
    {
        struct Subpass *pSubpass = &pTknRenderPass->subpasses[i];
        destroySubpass(pTknGfxContext, *pSubpass);
    }
    for (uint32_t i = 0; i < pTknRenderPass->attachmentCount; i++)
    {
        TknAttachment *pTknAttachment = pTknRenderPass->attachmentPtrs[i];
        tknRemoveFromHashSet(&pTknAttachment->renderPassPtrHashSet, &pTknRenderPass);
    }
    tknFree(pTknRenderPass->vkClearValues);
    tknFree(pTknRenderPass->subpasses);
    tknFree(pTknRenderPass->attachmentPtrs);
    tknFree(pTknRenderPass);
}