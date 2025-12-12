#include "gfxCore.h"

TknInstance *createInstancePtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout, uint32_t instanceCount, void *instances)
{
    TknInstance *pTknInstance = tknMalloc(sizeof(TknInstance));
    TknHashSet drawCallPtrHashSet = tknCreateHashSet(sizeof(TknDrawCall *));

    *pTknInstance = (TknInstance){
        .pTknVertexInputLayout = pTknVertexInputLayout,
        .instanceVkBuffer = VK_NULL_HANDLE,
        .instanceVkDeviceMemory = VK_NULL_HANDLE,
        .instanceMappedBuffer = NULL,
        .instanceCount = instanceCount,
        .maxInstanceCount = instanceCount,
        .drawCallPtrHashSet = drawCallPtrHashSet,
    };
    
    if (instanceCount > 0)
    {
        VkDeviceSize bufferSize = instanceCount * pTknVertexInputLayout->stride;
        createVkBuffer(pTknGfxContext, bufferSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &pTknInstance->instanceVkBuffer, &pTknInstance->instanceVkDeviceMemory);
        vkMapMemory(pTknGfxContext->vkDevice, pTknInstance->instanceVkDeviceMemory, 0, bufferSize, 0, &pTknInstance->instanceMappedBuffer);
        memcpy(pTknInstance->instanceMappedBuffer, instances, bufferSize);
    }
    else
    {
        // Resources already initialized to NULL/0 above
    }
    
    return pTknInstance;
}
void destroyInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance)
{
    tknAssert(0 == pTknInstance->drawCallPtrHashSet.count, "TknInstance still has draw calls attached!");
    if (pTknInstance->instanceCount > 0)
    {
        destroyVkBuffer(pTknGfxContext, pTknInstance->instanceVkBuffer, pTknInstance->instanceVkDeviceMemory);
    }
    else
    {
        // Nothing to clean up
    }
    tknDestroyHashSet(pTknInstance->drawCallPtrHashSet);
    tknFree(pTknInstance);
}
void updateInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance, void *newData, uint32_t instanceCount)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    VkDeviceSize newBufferSize = pTknInstance->pTknVertexInputLayout->stride * instanceCount;
    
    if (0 == pTknInstance->maxInstanceCount)
    {
        if (instanceCount > 0)
        {
            pTknInstance->maxInstanceCount = instanceCount;
            pTknInstance->instanceCount = instanceCount;
            createVkBuffer(pTknGfxContext, newBufferSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &pTknInstance->instanceVkBuffer, &pTknInstance->instanceVkDeviceMemory);
            vkMapMemory(vkDevice, pTknInstance->instanceVkDeviceMemory, 0, newBufferSize, 0, &pTknInstance->instanceMappedBuffer);
            memcpy(pTknInstance->instanceMappedBuffer, newData, newBufferSize);
        }
        else
        {
            pTknInstance->instanceCount = 0;
        }
    }
    else
    {
        if (instanceCount == 0)
        {
            pTknInstance->instanceCount = 0;
        }
        else if (instanceCount <= pTknInstance->maxInstanceCount)
        {
            pTknInstance->instanceCount = instanceCount;
            memcpy(pTknInstance->instanceMappedBuffer, newData, newBufferSize);
        }
        else
        {
            destroyVkBuffer(pTknGfxContext, pTknInstance->instanceVkBuffer, pTknInstance->instanceVkDeviceMemory);
            pTknInstance->maxInstanceCount = instanceCount;
            pTknInstance->instanceCount = instanceCount;
            createVkBuffer(pTknGfxContext, newBufferSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &pTknInstance->instanceVkBuffer, &pTknInstance->instanceVkDeviceMemory);
            vkMapMemory(vkDevice, pTknInstance->instanceVkDeviceMemory, 0, newBufferSize, 0, &pTknInstance->instanceMappedBuffer);
            memcpy(pTknInstance->instanceMappedBuffer, newData, newBufferSize);
        }
    }
}
