#include "gfxCore.h"
void populateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    uint32_t width = UINT32_MAX;
    uint32_t height = UINT32_MAX;
    uint32_t attachmentCount = pTknRenderPass->attachmentCount;
    TknAttachment **attachmentPtrs = pTknRenderPass->attachmentPtrs;
    SwapchainAttachment *pSwapchainUnion = &pTknGfxContext->pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    uint32_t swapchainWidth = pSwapchainUnion->swapchainExtent.width;
    uint32_t swapchainHeight = pSwapchainUnion->swapchainExtent.height;
    for (uint32_t attachmentIndex = 0; attachmentIndex < attachmentCount; attachmentIndex++)
    {
        TknAttachment *pTknAttachment = attachmentPtrs[attachmentIndex];
        if (ATTACHMENT_TYPE_SWAPCHAIN == pTknAttachment->attachmentType)
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
        else if (ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->attachmentType)
        {
            DynamicAttachment dynamicUnion = pTknAttachment->attachmentUnion.dynamicAttachment;
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
            FixedAttachment fixedUnion = pTknAttachment->attachmentUnion.fixedAttachment;
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
    pTknRenderPass->renderArea = (VkRect2D){
        .offset = {0, 0},
        .extent = {width, height},
    };
    TknAttachment *pSwapchainAttachment = getSwapchainAttachmentPtr(pTknGfxContext);
    if (tknContainsInHashSet(&pSwapchainAttachment->renderPassPtrHashSet, &pTknRenderPass))
    {
        uint32_t swapchainImageCount = pSwapchainUnion->swapchainImageCount;
        pTknRenderPass->vkFramebufferCount = swapchainImageCount;
        pTknRenderPass->vkFramebuffers = tknMalloc(sizeof(VkFramebuffer) * swapchainImageCount);
        VkImageView *attachmentVkImageViews = tknMalloc(sizeof(VkImageView) * attachmentCount);
        for (uint32_t swapchainIndex = 0; swapchainIndex < swapchainImageCount; swapchainIndex++)
        {
            for (uint32_t attachmentIndex = 0; attachmentIndex < attachmentCount; attachmentIndex++)
            {
                TknAttachment *pTknAttachment = attachmentPtrs[attachmentIndex];
                if (ATTACHMENT_TYPE_SWAPCHAIN == pTknAttachment->attachmentType)
                {
                    attachmentVkImageViews[attachmentIndex] = pSwapchainUnion->swapchainImageViews[swapchainIndex];
                }
                else if (ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->attachmentType)
                {
                    attachmentVkImageViews[attachmentIndex] = pTknAttachment->attachmentUnion.dynamicAttachment.vkImageView;
                }
                else
                {
                    attachmentVkImageViews[attachmentIndex] = pTknAttachment->attachmentUnion.fixedAttachment.vkImageView;
                }
            }
            VkFramebufferCreateInfo vkFramebufferCreateInfo = {
                .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .pNext = NULL,
                .flags = 0,
                .renderPass = pTknRenderPass->vkRenderPass,
                .attachmentCount = attachmentCount,
                .pAttachments = attachmentVkImageViews,
                .width = width,
                .height = height,
                .layers = 1,
            };
            assertVkResult(vkCreateFramebuffer(vkDevice, &vkFramebufferCreateInfo, NULL, &pTknRenderPass->vkFramebuffers[swapchainIndex]));
        }
        tknFree(attachmentVkImageViews);
    }
    else
    {
        pTknRenderPass->vkFramebufferCount = 1;
        pTknRenderPass->vkFramebuffers = tknMalloc(sizeof(VkFramebuffer));
        VkImageView *attachmentVkImageViews = tknMalloc(sizeof(VkImageView) * attachmentCount);
        for (uint32_t attachmentIndex = 0; attachmentIndex < attachmentCount; attachmentIndex++)
        {
            TknAttachment *pTknAttachment = attachmentPtrs[attachmentIndex];
            if (ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->attachmentType)
            {
                attachmentVkImageViews[attachmentIndex] = pTknAttachment->attachmentUnion.dynamicAttachment.vkImageView;
            }
            else
            {
                // ATTACHMENT_TYPE_FIXED == pTknAttachment->attachmentType
                attachmentVkImageViews[attachmentIndex] = pTknAttachment->attachmentUnion.fixedAttachment.vkImageView;
            }
        }
        VkFramebufferCreateInfo vkFramebufferCreateInfo = {
            .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .pNext = NULL,
            .flags = 0,
            .renderPass = pTknRenderPass->vkRenderPass,
            .attachmentCount = attachmentCount,
            .pAttachments = attachmentVkImageViews,
            .width = width,
            .height = height,
            .layers = 1,
        };

        assertVkResult(vkCreateFramebuffer(vkDevice, &vkFramebufferCreateInfo, NULL, &pTknRenderPass->vkFramebuffers[0]));
        tknFree(attachmentVkImageViews);
    }
}
void cleanupFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    for (uint32_t i = 0; i < pTknRenderPass->vkFramebufferCount; i++)
    {
        vkDestroyFramebuffer(vkDevice, pTknRenderPass->vkFramebuffers[i], NULL);
    }
    tknFree(pTknRenderPass->vkFramebuffers);
}
void repopulateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass)
{
    cleanupFramebuffers(pTknGfxContext, pTknRenderPass);
    populateFramebuffers(pTknGfxContext, pTknRenderPass);
}
