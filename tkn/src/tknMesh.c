#include "tknGfxCore.h"
// #include "rply.h"

static uint32_t tknGetPlyPropertySize(const char *propertyType)
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

static bool tknReadBinaryData(FILE *file, void **data, size_t size, const char *dataType)
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

TknMesh *tknCreateMeshPtrWithPlyFile(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknMeshVertexInputLayout, VkIndexType vkIndexType, const char *plyFilePath)
{
    FILE *file = fopen(plyFilePath, "rb");
    if (!file)
    {
        tknWarning("Cannot open PLY file: %s", plyFilePath);
        return NULL;
    }

    char line[256];
    uint32_t tknVertexCount = 0;
    uint32_t tknIndexCount = 0;
    
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
                sscanf(line, "element vertex %u", &tknVertexCount);
            }
            else if (strstr(line, "index "))
            {
                sscanf(line, "element index %u", &tknIndexCount);
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
                    
                    propertySize = tknGetPlyPropertySize(propertyType);
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
                if (currentAttributeIndex >= pTknMeshVertexInputLayout->tknAttributeCount)
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
    if (currentAttributeIndex != pTknMeshVertexInputLayout->tknAttributeCount || currentAttributeBytesMatched != 0)
    {
        tknWarning("PLY properties don't match vertex layout: completed %u/%u attributes, %u bytes remaining",
                   currentAttributeIndex, pTknMeshVertexInputLayout->tknAttributeCount, currentAttributeBytesMatched);
        fclose(file);
        return NULL;
    }

    // Validate index layout
    if (tknIndexCount > 0)
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
    size_t vertexDataSize = tknVertexCount * pTknMeshVertexInputLayout->stride;
    if (!tknReadBinaryData(file, &vertices, vertexDataSize, "vertex"))
    {
        fclose(file);
        return NULL;
    }

    // Read index data
    if (tknIndexCount > 0)
    {
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        size_t indexDataSize = tknIndexCount * indexSize;
        if (!tknReadBinaryData(file, &indices, indexDataSize, "index"))
        {
            tknFree(vertices);
            fclose(file);
            return NULL;
        }
    }

    fclose(file);

    TknMesh *pTknMesh = tknCreateMeshPtrWithData(pTknGfxContext, pTknMeshVertexInputLayout, vertices, tknVertexCount, vkIndexType, indices, tknIndexCount);

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

void tknSaveMeshPtrToPlyFile(uint32_t vertexPropertyCount, const char **vertexPropertyNames, const char **vertexPropertyTypes, TknVertexInputLayout *pTknMeshVertexInputLayout, void *vertices, uint32_t tknVertexCount, VkIndexType vkIndexType, void *indices, uint32_t tknIndexCount, const char *plyFilePath)
{
    // Validate that the provided property names and types match the TknVertexInputLayout
    uint32_t propertyIndex = 0;
    for (uint32_t i = 0; i < pTknMeshVertexInputLayout->tknAttributeCount; i++)
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
            uint32_t propertySize = tknGetPlyPropertySize(propertyType);
            
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
    fprintf(file, "element vertex %u\n", tknVertexCount);
    
    // Write vertex properties
    for (uint32_t i = 0; i < vertexPropertyCount; i++)
    {
        fprintf(file, "property %s %s\n", vertexPropertyTypes[i], vertexPropertyNames[i]);
    }
    
    // Write index element definition if indices exist
    if (tknIndexCount > 0)
    {
        fprintf(file, "element index %u\n", tknIndexCount);
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
    if (tknVertexCount > 0)
    {
        size_t vertexDataSize = tknVertexCount * pTknMeshVertexInputLayout->stride;
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
    if (tknIndexCount > 0)
    {
        size_t indexSize = (vkIndexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        size_t indexDataSize = tknIndexCount * indexSize;
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
