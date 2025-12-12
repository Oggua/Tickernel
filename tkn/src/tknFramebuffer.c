#include "tknGfxCore.h"
void tknPopulateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    uint32_t width = UINT32_MAX;
    uint32_t height = UINT32_MAX;
    uint32_t tknAttachmentCount = pTknRenderPass->tknAttachmentCount;
    TknAttachment **tknAttachmentPtrs = pTknRenderPass->tknAttachmentPtrs;
    TknSwapchainAttachment *pSwapchainUnion = &pTknGfxContext->pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    uint32_t swapchainWidth = pSwapchainUnion->tknSwapchainExtent.width;
    uint32_t swapchainHeight = pSwapchainUnion->tknSwapchainExtent.height;
    for (uint32_t attachmentIndex = 0; attachmentIndex < tknAttachmentCount; attachmentIndex++)
    {
        TknAttachment *pTknAttachment = tknAttachmentPtrs[attachmentIndex];
        if (TKN_ATTACHMENT_TYPE_SWAPCHAIN == pTknAttachment->tknAttachmentType)
        {
            if (UINT32_MAX == width && UINT32_MAX == height)
            {
                width = swapchainWidth;
                height = swapchainHeight;
            }
            else
            {
                tknAssert(width == swapchainWidth && height == swapchainHeight, "Swapchain attachment size mismatch!");
            }
        }
        else if (TKN_ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->tknAttachmentType)
        {
            TknDynamicAttachment dynamicUnion = pTknAttachment->tknAttachmentUnion.tknDynamicAttachment;
            uint32_t dynamicWidth = (uint32_t)(swapchainWidth * dynamicUnion.scaler + 0.5f);
            uint32_t dynamicHeight = (uint32_t)(swapchainHeight * dynamicUnion.scaler + 0.5f);
            if (UINT32_MAX == width && UINT32_MAX == height)
            {
                width = dynamicWidth;
                height = dynamicHeight;
            }
            else
            {
                tknAssert(width == dynamicWidth && height == dynamicHeight, "Dynamic attachment size mismatch!");
            }
        }
        else
        {
            TknFixedAttachment fixedUnion = pTknAttachment->tknAttachmentUnion.tknFixedAttachment;
            if (UINT32_MAX == width && UINT32_MAX == height)
            {
                width = fixedUnion.width;
                height = fixedUnion.height;
            }
            else
            {
                tknAssert(width == fixedUnion.width && height == fixedUnion.height, "Fixed attachment size mismatch!");
            }
        }
    }

    tknAssert(UINT32_MAX != width && UINT32_MAX != height, "No valid attachment found to determine framebuffer size");
    pTknRenderPass->tknRenderArea = (VkRect2D){
        .offset = {0, 0},
        .extent = {width, height},
    };
    TknAttachment *pTknSwapchainAttachment = tknGetSwapchainAttachmentPtr(pTknGfxContext);
    if (tknContainsInHashSet(&pTknSwapchainAttachment->tknRenderPassPtrHashSet, &pTknRenderPass))
    {
        uint32_t tknSwapchainImageCount = pSwapchainUnion->tknSwapchainImageCount;
        pTknRenderPass->vkFramebufferCount = tknSwapchainImageCount;
        pTknRenderPass->vkFramebuffers = tknMalloc(sizeof(VkFramebuffer) * tknSwapchainImageCount);
        VkImageView *attachmentVkImageViews = tknMalloc(sizeof(VkImageView) * tknAttachmentCount);
        for (uint32_t swapchainIndex = 0; swapchainIndex < tknSwapchainImageCount; swapchainIndex++)
        {
            for (uint32_t attachmentIndex = 0; attachmentIndex < tknAttachmentCount; attachmentIndex++)
            {
                TknAttachment *pTknAttachment = tknAttachmentPtrs[attachmentIndex];
                if (TKN_ATTACHMENT_TYPE_SWAPCHAIN == pTknAttachment->tknAttachmentType)
                {
                    attachmentVkImageViews[attachmentIndex] = pSwapchainUnion->tknSwapchainImageViews[swapchainIndex];
                }
                else if (TKN_ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->tknAttachmentType)
                {
                    attachmentVkImageViews[attachmentIndex] = pTknAttachment->tknAttachmentUnion.tknDynamicAttachment.vkImageView;
                }
                else
                {
                    attachmentVkImageViews[attachmentIndex] = pTknAttachment->tknAttachmentUnion.tknFixedAttachment.vkImageView;
                }
            }
            VkFramebufferCreateInfo vkFramebufferCreateInfo = {
                .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .pNext = NULL,
                .flags = 0,
                .renderPass = pTknRenderPass->vkRenderPass,
                .attachmentCount = tknAttachmentCount,
                .pAttachments = attachmentVkImageViews,
                .width = width,
                .height = height,
                .layers = 1,
            };
            tknAssertVkResult(vkCreateFramebuffer(vkDevice, &vkFramebufferCreateInfo, NULL, &pTknRenderPass->vkFramebuffers[swapchainIndex]));
        }
        tknFree(attachmentVkImageViews);
    }
    else
    {
        pTknRenderPass->vkFramebufferCount = 1;
        pTknRenderPass->vkFramebuffers = tknMalloc(sizeof(VkFramebuffer));
        VkImageView *attachmentVkImageViews = tknMalloc(sizeof(VkImageView) * tknAttachmentCount);
        for (uint32_t attachmentIndex = 0; attachmentIndex < tknAttachmentCount; attachmentIndex++)
        {
            TknAttachment *pTknAttachment = tknAttachmentPtrs[attachmentIndex];
            if (TKN_ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->tknAttachmentType)
            {
                attachmentVkImageViews[attachmentIndex] = pTknAttachment->tknAttachmentUnion.tknDynamicAttachment.vkImageView;
            }
            else
            {
                // TKN_ATTACHMENT_TYPE_FIXED == pTknAttachment->tknAttachmentType
                attachmentVkImageViews[attachmentIndex] = pTknAttachment->tknAttachmentUnion.tknFixedAttachment.vkImageView;
            }
        }
        VkFramebufferCreateInfo vkFramebufferCreateInfo = {
            .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .pNext = NULL,
            .flags = 0,
            .renderPass = pTknRenderPass->vkRenderPass,
            .attachmentCount = tknAttachmentCount,
            .pAttachments = attachmentVkImageViews,
            .width = width,
            .height = height,
            .layers = 1,
        };

        tknAssertVkResult(vkCreateFramebuffer(vkDevice, &vkFramebufferCreateInfo, NULL, &pTknRenderPass->vkFramebuffers[0]));
        tknFree(attachmentVkImageViews);
    }
}
void tknCleanupFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    for (uint32_t i = 0; i < pTknRenderPass->vkFramebufferCount; i++)
    {
        vkDestroyFramebuffer(vkDevice, pTknRenderPass->vkFramebuffers[i], NULL);
    }
    tknFree(pTknRenderPass->vkFramebuffers);
}
void tknRepopulateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    tknCleanupFramebuffers(pTknGfxContext, pTknRenderPass);
    tknPopulateFramebuffers(pTknGfxContext, pTknRenderPass);
}
