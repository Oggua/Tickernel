#include "gfxCore.h"

static struct Subpass createSubpass(GfxContext *pGfxContext, uint32_t subpassIndex, uint32_t attachmentCount, Attachment **attachmentPtrs, uint32_t inputVkAttachmentReferenceCount, const VkAttachmentReference *inputVkAttachmentReferences, uint32_t spvPathCount, const char **spvPaths)
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
    DescriptorSet *pSubpassDescriptorSet = createDescriptorSetPtr(pGfxContext, spvPathCount, spvReflectShaderModules, TKN_SUBPASS_DESCRIPTOR_SET);
    Material *pMaterial = createMaterialPtr(pGfxContext, pSubpassDescriptorSet);
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
                        Attachment *pInputAttachment = attachmentPtrs[realAttachmentIndex];
                        if (NULL == pMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.pAttachment)
                        {
                            pMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.pAttachment = pInputAttachment;
                            pMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.vkImageLayout = inputAttachmentIndexToVkImageLayout[inputAttachmentIndex];
                        }
                        else
                        {
                            tknAssert(pMaterial->bindings[binding].bindingUnion.inputAttachmentBinding.pAttachment == pInputAttachment,
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

    bindAttachmentsToMaterialPtr(pGfxContext, pMaterial);

    TknHashSet pipelinePtrHashSet = tknCreateHashSet(sizeof(Pipeline *));
    TknDynamicArray drawCallPtrDynamicArray = tknCreateDynamicArray(sizeof(DrawCall *), TKN_DEFAULT_COLLECTION_SIZE);
    struct Subpass subpass = {
        .pSubpassDescriptorSet = pSubpassDescriptorSet,
        .pipelinePtrHashSet = pipelinePtrHashSet,
        .drawCallPtrDynamicArray = drawCallPtrDynamicArray,
    };
    return subpass;
}
static void destroySubpass(GfxContext *pGfxContext, struct Subpass subpass)
{
    for (uint32_t i = 0; i < subpass.pipelinePtrHashSet.capacity; i++)
    {
        TknListNode *node = subpass.pipelinePtrHashSet.nodePtrs[i];
        while (node)
        {
            TknListNode *nextNode = node->pNextNode;
            Pipeline *pPipeline = *(Pipeline **)node->data;
            destroyPipelinePtr(pGfxContext, pPipeline);
            node = nextNode;
        }
    }
    tknAssert(subpass.pSubpassDescriptorSet->materialPtrHashSet.count == 1, "Subpass must have exactly one material");
    for (uint32_t i = 0; i < subpass.pSubpassDescriptorSet->materialPtrHashSet.capacity; i++)
    {
        TknListNode *node = subpass.pSubpassDescriptorSet->materialPtrHashSet.nodePtrs[i];
        if (node != NULL)
        {
            Material *pMaterial = *(Material **)node->data;
            unbindAttachmentsFromMaterialPtr(pGfxContext, pMaterial);
            break;
        }
        else
        {
            // Skip
        }
    }
    destroyDescriptorSetPtr(pGfxContext, subpass.pSubpassDescriptorSet);
    tknDestroyHashSet(subpass.pipelinePtrHashSet);
    tknDestroyDynamicArray(subpass.drawCallPtrDynamicArray);
}

RenderPass *createRenderPassPtr(GfxContext *pGfxContext, uint32_t attachmentCount, VkAttachmentDescription *vkAttachmentDescriptions, Attachment **inputAttachmentPtrs, VkClearValue *vkClearValues, uint32_t subpassCount, VkSubpassDescription *vkSubpassDescriptions, uint32_t *spvPathCounts, const char ***spvPathsArray, uint32_t vkSubpassDependencyCount, VkSubpassDependency *vkSubpassDependencies, uint32_t renderPassIndex)
{
    RenderPass *pRenderPass = tknMalloc(sizeof(RenderPass));
    Attachment **attachmentPtrs = tknMalloc(sizeof(Attachment *) * attachmentCount);
    struct Subpass *subpasses = tknMalloc(sizeof(struct Subpass) * subpassCount);
    VkRenderPass vkRenderPass = VK_NULL_HANDLE;
    // Create vkRenderPass
    VkDevice vkDevice = pGfxContext->vkDevice;
    for (uint32_t attachmentIndex = 0; attachmentIndex < attachmentCount; attachmentIndex++)
    {
        Attachment *pAttachment = inputAttachmentPtrs[attachmentIndex];
        attachmentPtrs[attachmentIndex] = pAttachment;
        vkAttachmentDescriptions[attachmentIndex].format = pAttachment->vkFormat;
        tknAddToHashSet(&pAttachment->renderPassPtrHashSet, &pRenderPass);
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
    *pRenderPass = (RenderPass){
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
    populateFramebuffers(pGfxContext, pRenderPass);
    for (uint32_t subpassIndex = 0; subpassIndex < pRenderPass->subpassCount; subpassIndex++)
    {
        pRenderPass->subpasses[subpassIndex] = createSubpass(pGfxContext, subpassIndex, attachmentCount, attachmentPtrs, vkSubpassDescriptions[subpassIndex].inputAttachmentCount, vkSubpassDescriptions[subpassIndex].pInputAttachments, spvPathCounts[subpassIndex], spvPathsArray[subpassIndex]);
    }
    tknInsertIntoDynamicArray(&pGfxContext->renderPassPtrDynamicArray, &pRenderPass, renderPassIndex);
    return pRenderPass;
}
void destroyRenderPassPtr(GfxContext *pGfxContext, RenderPass *pRenderPass)
{
    tknRemoveFromDynamicArray(&pGfxContext->renderPassPtrDynamicArray, &pRenderPass);
    cleanupFramebuffers(pGfxContext, pRenderPass);
    vkDestroyRenderPass(pGfxContext->vkDevice, pRenderPass->vkRenderPass, NULL);
    for (uint32_t i = 0; i < pRenderPass->subpassCount; i++)
    {
        struct Subpass *pSubpass = &pRenderPass->subpasses[i];
        destroySubpass(pGfxContext, *pSubpass);
    }
    for (uint32_t i = 0; i < pRenderPass->attachmentCount; i++)
    {
        Attachment *pAttachment = pRenderPass->attachmentPtrs[i];
        tknRemoveFromHashSet(&pAttachment->renderPassPtrHashSet, &pRenderPass);
    }
    tknFree(pRenderPass->vkClearValues);
    tknFree(pRenderPass->subpasses);
    tknFree(pRenderPass->attachmentPtrs);
    tknFree(pRenderPass);
}