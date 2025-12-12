#include "tknGfxCore.h"

TknInstance *tknCreateInstancePtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout, uint32_t tknInstanceCount, void *instances)
{
    TknInstance *pTknInstance = tknMalloc(sizeof(TknInstance));
    TknHashSet tknDrawCallPtrHashSet = tknCreateHashSet(sizeof(TknDrawCall *));

    *pTknInstance = (TknInstance){
        .pTknVertexInputLayout = pTknVertexInputLayout,
        .tknInstanceVkBuffer = VK_NULL_HANDLE,
        .tknInstanceVkDeviceMemory = VK_NULL_HANDLE,
        .tknInstanceMappedBuffer = NULL,
        .tknInstanceCount = tknInstanceCount,
        .tknMaxInstanceCount = tknInstanceCount,
        .tknDrawCallPtrHashSet = tknDrawCallPtrHashSet,
    };
    
    if (tknInstanceCount > 0)
    {
        VkDeviceSize bufferSize = tknInstanceCount * pTknVertexInputLayout->stride;
        tknCreateVkBuffer(pTknGfxContext, bufferSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &pTknInstance->tknInstanceVkBuffer, &pTknInstance->tknInstanceVkDeviceMemory);
        vkMapMemory(pTknGfxContext->vkDevice, pTknInstance->tknInstanceVkDeviceMemory, 0, bufferSize, 0, &pTknInstance->tknInstanceMappedBuffer);
        memcpy(pTknInstance->tknInstanceMappedBuffer, instances, bufferSize);
    }
    else
    {
        // Resources already initialized to NULL/0 above
    }
    
    return pTknInstance;
}
void tknDestroyInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance)
{
    tknAssert(0 == pTknInstance->tknDrawCallPtrHashSet.count, "TknInstance still has draw calls attached!");
    if (pTknInstance->tknInstanceCount > 0)
    {
        tknDestroyVkBuffer(pTknGfxContext, pTknInstance->tknInstanceVkBuffer, pTknInstance->tknInstanceVkDeviceMemory);
    }
    else
    {
        // Nothing to clean up
    }
    tknDestroyHashSet(pTknInstance->tknDrawCallPtrHashSet);
    tknFree(pTknInstance);
}
void tknUpdateInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance, void *newData, uint32_t tknInstanceCount)
{
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    VkDeviceSize newBufferSize = pTknInstance->pTknVertexInputLayout->stride * tknInstanceCount;
    
    if (0 == pTknInstance->tknMaxInstanceCount)
    {
        if (tknInstanceCount > 0)
        {
            pTknInstance->tknMaxInstanceCount = tknInstanceCount;
            pTknInstance->tknInstanceCount = tknInstanceCount;
            tknCreateVkBuffer(pTknGfxContext, newBufferSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &pTknInstance->tknInstanceVkBuffer, &pTknInstance->tknInstanceVkDeviceMemory);
            vkMapMemory(vkDevice, pTknInstance->tknInstanceVkDeviceMemory, 0, newBufferSize, 0, &pTknInstance->tknInstanceMappedBuffer);
            memcpy(pTknInstance->tknInstanceMappedBuffer, newData, newBufferSize);
        }
        else
        {
            pTknInstance->tknInstanceCount = 0;
        }
    }
    else
    {
        if (tknInstanceCount == 0)
        {
            pTknInstance->tknInstanceCount = 0;
        }
        else if (tknInstanceCount <= pTknInstance->tknMaxInstanceCount)
        {
            pTknInstance->tknInstanceCount = tknInstanceCount;
            memcpy(pTknInstance->tknInstanceMappedBuffer, newData, newBufferSize);
        }
        else
        {
            tknDestroyVkBuffer(pTknGfxContext, pTknInstance->tknInstanceVkBuffer, pTknInstance->tknInstanceVkDeviceMemory);
            pTknInstance->tknMaxInstanceCount = tknInstanceCount;
            pTknInstance->tknInstanceCount = tknInstanceCount;
            tknCreateVkBuffer(pTknGfxContext, newBufferSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &pTknInstance->tknInstanceVkBuffer, &pTknInstance->tknInstanceVkDeviceMemory);
            vkMapMemory(vkDevice, pTknInstance->tknInstanceVkDeviceMemory, 0, newBufferSize, 0, &pTknInstance->tknInstanceMappedBuffer);
            memcpy(pTknInstance->tknInstanceMappedBuffer, newData, newBufferSize);
        }
    }
}
