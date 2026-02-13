#include "tknGfxCore.h"

static void tknCopyVkBuffer(TknGfxContext *pTknGfxContext, VkBuffer srcVkBuffer, VkBuffer dstVkBuffer, VkDeviceSize size)
{
    VkCommandBuffer vkCommandBuffer = tknBeginSingleTimeCommands(pTknGfxContext);

    VkBufferCopy vkBufferCopy = {
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size
    };
    vkCmdCopyBuffer(vkCommandBuffer, srcVkBuffer, dstVkBuffer, 1, &vkBufferCopy);

    tknEndSingleTimeCommands(pTknGfxContext, vkCommandBuffer);
}

static bool tknCreateBufferWithData(TknGfxContext *pTknGfxContext, void *data, VkDeviceSize size, VkBufferUsageFlags usage, VkBuffer *pBuffer, VkDeviceMemory *pDeviceMemory)
{
    if (size == 0)
    {
        *pBuffer = VK_NULL_HANDLE;
        *pDeviceMemory = VK_NULL_HANDLE;
        return true;
    }
    
    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;
    
    // Create staging buffer
    tknCreateVkBuffer(pTknGfxContext, size, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, 
                   VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, 
                   &stagingBuffer, &stagingBufferMemory);
    
    // Copy data to staging buffer
    void *mappedData;
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkMapMemory(vkDevice, stagingBufferMemory, 0, size, 0, &mappedData);
    memcpy(mappedData, data, (size_t)size);
    vkUnmapMemory(vkDevice, stagingBufferMemory);
    
    // Create device local buffer
    tknCreateVkBuffer(pTknGfxContext, size, VK_BUFFER_USAGE_TRANSFER_DST_BIT | usage, 
                   VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, pBuffer, pDeviceMemory);
    
    // Copy from staging to device local buffer
    tknCopyVkBuffer(pTknGfxContext, stagingBuffer, *pBuffer, size);
    
    // Clean up staging buffer
    tknDestroyVkBuffer(pTknGfxContext, stagingBuffer, stagingBufferMemory);
    
    return true;
}

TknMesh *tknCreateMeshPtrWithData(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout, void *vertices, uint32_t tknVertexCount, VkIndexType vkIndexType, void *indices, uint32_t tknIndexCount)
{
    TknMesh *pTknMesh = tknMalloc(sizeof(TknMesh));
    VkBuffer tknVertexVkBuffer = VK_NULL_HANDLE;
    VkDeviceMemory tknVertexVkDeviceMemory = VK_NULL_HANDLE;
    VkBuffer tknIndexVkBuffer = VK_NULL_HANDLE;
    VkDeviceMemory tknIndexVkDeviceMemory = VK_NULL_HANDLE;

    // Create vertex buffer
    VkDeviceSize vertexSize = tknVertexCount * pTknVertexInputLayout->stride;
    tknCreateBufferWithData(pTknGfxContext, vertices, vertexSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, 
                        &tknVertexVkBuffer, &tknVertexVkDeviceMemory);

    // Create index buffer if needed
    if (tknIndexCount > 0)
    {
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        VkDeviceSize indexBufferSize = tknIndexCount * indexSize;
        tknCreateBufferWithData(pTknGfxContext, indices, indexBufferSize, VK_BUFFER_USAGE_INDEX_BUFFER_BIT, 
                            &tknIndexVkBuffer, &tknIndexVkDeviceMemory);
    }

    TknHashSet tknDrawCallPtrHashSet = tknCreateHashSet(sizeof(TknDrawCall *));
    *pTknMesh = (TknMesh){
        .tknVertexVkBuffer = tknVertexVkBuffer,
        .tknVertexVkDeviceMemory = tknVertexVkDeviceMemory,
        .tknVertexCount = tknVertexCount,
        .tknIndexVkBuffer = tknIndexVkBuffer,
        .tknIndexVkDeviceMemory = tknIndexVkDeviceMemory,
        .tknIndexCount = tknIndexCount,
        .pTknVertexInputLayout = pTknVertexInputLayout,
        .vkIndexType = vkIndexType,
        .tknDrawCallPtrHashSet = tknDrawCallPtrHashSet,
    };
    tknAddToHashSet(&pTknVertexInputLayout->tknReferencePtrHashSet, &pTknMesh);
    return pTknMesh;
}

void tknDestroyMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh)
{
    tknAssert(0 == pTknMesh->tknDrawCallPtrHashSet.count, "TknMesh still has draw calls attached!");
    tknDestroyHashSet(pTknMesh->tknDrawCallPtrHashSet);
    tknRemoveFromHashSet(&pTknMesh->pTknVertexInputLayout->tknReferencePtrHashSet, &pTknMesh);
    if (pTknMesh->tknVertexVkBuffer != VK_NULL_HANDLE && pTknMesh->tknVertexVkDeviceMemory != VK_NULL_HANDLE)
    {
        tknDestroyVkBuffer(pTknGfxContext, pTknMesh->tknVertexVkBuffer, pTknMesh->tknVertexVkDeviceMemory);
    }
    if (pTknMesh->tknIndexVkBuffer != VK_NULL_HANDLE && pTknMesh->tknIndexVkDeviceMemory != VK_NULL_HANDLE)
    {
        tknDestroyVkBuffer(pTknGfxContext, pTknMesh->tknIndexVkBuffer, pTknMesh->tknIndexVkDeviceMemory);
    }
    tknFree(pTknMesh);
}

void tknUpdateMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh, const char *format, const void *vertices, uint32_t tknVertexCount, uint32_t indexType, const void *indices, uint32_t tknIndexCount)
{
    // Update vertex buffer if vertices provided
    if (vertices && tknVertexCount > 0)
    {
        VkDeviceSize vertexSize = tknVertexCount * pTknMesh->pTknVertexInputLayout->stride;
        VkDeviceSize currentVertexSize = pTknMesh->tknVertexCount * pTknMesh->pTknVertexInputLayout->stride;

        // Check if we need to recreate the vertex buffer
        if (pTknMesh->tknVertexVkBuffer == VK_NULL_HANDLE || vertexSize > currentVertexSize)
        {
            // Destroy existing buffer if it exists
            if (pTknMesh->tknVertexVkBuffer != VK_NULL_HANDLE)
            {
                tknDestroyVkBuffer(pTknGfxContext, pTknMesh->tknVertexVkBuffer, pTknMesh->tknVertexVkDeviceMemory);
            }

            // Create new vertex buffer
            tknCreateVkBuffer(pTknGfxContext, vertexSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &pTknMesh->tknVertexVkBuffer, &pTknMesh->tknVertexVkDeviceMemory);
        }

        // Create staging buffer and copy data
        VkBuffer stagingBuffer;
        VkDeviceMemory stagingBufferMemory;
        tknCreateVkBuffer(pTknGfxContext, vertexSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &stagingBuffer, &stagingBufferMemory);

        // Copy data to staging buffer
        void *mappedData;
        VkDevice vkDevice = pTknGfxContext->vkDevice;
        vkMapMemory(vkDevice, stagingBufferMemory, 0, vertexSize, 0, &mappedData);
        memcpy(mappedData, vertices, (size_t)vertexSize);
        vkUnmapMemory(vkDevice, stagingBufferMemory);

        // Copy from staging to device local buffer
        tknCopyVkBuffer(pTknGfxContext, stagingBuffer, pTknMesh->tknVertexVkBuffer, vertexSize);

        // Clean up staging buffer
        tknDestroyVkBuffer(pTknGfxContext, stagingBuffer, stagingBufferMemory);

        // Update vertex count
        pTknMesh->tknVertexCount = tknVertexCount;
    }

    // Update index buffer if indices provided
    if (indices && tknIndexCount > 0)
    {
        VkIndexType vkIndexType = (VkIndexType)indexType;
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        VkDeviceSize indexBufferSize = tknIndexCount * indexSize;
        VkDeviceSize currentIndexSize = 0;
        if (pTknMesh->tknIndexVkBuffer != VK_NULL_HANDLE)
        {
            size_t currentIndexSizePerElement = (pTknMesh->vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
            currentIndexSize = pTknMesh->tknIndexCount * currentIndexSizePerElement;
        }

        // Check if we need to recreate the index buffer
        if (pTknMesh->tknIndexVkBuffer == VK_NULL_HANDLE || indexBufferSize > currentIndexSize || vkIndexType != pTknMesh->vkIndexType)
        {
            // Destroy existing buffer if it exists
            if (pTknMesh->tknIndexVkBuffer != VK_NULL_HANDLE)
            {
                tknDestroyVkBuffer(pTknGfxContext, pTknMesh->tknIndexVkBuffer, pTknMesh->tknIndexVkDeviceMemory);
            }

            // Create new index buffer
            tknCreateVkBuffer(pTknGfxContext, indexBufferSize, VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &pTknMesh->tknIndexVkBuffer, &pTknMesh->tknIndexVkDeviceMemory);
        }

        // Create staging buffer and copy data
        VkBuffer stagingBuffer;
        VkDeviceMemory stagingBufferMemory;
        tknCreateVkBuffer(pTknGfxContext, indexBufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &stagingBuffer, &stagingBufferMemory);

        // Copy data to staging buffer
        void *mappedData;
        VkDevice vkDevice = pTknGfxContext->vkDevice;
        vkMapMemory(vkDevice, stagingBufferMemory, 0, indexBufferSize, 0, &mappedData);
        memcpy(mappedData, indices, (size_t)indexBufferSize);
        vkUnmapMemory(vkDevice, stagingBufferMemory);

        // Copy from staging to device local buffer
        tknCopyVkBuffer(pTknGfxContext, stagingBuffer, pTknMesh->tknIndexVkBuffer, indexBufferSize);

        // Clean up staging buffer
        tknDestroyVkBuffer(pTknGfxContext, stagingBuffer, stagingBufferMemory);

        // Update index type and count
        pTknMesh->vkIndexType = vkIndexType;
        pTknMesh->tknIndexCount = tknIndexCount;
    }
}