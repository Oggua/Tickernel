#include "tknGfxCore.h"

TknUniformBuffer *tknCreateUniformBufferPtr(TknGfxContext *pTknGfxContext, const void *data, VkDeviceSize size)
{
    TknUniformBuffer *pTknUniformBuffer = tknMalloc(sizeof(TknUniformBuffer));
    VkBuffer vkBuffer = VK_NULL_HANDLE;
    VkDeviceMemory vkDeviceMemory = VK_NULL_HANDLE;
    void *mapped = NULL;
    TknHashSet tknBindingPtrHashSet = tknCreateHashSet(sizeof(TknBinding *));

    tknCreateVkBuffer(pTknGfxContext, size, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &vkBuffer, &vkDeviceMemory);
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    tknAssertVkResult(vkMapMemory(vkDevice, vkDeviceMemory, 0, size, 0, &mapped));

    *pTknUniformBuffer = (TknUniformBuffer){
        .vkBuffer = vkBuffer,
        .vkDeviceMemory = vkDeviceMemory,
        .mapped = mapped,
        .tknBindingPtrHashSet = tknBindingPtrHashSet,
        .size = size,
    };

    memcpy(pTknUniformBuffer->mapped, data, size);
    return pTknUniformBuffer;
}
void tknDestroyUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer)
{
    tknClearBindingPtrHashSet(pTknGfxContext, pTknUniformBuffer->tknBindingPtrHashSet);
    tknDestroyHashSet(pTknUniformBuffer->tknBindingPtrHashSet);
    if (pTknUniformBuffer->mapped != NULL)
    {
        vkUnmapMemory(pTknGfxContext->vkDevice, pTknUniformBuffer->vkDeviceMemory);
    }
    tknDestroyVkBuffer(pTknGfxContext, pTknUniformBuffer->vkBuffer, pTknUniformBuffer->vkDeviceMemory);
    pTknUniformBuffer->vkBuffer = VK_NULL_HANDLE;
    pTknUniformBuffer->vkDeviceMemory = VK_NULL_HANDLE;
    tknFree(pTknUniformBuffer);
}
void tknUpdateUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer, const void *data, VkDeviceSize size)
{
    tknAssert(pTknUniformBuffer->mapped != NULL, "Uniform buffer is not mapped!");
    tknAssert(size <= pTknUniformBuffer->size, "Data size exceeds mapped buffer size!");
    memcpy(pTknUniformBuffer->mapped, data, size);
}
