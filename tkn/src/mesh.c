#include "gfxCore.h"
// #include "rply.h"

static uint32_t getPlyPropertySize(const char *propertyType)
{
    if (strcmp(propertyType, "float") == 0 || strcmp(propertyType, "int") == 0 || strcmp(propertyType, "uint") == 0)
    {
        return 4;
    }
    else if (strcmp(propertyType, "double") == 0)
    {
        return 8;
    }
    else if (strcmp(propertyType, "short") == 0 || strcmp(propertyType, "ushort") == 0)
    {
        return 2;
    }
    else if (strcmp(propertyType, "char") == 0 || strcmp(propertyType, "uchar") == 0)
    {
        return 1;
    }
    else
    {
        return 0; // Invalid type
    }
}

static void copyVkBuffer(TknGfxContext *pTknGfxContext, VkBuffer srcVkBuffer, VkBuffer dstVkBuffer, VkDeviceSize size)
{
    VkCommandBuffer vkCommandBuffer = beginSingleTimeCommands(pTknGfxContext);

    VkBufferCopy vkBufferCopy = {
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size
    };
    vkCmdCopyBuffer(vkCommandBuffer, srcVkBuffer, dstVkBuffer, 1, &vkBufferCopy);

    endSingleTimeCommands(pTknGfxContext, vkCommandBuffer);
}

static bool readBinaryData(FILE *file, void **data, size_t size, const char *dataType)
{
    if (size == 0)
    {
        *data = NULL;
        return true;
    }
    
    *data = tknMalloc(size);
    size_t bytesRead = fread(*data, 1, size, file);
    if (bytesRead != size)
    {
        tknWarning("Failed to read %s data from PLY file: expected %zu bytes, got %zu",
                   dataType, size, bytesRead);
        tknFree(*data);
        *data = NULL;
        return false;
    }
    return true;
}

static bool createBufferWithData(TknGfxContext *pTknGfxContext, void *data, VkDeviceSize size, VkBufferUsageFlags usage, VkBuffer *pBuffer, VkDeviceMemory *pDeviceMemory)
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
    createVkBuffer(pTknGfxContext, size, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, 
                   VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, 
                   &stagingBuffer, &stagingBufferMemory);
    
    // Copy data to staging buffer
    void *mappedData;
    VkDevice vkDevice = pTknGfxContext->vkDevice;
    vkMapMemory(vkDevice, stagingBufferMemory, 0, size, 0, &mappedData);
    memcpy(mappedData, data, (size_t)size);
    vkUnmapMemory(vkDevice, stagingBufferMemory);
    
    // Create device local buffer
    createVkBuffer(pTknGfxContext, size, VK_BUFFER_USAGE_TRANSFER_DST_BIT | usage, 
                   VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, pBuffer, pDeviceMemory);
    
    // Copy from staging to device local buffer
    copyVkBuffer(pTknGfxContext, stagingBuffer, *pBuffer, size);
    
    // Clean up staging buffer
    destroyVkBuffer(pTknGfxContext, stagingBuffer, stagingBufferMemory);
    
    return true;
}

TknMesh *createMeshPtrWithData(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout, void *vertices, uint32_t vertexCount, VkIndexType vkIndexType, void *indices, uint32_t indexCount)
{
    TknMesh *pTknMesh = tknMalloc(sizeof(TknMesh));
    VkBuffer vertexVkBuffer = VK_NULL_HANDLE;
    VkDeviceMemory vertexVkDeviceMemory = VK_NULL_HANDLE;
    VkBuffer indexVkBuffer = VK_NULL_HANDLE;
    VkDeviceMemory indexVkDeviceMemory = VK_NULL_HANDLE;

    // Create vertex buffer
    VkDeviceSize vertexSize = vertexCount * pTknVertexInputLayout->stride;
    createBufferWithData(pTknGfxContext, vertices, vertexSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, 
                        &vertexVkBuffer, &vertexVkDeviceMemory);

    // Create index buffer if needed
    if (indexCount > 0)
    {
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        VkDeviceSize indexBufferSize = indexCount * indexSize;
        createBufferWithData(pTknGfxContext, indices, indexBufferSize, VK_BUFFER_USAGE_INDEX_BUFFER_BIT, 
                            &indexVkBuffer, &indexVkDeviceMemory);
    }

    TknHashSet drawCallPtrHashSet = tknCreateHashSet(sizeof(TknDrawCall *));
    *pTknMesh = (TknMesh){
        .vertexVkBuffer = vertexVkBuffer,
        .vertexVkDeviceMemory = vertexVkDeviceMemory,
        .vertexCount = vertexCount,
        .indexVkBuffer = indexVkBuffer,
        .indexVkDeviceMemory = indexVkDeviceMemory,
        .indexCount = indexCount,
        .pTknVertexInputLayout = pTknVertexInputLayout,
        .vkIndexType = vkIndexType,
        .drawCallPtrHashSet = drawCallPtrHashSet,
    };
    tknAddToHashSet(&pTknVertexInputLayout->referencePtrHashSet, &pTknMesh);
    return pTknMesh;
}

TknMesh *createMeshPtrWithPlyFile(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknMeshVertexInputLayout, VkIndexType vkIndexType, const char *plyFilePath)
{
    FILE *file = fopen(plyFilePath, "rb");
    if (!file)
    {
        tknWarning("Cannot open PLY file: %s", plyFilePath);
        return NULL;
    }

    char line[256];
    uint32_t vertexCount = 0;
    uint32_t indexCount = 0;
    
    // First pass: get element counts and validate format
    while (fgets(line, sizeof(line), file))
    {
        line[strcspn(line, "\r\n")] = 0;

        if (strcmp(line, "ply") == 0)
        {
            continue;
        }
        else if (strncmp(line, "format ", 7) == 0)
        {
            if (!strstr(line, "binary_little_endian"))
            {
                tknWarning("PLY file is not binary little endian format: %s", plyFilePath);
                fclose(file);
                return NULL;
            }
        }
        else if (strncmp(line, "element ", 8) == 0)
        {
            if (strstr(line, "vertex "))
            {
                sscanf(line, "element vertex %u", &vertexCount);
            }
            else if (strstr(line, "index "))
            {
                sscanf(line, "element index %u", &indexCount);
            }
        }
        else if (strcmp(line, "end_header") == 0)
        {
            break;
        }
    }

    // Second pass: detailed property validation
    fseek(file, 0, SEEK_SET);
    
    uint32_t currentAttributeIndex = 0;
    uint32_t currentAttributeBytesMatched = 0;
    bool inVertexElement = false;
    bool inIndexElement = false;
    uint32_t indexPropertyBytes = 0;
    
    while (fgets(line, sizeof(line), file))
    {
        line[strcspn(line, "\r\n")] = 0;

        if (strncmp(line, "element ", 8) == 0)
        {
            inVertexElement = false;
            inIndexElement = false;
            
            if (strstr(line, "vertex "))
            {
                inVertexElement = true;
                currentAttributeIndex = 0;
                currentAttributeBytesMatched = 0;
            }
            else if (strstr(line, "index "))
            {
                inIndexElement = true;
                indexPropertyBytes = 0;
            }
        }
        else if (strncmp(line, "property ", 9) == 0)
        {
            // Parse property type from line and get size
            char *propertyType = NULL;
            uint32_t propertySize = 0;
            
            // Extract property type from line (format: "property <type> <name>")
            char *typeStart = strstr(line, " ");
            if (typeStart)
            {
                typeStart++; // Skip first space
                char *typeEnd = strstr(typeStart, " ");
                if (typeEnd)
                {
                    size_t typeLen = typeEnd - typeStart;
                    propertyType = tknMalloc(typeLen + 1);
                    strncpy(propertyType, typeStart, typeLen);
                    propertyType[typeLen] = '\0';
                    
                    propertySize = getPlyPropertySize(propertyType);
                    tknFree(propertyType);
                }
            }
            
            if (propertySize == 0)
            {
                tknWarning("Unsupported PLY property type in line: %s", line);
                fclose(file);
                return NULL;
            }

            if (inVertexElement)
            {
                // Check if we have more attributes to match
                if (currentAttributeIndex >= pTknMeshVertexInputLayout->attributeCount)
                {
                    tknWarning("PLY has more properties than vertex layout attributes");
                    fclose(file);
                    return NULL;
                }

                // Add this property size to current attribute
                currentAttributeBytesMatched += propertySize;

                // Check if current attribute is complete
                uint32_t expectedAttributeSize = pTknMeshVertexInputLayout->sizes[currentAttributeIndex];
                if (currentAttributeBytesMatched == expectedAttributeSize)
                {
                    // Attribute complete, move to next
                    currentAttributeIndex++;
                    currentAttributeBytesMatched = 0;
                }
                else if (currentAttributeBytesMatched > expectedAttributeSize)
                {
                    tknWarning("PLY properties exceed expected size for attribute %u: got %u bytes, expected %u bytes",
                               currentAttributeIndex, currentAttributeBytesMatched, expectedAttributeSize);
                    fclose(file);
                    return NULL;
                }
                else
                {
                    // Still matching current attribute
                }
            }
            else if (inIndexElement)
            {
                indexPropertyBytes += propertySize;
            }
        }
        else if (strcmp(line, "end_header") == 0)
        {
            break;
        }
    }

    // Check if all vertex attributes were matched completely
    if (currentAttributeIndex != pTknMeshVertexInputLayout->attributeCount || currentAttributeBytesMatched != 0)
    {
        tknWarning("PLY properties don't match vertex layout: completed %u/%u attributes, %u bytes remaining",
                   currentAttributeIndex, pTknMeshVertexInputLayout->attributeCount, currentAttributeBytesMatched);
        fclose(file);
        return NULL;
    }

    // Validate index layout
    if (indexCount > 0)
    {
        uint32_t expectedIndexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? 2 : 4;
        if (indexPropertyBytes != expectedIndexSize)
        {
            tknWarning("PLY index properties size (%u bytes) doesn't match expected index size (%u bytes)",
                       indexPropertyBytes, expectedIndexSize);
            fclose(file);
            return NULL;
        }
    }

    // Read binary data
    void *vertices = NULL;
    void *indices = NULL;

    // Read vertex data
    size_t vertexDataSize = vertexCount * pTknMeshVertexInputLayout->stride;
    if (!readBinaryData(file, &vertices, vertexDataSize, "vertex"))
    {
        fclose(file);
        return NULL;
    }

    // Read index data
    if (indexCount > 0)
    {
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        size_t indexDataSize = indexCount * indexSize;
        if (!readBinaryData(file, &indices, indexDataSize, "index"))
        {
            tknFree(vertices);
            fclose(file);
            return NULL;
        }
    }

    fclose(file);

    TknMesh *pTknMesh = createMeshPtrWithData(pTknGfxContext, pTknMeshVertexInputLayout, vertices, vertexCount, vkIndexType, indices, indexCount);

    // Clean up temporary data
    if (vertices)
    {
        tknFree(vertices);
    }
    if (indices)
    {
        tknFree(indices);
    }

    return pTknMesh;
}
void destroyMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh)
{
    tknAssert(0 == pTknMesh->drawCallPtrHashSet.count, "TknMesh still has draw calls attached!");
    tknDestroyHashSet(pTknMesh->drawCallPtrHashSet);
    tknRemoveFromHashSet(&pTknMesh->pTknVertexInputLayout->referencePtrHashSet, &pTknMesh);
    if (pTknMesh->vertexVkBuffer != VK_NULL_HANDLE && pTknMesh->vertexVkDeviceMemory != VK_NULL_HANDLE)
    {
        destroyVkBuffer(pTknGfxContext, pTknMesh->vertexVkBuffer, pTknMesh->vertexVkDeviceMemory);
    }
    if (pTknMesh->indexVkBuffer != VK_NULL_HANDLE && pTknMesh->indexVkDeviceMemory != VK_NULL_HANDLE)
    {
        destroyVkBuffer(pTknGfxContext, pTknMesh->indexVkBuffer, pTknMesh->indexVkDeviceMemory);
    }
    tknFree(pTknMesh);
}

void updateMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh, const char *format, const void *vertices, uint32_t vertexCount, uint32_t indexType, const void *indices, uint32_t indexCount)
{
    // Update vertex buffer if vertices provided
    if (vertices && vertexCount > 0)
    {
        VkDeviceSize vertexSize = vertexCount * pTknMesh->pTknVertexInputLayout->stride;
        VkDeviceSize currentVertexSize = pTknMesh->vertexCount * pTknMesh->pTknVertexInputLayout->stride;

        // Check if we need to recreate the vertex buffer
        if (pTknMesh->vertexVkBuffer == VK_NULL_HANDLE || vertexSize > currentVertexSize)
        {
            // Destroy existing buffer if it exists
            if (pTknMesh->vertexVkBuffer != VK_NULL_HANDLE)
            {
                destroyVkBuffer(pTknGfxContext, pTknMesh->vertexVkBuffer, pTknMesh->vertexVkDeviceMemory);
            }

            // Create new vertex buffer
            createVkBuffer(pTknGfxContext, vertexSize, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &pTknMesh->vertexVkBuffer, &pTknMesh->vertexVkDeviceMemory);
        }

        // Create staging buffer and copy data
        VkBuffer stagingBuffer;
        VkDeviceMemory stagingBufferMemory;
        createVkBuffer(pTknGfxContext, vertexSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &stagingBuffer, &stagingBufferMemory);

        // Copy data to staging buffer
        void *mappedData;
        VkDevice vkDevice = pTknGfxContext->vkDevice;
        vkMapMemory(vkDevice, stagingBufferMemory, 0, vertexSize, 0, &mappedData);
        memcpy(mappedData, vertices, (size_t)vertexSize);
        vkUnmapMemory(vkDevice, stagingBufferMemory);

        // Copy from staging to device local buffer
        copyVkBuffer(pTknGfxContext, stagingBuffer, pTknMesh->vertexVkBuffer, vertexSize);

        // Clean up staging buffer
        destroyVkBuffer(pTknGfxContext, stagingBuffer, stagingBufferMemory);

        // Update vertex count
        pTknMesh->vertexCount = vertexCount;
    }

    // Update index buffer if indices provided
    if (indices && indexCount > 0)
    {
        VkIndexType vkIndexType = (VkIndexType)indexType;
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        VkDeviceSize indexBufferSize = indexCount * indexSize;
        VkDeviceSize currentIndexSize = 0;
        if (pTknMesh->indexVkBuffer != VK_NULL_HANDLE)
        {
            size_t currentIndexSizePerElement = (pTknMesh->vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
            currentIndexSize = pTknMesh->indexCount * currentIndexSizePerElement;
        }

        // Check if we need to recreate the index buffer
        if (pTknMesh->indexVkBuffer == VK_NULL_HANDLE || indexBufferSize > currentIndexSize || vkIndexType != pTknMesh->vkIndexType)
        {
            // Destroy existing buffer if it exists
            if (pTknMesh->indexVkBuffer != VK_NULL_HANDLE)
            {
                destroyVkBuffer(pTknGfxContext, pTknMesh->indexVkBuffer, pTknMesh->indexVkDeviceMemory);
            }

            // Create new index buffer
            createVkBuffer(pTknGfxContext, indexBufferSize, VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &pTknMesh->indexVkBuffer, &pTknMesh->indexVkDeviceMemory);
        }

        // Create staging buffer and copy data
        VkBuffer stagingBuffer;
        VkDeviceMemory stagingBufferMemory;
        createVkBuffer(pTknGfxContext, indexBufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &stagingBuffer, &stagingBufferMemory);

        // Copy data to staging buffer
        void *mappedData;
        VkDevice vkDevice = pTknGfxContext->vkDevice;
        vkMapMemory(vkDevice, stagingBufferMemory, 0, indexBufferSize, 0, &mappedData);
        memcpy(mappedData, indices, (size_t)indexBufferSize);
        vkUnmapMemory(vkDevice, stagingBufferMemory);

        // Copy from staging to device local buffer
        copyVkBuffer(pTknGfxContext, stagingBuffer, pTknMesh->indexVkBuffer, indexBufferSize);

        // Clean up staging buffer
        destroyVkBuffer(pTknGfxContext, stagingBuffer, stagingBufferMemory);

        // Update index type and count
        pTknMesh->vkIndexType = vkIndexType;
        pTknMesh->indexCount = indexCount;
    }
}

void saveMeshPtrToPlyFile(uint32_t vertexPropertyCount, const char **vertexPropertyNames, const char **vertexPropertyTypes, TknVertexInputLayout *pTknMeshVertexInputLayout, void *vertices, uint32_t vertexCount, VkIndexType vkIndexType, void *indices, uint32_t indexCount, const char *plyFilePath)
{
    // Validate that the provided property names and types match the TknVertexInputLayout
    uint32_t propertyIndex = 0;
    for (uint32_t i = 0; i < pTknMeshVertexInputLayout->attributeCount; i++)
    {
        uint32_t expectedAttributeSize = pTknMeshVertexInputLayout->sizes[i];
        uint32_t accumulatedPropertySize = 0;
        
        // Accumulate property sizes until we match the expected attribute size
        while (accumulatedPropertySize < expectedAttributeSize)
        {
            if (propertyIndex >= vertexPropertyCount)
            {
                tknWarning("Not enough properties provided: need more properties for attribute %u", i);
                return;
            }
            
            const char *propertyType = vertexPropertyTypes[propertyIndex];
            uint32_t propertySize = getPlyPropertySize(propertyType);
            
            if (propertySize == 0)
            {
                tknWarning("Unsupported property type: %s", propertyType);
                return;
            }
            
            accumulatedPropertySize += propertySize;
            propertyIndex++;
            
            // Check if we've exceeded the expected size
            if (accumulatedPropertySize > expectedAttributeSize)
            {
                tknWarning("Property sizes exceed expected size for attribute %u: got %u bytes, expected %u bytes",
                           i, accumulatedPropertySize, expectedAttributeSize);
                return;
            }
        }
        
        // Check if we have exact match
        if (accumulatedPropertySize != expectedAttributeSize)
        {
            tknWarning("Property sizes don't match expected size for attribute %u: got %u bytes, expected %u bytes",
                       i, accumulatedPropertySize, expectedAttributeSize);
            return;
        }
    }
    
    // Check if we have used all provided properties
    if (propertyIndex != vertexPropertyCount)
    {
        tknWarning("Property count mismatch: used %u properties, but provided %u properties",
                   propertyIndex, vertexPropertyCount);
        return;
    }
    
    FILE *file = fopen(plyFilePath, "wb");
    if (!file)
    {
        tknWarning("Cannot create PLY file: %s", plyFilePath);
        return;
    }

    // Write PLY header
    fprintf(file, "ply\n");
    fprintf(file, "format binary_little_endian 1.0\n");
    
    // Write vertex element definition
    fprintf(file, "element vertex %u\n", vertexCount);
    
    // Write vertex properties
    for (uint32_t i = 0; i < vertexPropertyCount; i++)
    {
        fprintf(file, "property %s %s\n", vertexPropertyTypes[i], vertexPropertyNames[i]);
    }
    
    // Write index element definition if indices exist
    if (indexCount > 0)
    {
        fprintf(file, "element index %u\n", indexCount);
        if (vkIndexType == VK_INDEX_TYPE_UINT16)
        {
            fprintf(file, "property ushort vertex_index\n");
        }
        else // VK_INDEX_TYPE_UINT32
        {
            fprintf(file, "property uint vertex_index\n");
        }
    }
    
    // End header
    fprintf(file, "end_header\n");
    
    // Write binary vertex data
    if (vertexCount > 0)
    {
        size_t vertexDataSize = vertexCount * pTknMeshVertexInputLayout->stride;
        size_t bytesWritten = fwrite(vertices, 1, vertexDataSize, file);
        if (bytesWritten != vertexDataSize)
        {
            tknWarning("Failed to write vertex data to PLY file: expected %zu bytes, wrote %zu",
                       vertexDataSize, bytesWritten);
            fclose(file);
            return;
        }
    }
    
    // Write binary index data
    if (indexCount > 0)
    {
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        size_t indexDataSize = indexCount * indexSize;
        size_t bytesWritten = fwrite(indices, 1, indexDataSize, file);
        if (bytesWritten != indexDataSize)
        {
            tknWarning("Failed to write index data to PLY file: expected %zu bytes, wrote %zu",
                       indexDataSize, bytesWritten);
            fclose(file);
            return;
        }
    }
    
    fclose(file);
}
