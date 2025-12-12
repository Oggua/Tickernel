#include "gfxCore.h"

TknUniformBuffer *createUniformBufferPtr(TknGfxContext *pTknGfxContext, const void *data, VkDeviceSize size)
{
    TknUniformBuffer *pTknUniformBuffer = tknMalloc(sizeof(TknUniformBuffer));
    VkBuffer vkBuffer = VK_NULL_HANDLE;
    VkDeviceMemory vkDeviceMemory = VK_NULL_HANDLE;
    void *mapped = NULL;
    TknHashSet bindingPtrHashSet = tknCreateHashSet(sizeof(Binding *));

    createVkBuffer(pTknGfxContext, size, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &vkBuffer, &vkDeviceMemory);
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    assertVkResult(vkMapMemory(vkDevice, vkDeviceMemory, 0, size, 0, &mapped));

    *pTknUniformBuffer = (TknUniformBuffer){
        .vkBuffer = vkBuffer,
        .vkDeviceMemory = vkDeviceMemory,
        .mapped = mapped,
        .bindingPtrHashSet = bindingPtrHashSet,
        .size = size,
    };

    memcpy(pTknUniformBuffer->mapped, data, size);
    return pTknUniformBuffer;
}
void destroyUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer)
{
    clearBindingPtrHashSet(pTknGfxContext, pTknUniformBuffer->bindingPtrHashSet);
    tknDestroyHashSet(pTknUniformBuffer->bindingPtrHashSet);
    if (pTknUniformBuffer->mapped != NULL)
    {
        vkUnmapMemory(pTknGfxContext->vkDevice, pTknUniformBuffer->vkDeviceMemory);
    }
    destroyVkBuffer(pTknGfxContext, pTknUniformBuffer->vkBuffer, pTknUniformBuffer->vkDeviceMemory);
    pTknUniformBuffer->vkBuffer = VK_NULL_HANDLE;
    pTknUniformBuffer->vkDeviceMemory = VK_NULL_HANDLE;
    tknFree(pTknUniformBuffer);
}
void updateUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer, const void *data, VkDeviceSize size)
{
    tknAssert(pTknUniformBuffer->mapped != NULL, "Uniform buffer is not mapped!");
    tknAssert(size <= pTknUniformBuffer->size, "Data size exceeds mapped buffer size!");
    memcpy(pTknUniformBuffer->mapped, data, size);
}
