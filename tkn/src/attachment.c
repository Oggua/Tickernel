#include "gfxCore.h"

TknAttachment *createDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, float scaler)
{
    SwapchainAttachment *pSwapchainAttachment = &pTknGfxContext->pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    TknAttachment *pTknAttachment = tknMalloc(sizeof(TknAttachment));
    VkExtent3D vkExtent3D = {
        .width = (uint32_t)(pSwapchainAttachment->swapchainExtent.width * scaler),
        .height = (uint32_t)(pSwapchainAttachment->swapchainExtent.height * scaler),
        .depth = 1,
    };

    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    createVkImage(pTknGfxContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, vkImageUsageFlags, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, vkImageAspectFlags, &vkImage, &vkDeviceMemory, &vkImageView);
    DynamicAttachment dynamicAttachment = {
        .vkImage = vkImage,
        .vkDeviceMemory = vkDeviceMemory,
        .vkImageView = vkImageView,
        .vkImageUsageFlags = vkImageUsageFlags,
        .vkImageAspectFlags = vkImageAspectFlags,
        .scaler = scaler,
        .bindingPtrHashSet = tknCreateHashSet(sizeof(Binding *)),
    };
    *pTknAttachment = (TknAttachment){
        .attachmentType = ATTACHMENT_TYPE_DYNAMIC,
        .attachmentUnion.dynamicAttachment = dynamicAttachment,
        .vkFormat = vkFormat,
        .renderPassPtrHashSet = tknCreateHashSet(sizeof(TknRenderPass *)),
    };
    tknAddToHashSet(&pTknGfxContext->dynamicAttachmentPtrHashSet, &pTknAttachment);
    return pTknAttachment;
}
void destroyDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment)
{
    tknAssert(ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->attachmentType, "TknAttachment type mismatch!");
    tknRemoveFromHashSet(&pTknGfxContext->dynamicAttachmentPtrHashSet, &pTknAttachment);
    DynamicAttachment dynamicAttachment = pTknAttachment->attachmentUnion.dynamicAttachment;
    tknAssert(0 == dynamicAttachment.bindingPtrHashSet.count, "Cannot destroy dynamic attachment with bindings attached!");
    tknDestroyHashSet(dynamicAttachment.bindingPtrHashSet);
    tknAssert(0 == pTknAttachment->renderPassPtrHashSet.count, "Cannot destroy dynamic attachment with render passes attached!");
    tknDestroyHashSet(pTknAttachment->renderPassPtrHashSet);
    destroyVkImage(pTknGfxContext, dynamicAttachment.vkImage, dynamicAttachment.vkDeviceMemory, dynamicAttachment.vkImageView);
    tknFree(pTknAttachment);
}
void resizeDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment)
{
    tknAssert(ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->attachmentType, "TknAttachment type mismatch!");
    DynamicAttachment *pDynamicAttachment = &pTknAttachment->attachmentUnion.dynamicAttachment;
    SwapchainAttachment *pSwapchainAttachment = &pTknGfxContext->pSwapchainAttachment->attachmentUnion.swapchainAttachment;
    VkExtent3D vkExtent3D = {
        .width = (uint32_t)(pSwapchainAttachment->swapchainExtent.width * pDynamicAttachment->scaler),
        .height = (uint32_t)(pSwapchainAttachment->swapchainExtent.height * pDynamicAttachment->scaler),
        .depth = 1,
    };
    destroyVkImage(pTknGfxContext, pDynamicAttachment->vkImage, pDynamicAttachment->vkDeviceMemory, pDynamicAttachment->vkImageView);
    createVkImage(pTknGfxContext, vkExtent3D, pTknAttachment->vkFormat, VK_IMAGE_TILING_OPTIMAL, pDynamicAttachment->vkImageUsageFlags, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, pDynamicAttachment->vkImageAspectFlags, &pDynamicAttachment->vkImage, &pDynamicAttachment->vkDeviceMemory, &pDynamicAttachment->vkImageView);

    for (uint32_t i = 0; i < pDynamicAttachment->bindingPtrHashSet.capacity; i++)
    {
        TknListNode *node = pDynamicAttachment->bindingPtrHashSet.nodePtrs[i];
        while (node)
        {
            Binding *pBinding = *(Binding **)node->data;
            updateAttachmentOfMaterialPtr(pTknGfxContext, pBinding);
            node = node->pNextNode;
        }
    }
}
TknAttachment *createFixedAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, uint32_t width, uint32_t height)
{
    TknAttachment *pTknAttachment = tknMalloc(sizeof(TknAttachment));
    VkExtent3D vkExtent3D = {
        .width = width,
        .height = height,
        .depth = 1,
    };

    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    createVkImage(pTknGfxContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, vkImageUsageFlags, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, vkImageAspectFlags, &vkImage, &vkDeviceMemory, &vkImageView);

    FixedAttachment fixedAttachment = {
        .vkImage = vkImage,
        .vkDeviceMemory = vkDeviceMemory,
        .vkImageView = vkImageView,
        .width = width,
        .height = height,
        .bindingPtrHashSet = tknCreateHashSet(sizeof(Binding *)),
    };

    *pTknAttachment = (TknAttachment){
        .attachmentType = ATTACHMENT_TYPE_FIXED,
        .attachmentUnion.fixedAttachment = fixedAttachment,
        .vkFormat = vkFormat,
        .renderPassPtrHashSet = tknCreateHashSet(sizeof(TknRenderPass *)),
    };
    tknAddToHashSet(&pTknGfxContext->fixedAttachmentPtrHashSet, &pTknAttachment);
    return pTknAttachment;
}
void destroyFixedAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment)
{
    tknAssert(ATTACHMENT_TYPE_FIXED == pTknAttachment->attachmentType, "TknAttachment type mismatch!");
    tknAssert(0 == pTknAttachment->renderPassPtrHashSet.count, "Cannot destroy fixed attachment with render passes attached!");
    tknRemoveFromHashSet(&pTknGfxContext->fixedAttachmentPtrHashSet, &pTknAttachment);
    tknDestroyHashSet(pTknAttachment->renderPassPtrHashSet);
    FixedAttachment fixedAttachment = pTknAttachment->attachmentUnion.fixedAttachment;
    destroyVkImage(pTknGfxContext, fixedAttachment.vkImage, fixedAttachment.vkDeviceMemory, fixedAttachment.vkImageView);
    tknDestroyHashSet(fixedAttachment.bindingPtrHashSet);
    tknFree(pTknAttachment);
}
TknAttachment *getSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext)
{
    return pTknGfxContext->pSwapchainAttachment;
}
