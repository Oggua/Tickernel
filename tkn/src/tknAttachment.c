#include "tknGfxCore.h"

TknAttachment *tknCreateDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, float scaler)
{
    TknSwapchainAttachment *pTknSwapchainAttachment = &pTknGfxContext->pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    TknAttachment *pTknAttachment = tknMalloc(sizeof(TknAttachment));
    VkExtent3D vkExtent3D = {
        .width = (uint32_t)(pTknSwapchainAttachment->tknSwapchainExtent.width * scaler),
        .height = (uint32_t)(pTknSwapchainAttachment->tknSwapchainExtent.height * scaler),
        .depth = 1,
    };

    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    tknCreateVkImage(pTknGfxContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, vkImageUsageFlags, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, vkImageAspectFlags, &vkImage, &vkDeviceMemory, &vkImageView);
    TknDynamicAttachment dynamicAttachment = {
        .vkImage = vkImage,
        .vkDeviceMemory = vkDeviceMemory,
        .vkImageView = vkImageView,
        .vkImageUsageFlags = vkImageUsageFlags,
        .vkImageAspectFlags = vkImageAspectFlags,
        .scaler = scaler,
        .tknBindingPtrHashSet = tknCreateHashSet(sizeof(TknBinding *)),
    };
    *pTknAttachment = (TknAttachment){
        .tknAttachmentType = TKN_ATTACHMENT_TYPE_DYNAMIC,
        .tknAttachmentUnion.tknDynamicAttachment = dynamicAttachment,
        .vkFormat = vkFormat,
        .tknRenderPassPtrHashSet = tknCreateHashSet(sizeof(TknRenderPass *)),
    };
    tknAddToHashSet(&pTknGfxContext->tknDynamicAttachmentPtrHashSet, &pTknAttachment);
    return pTknAttachment;
}
void tknDestroyDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment)
{
    tknAssert(TKN_ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->tknAttachmentType, "TknAttachment type mismatch!");
    tknRemoveFromHashSet(&pTknGfxContext->tknDynamicAttachmentPtrHashSet, &pTknAttachment);
    TknDynamicAttachment dynamicAttachment = pTknAttachment->tknAttachmentUnion.tknDynamicAttachment;
    tknAssert(0 == dynamicAttachment.tknBindingPtrHashSet.count, "Cannot destroy dynamic attachment with bindings attached!");
    tknDestroyHashSet(dynamicAttachment.tknBindingPtrHashSet);
    tknAssert(0 == pTknAttachment->tknRenderPassPtrHashSet.count, "Cannot destroy dynamic attachment with render passes attached!");
    tknDestroyHashSet(pTknAttachment->tknRenderPassPtrHashSet);
    tknDestroyVkImage(pTknGfxContext, dynamicAttachment.vkImage, dynamicAttachment.vkDeviceMemory, dynamicAttachment.vkImageView);
    tknFree(pTknAttachment);
}
void tknResizeDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment)
{
    tknAssert(TKN_ATTACHMENT_TYPE_DYNAMIC == pTknAttachment->tknAttachmentType, "TknAttachment type mismatch!");
    TknDynamicAttachment *pDynamicAttachment = &pTknAttachment->tknAttachmentUnion.tknDynamicAttachment;
    TknSwapchainAttachment *pTknSwapchainAttachment = &pTknGfxContext->pTknSwapchainAttachment->tknAttachmentUnion.tknSwapchainAttachment;
    VkExtent3D vkExtent3D = {
        .width = (uint32_t)(pTknSwapchainAttachment->tknSwapchainExtent.width * pDynamicAttachment->scaler),
        .height = (uint32_t)(pTknSwapchainAttachment->tknSwapchainExtent.height * pDynamicAttachment->scaler),
        .depth = 1,
    };
    tknDestroyVkImage(pTknGfxContext, pDynamicAttachment->vkImage, pDynamicAttachment->vkDeviceMemory, pDynamicAttachment->vkImageView);
    tknCreateVkImage(pTknGfxContext, vkExtent3D, pTknAttachment->vkFormat, VK_IMAGE_TILING_OPTIMAL, pDynamicAttachment->vkImageUsageFlags, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, pDynamicAttachment->vkImageAspectFlags, &pDynamicAttachment->vkImage, &pDynamicAttachment->vkDeviceMemory, &pDynamicAttachment->vkImageView);

    for (uint32_t i = 0; i < pDynamicAttachment->tknBindingPtrHashSet.capacity; i++)
    {
        TknListNode *node = pDynamicAttachment->tknBindingPtrHashSet.nodePtrs[i];
        while (node)
        {
            TknBinding *pTknBinding = *(TknBinding **)node->data;
            tknUpdateAttachmentOfMaterialPtr(pTknGfxContext, pTknBinding);
            node = node->pNextNode;
        }
    }
}
TknAttachment *tknCreateFixedAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, uint32_t width, uint32_t height)
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
    tknCreateVkImage(pTknGfxContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, vkImageUsageFlags, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, vkImageAspectFlags, &vkImage, &vkDeviceMemory, &vkImageView);

    TknFixedAttachment fixedAttachment = {
        .vkImage = vkImage,
        .vkDeviceMemory = vkDeviceMemory,
        .vkImageView = vkImageView,
        .width = width,
        .height = height,
        .tknBindingPtrHashSet = tknCreateHashSet(sizeof(TknBinding *)),
    };

    *pTknAttachment = (TknAttachment){
        .tknAttachmentType = TKN_ATTACHMENT_TYPE_FIXED,
        .tknAttachmentUnion.tknFixedAttachment = fixedAttachment,
        .vkFormat = vkFormat,
        .tknRenderPassPtrHashSet = tknCreateHashSet(sizeof(TknRenderPass *)),
    };
    tknAddToHashSet(&pTknGfxContext->tknFixedAttachmentPtrHashSet, &pTknAttachment);
    return pTknAttachment;
}
void tknDestroyFixedAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment)
{
    tknAssert(TKN_ATTACHMENT_TYPE_FIXED == pTknAttachment->tknAttachmentType, "TknAttachment type mismatch!");
    tknAssert(0 == pTknAttachment->tknRenderPassPtrHashSet.count, "Cannot destroy fixed attachment with render passes attached!");
    tknRemoveFromHashSet(&pTknGfxContext->tknFixedAttachmentPtrHashSet, &pTknAttachment);
    tknDestroyHashSet(pTknAttachment->tknRenderPassPtrHashSet);
    TknFixedAttachment fixedAttachment = pTknAttachment->tknAttachmentUnion.tknFixedAttachment;
    tknDestroyVkImage(pTknGfxContext, fixedAttachment.vkImage, fixedAttachment.vkDeviceMemory, fixedAttachment.vkImageView);
    tknDestroyHashSet(fixedAttachment.tknBindingPtrHashSet);
    tknFree(pTknAttachment);
}
TknAttachment *tknGetSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext)
{
    return pTknGfxContext->pTknSwapchainAttachment;
}
