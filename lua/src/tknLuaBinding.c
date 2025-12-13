#include "tknLuaBinding.h"
#include "tknFont.h"
#include <string.h>
#include <ft2build.h>
#include FT_FREETYPE_H
// Helper function to calculate size from layout
static VkDeviceSize calculateLayoutSize(lua_State *pLuaState, int layoutIndex)
{
    VkDeviceSize totalSize = 0;
    lua_len(pLuaState, layoutIndex);
    uint32_t fieldCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    for (uint32_t i = 0; i < fieldCount; i++)
    {
        lua_rawgeti(pLuaState, layoutIndex, i + 1);

        lua_getfield(pLuaState, -1, "type");
        uint32_t type = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "count");
        uint32_t count = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        uint32_t typeSize = 0;
        if (type == TYPE_UINT8)
            typeSize = 1;
        else if (type == TYPE_UINT16)
            typeSize = 2;
        else if (type == TYPE_UINT32)
            typeSize = 4;
        else if (type == TYPE_UINT64)
            typeSize = 8;
        else if (type == TYPE_INT8)
            typeSize = 1;
        else if (type == TYPE_INT16)
            typeSize = 2;
        else if (type == TYPE_INT32)
            typeSize = 4;
        else if (type == TYPE_INT64)
            typeSize = 8;
        else if (type == TYPE_FLOAT)
            typeSize = 4;
        else if (type == TYPE_DOUBLE)
            typeSize = 8;
        else
        {
            typeSize = 4; // default
        }

        totalSize += typeSize * count;
        lua_pop(pLuaState, 1);
    }

    return totalSize;
}

// Helper function to pack data from Lua table according to layout
static void *packDataFromLayout(lua_State *pLuaState, int layoutIndex, int dataIndex, VkDeviceSize *outSize)
{
    // Convert negative indices to absolute indices to avoid stack changes affecting them
    int absoluteLayoutIndex = lua_absindex(pLuaState, layoutIndex);
    int absoluteDataIndex = lua_absindex(pLuaState, dataIndex);

    VkDeviceSize singleVertexSize = calculateLayoutSize(pLuaState, absoluteLayoutIndex);

    // Calculate vertex count by checking the first field's array length
    uint32_t vertexCount = 0;
    lua_len(pLuaState, absoluteLayoutIndex);
    uint32_t fieldCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    if (fieldCount > 0)
    {
        // Get first field info
        lua_rawgeti(pLuaState, absoluteLayoutIndex, 1);
        lua_getfield(pLuaState, -1, "name");
        const char *firstFieldName = lua_tostring(pLuaState, -1);
        lua_pop(pLuaState, 1);
        lua_getfield(pLuaState, -1, "count");
        uint32_t firstFieldCount = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 2);

        // Get first field data to determine vertex count
        lua_getfield(pLuaState, absoluteDataIndex, firstFieldName);
        if (lua_istable(pLuaState, -1))
        {
            lua_len(pLuaState, -1);
            uint32_t arrayLength = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
            vertexCount = arrayLength / firstFieldCount;
        }
        lua_pop(pLuaState, 1);
    }

    VkDeviceSize totalSize = singleVertexSize * vertexCount;
    void *data = tknMalloc(totalSize);
    uint8_t *dataPtr = (uint8_t *)data;

    lua_len(pLuaState, absoluteLayoutIndex);
    fieldCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    // Pack data for each vertex
    for (uint32_t vertexIdx = 0; vertexIdx < vertexCount; vertexIdx++)
    {
        for (uint32_t i = 0; i < fieldCount; i++)
        {
            lua_rawgeti(pLuaState, absoluteLayoutIndex, i + 1);

            lua_getfield(pLuaState, -1, "name");
            const char *fieldName = lua_tostring(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "type");
            uint32_t type = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "count");
            uint32_t count = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            // Get data for this field
            lua_getfield(pLuaState, absoluteDataIndex, fieldName);
            if (!lua_isnil(pLuaState, -1))
            {
                if (lua_istable(pLuaState, -1))
                {
                    // Array data - get data for current vertex
                    for (uint32_t j = 0; j < count; j++)
                    {
                        uint32_t dataIndex = vertexIdx * count + j + 1; // Lua arrays are 1-indexed
                        lua_rawgeti(pLuaState, -1, dataIndex);
                        if (type == TYPE_UINT8 || type == TYPE_INT8)
                        {
                            uint8_t value = (uint8_t)lua_tointeger(pLuaState, -1);
                            memcpy(dataPtr, &value, 1);
                            dataPtr += 1;
                        }
                        else if (type == TYPE_UINT16 || type == TYPE_INT16)
                        {
                            uint16_t value = (uint16_t)lua_tointeger(pLuaState, -1);
                            memcpy(dataPtr, &value, 2);
                            dataPtr += 2;
                        }
                        else if (type == TYPE_UINT32 || type == TYPE_INT32)
                        {
                            uint32_t value = (uint32_t)lua_tointeger(pLuaState, -1);
                            memcpy(dataPtr, &value, 4);
                            dataPtr += 4;
                        }
                        else if (type == TYPE_UINT64 || type == TYPE_INT64)
                        {
                            uint64_t value = (uint64_t)lua_tointeger(pLuaState, -1);
                            memcpy(dataPtr, &value, 8);
                            dataPtr += 8;
                        }
                        else if (type == TYPE_FLOAT)
                        {
                            float value = (float)lua_tonumber(pLuaState, -1);
                            memcpy(dataPtr, &value, 4);
                            dataPtr += 4;
                        }
                        else if (type == TYPE_DOUBLE)
                        {
                            double value = (double)lua_tonumber(pLuaState, -1);
                            memcpy(dataPtr, &value, 8);
                            dataPtr += 8;
                        }
                        lua_pop(pLuaState, 1);
                    }
                }
                else
                {
                    // Single value - repeat for each vertex
                    if (type == TYPE_FLOAT)
                    {
                        float value = (float)lua_tonumber(pLuaState, -1);
                        memcpy(dataPtr, &value, 4);
                        dataPtr += 4;
                    }
                    else
                    {
                        uint32_t value = (uint32_t)lua_tointeger(pLuaState, -1);
                        memcpy(dataPtr, &value, 4);
                        dataPtr += 4;
                    }
                }
            }
            lua_pop(pLuaState, 1); // pop field data
            lua_pop(pLuaState, 1); // pop layout entry
        }
    }
    *outSize = totalSize;
    return data;
}

static int luaGetSupportedFormat(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -4);

    // candidates table is at position -3
    lua_len(pLuaState, -3);
    uint32_t candidateCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    VkFormat *candidates = tknMalloc(sizeof(VkFormat) * candidateCount);
    for (uint32_t i = 0; i < candidateCount; i++)
    {
        lua_rawgeti(pLuaState, -3, i + 1);
        candidates[i] = (VkFormat)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);
    }
    VkImageTiling tiling = (VkImageTiling)lua_tointeger(pLuaState, -2);
    VkFormatFeatureFlags features = (VkFormatFeatureFlags)lua_tointeger(pLuaState, -1);
    VkFormat supportedFormat = tknGetSupportedFormat(pTknGfxContext, candidateCount, candidates, tiling, features);
    tknFree(candidates);
    lua_pushinteger(pLuaState, (lua_Integer)supportedFormat);
    return 1;
}
static int luaCreateDynamicAttachmentPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -5);
    VkFormat vkFormat = (VkFormat)lua_tointeger(pLuaState, -4);
    VkImageUsageFlags vkImageUsageFlags = (VkImageUsageFlags)lua_tointeger(pLuaState, -3);
    VkImageAspectFlags vkImageAspectFlags = (VkImageAspectFlags)lua_tointeger(pLuaState, -2);
    float scaler = (float)lua_tonumber(pLuaState, -1);
    TknAttachment *pTknAttachment = tknCreateDynamicAttachmentPtr(pTknGfxContext, vkFormat, vkImageUsageFlags, vkImageAspectFlags, scaler);
    lua_pushlightuserdata(pLuaState, pTknAttachment);
    return 1;
}

static int luaCreateFixedAttachmentPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -6);
    VkFormat vkFormat = (VkFormat)lua_tointeger(pLuaState, -5);
    VkImageUsageFlags vkImageUsageFlags = (VkImageUsageFlags)lua_tointeger(pLuaState, -4);
    VkImageAspectFlags vkImageAspectFlags = (VkImageAspectFlags)lua_tointeger(pLuaState, -3);
    uint32_t width = (uint32_t)lua_tointeger(pLuaState, -2);
    uint32_t height = (uint32_t)lua_tointeger(pLuaState, -1);
    TknAttachment *pTknAttachment = tknCreateFixedAttachmentPtr(pTknGfxContext, vkFormat, vkImageUsageFlags, vkImageAspectFlags, width, height);
    lua_pushlightuserdata(pLuaState, pTknAttachment);
    return 1;
}

static int luaGetSwapchainAttachmentPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -1);
    TknAttachment *pTknAttachment = tknGetSwapchainAttachmentPtr(pTknGfxContext);
    lua_pushlightuserdata(pLuaState, pTknAttachment);
    return 1;
}

static int luaDestroyDynamicAttachmentPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknAttachment *pTknAttachment = (TknAttachment *)lua_touserdata(pLuaState, -1);
    tknDestroyDynamicAttachmentPtr(pTknGfxContext, pTknAttachment);
    return 0;
}

static int luaDestroyFixedAttachmentPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknAttachment *pTknAttachment = (TknAttachment *)lua_touserdata(pLuaState, -1);
    tknDestroyFixedAttachmentPtr(pTknGfxContext, pTknAttachment);
    return 0;
}

static int luaCreateRenderPassPtr(lua_State *pLuaState)
{
    // Get parameters from Lua stack
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -8);

    // Get VkAttachmentDescription array
    lua_len(pLuaState, -7);
    uint32_t attachmentCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);
    VkAttachmentDescription *vkAttachmentDescriptions = tknMalloc(sizeof(VkAttachmentDescription) * attachmentCount);
    for (uint32_t i = 0; i < attachmentCount; i++)
    {
        lua_rawgeti(pLuaState, -7, i + 1);
        VkAttachmentDescription attachmentDescription = {0};

        lua_getfield(pLuaState, -1, "flags");
        attachmentDescription.flags = lua_isnil(pLuaState, -1) ? 0 : (VkAttachmentDescriptionFlags)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "format");
        attachmentDescription.format = lua_isnil(pLuaState, -1) ? VK_FORMAT_UNDEFINED : (VkFormat)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "samples");
        attachmentDescription.samples = (VkSampleCountFlagBits)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "loadOp");
        attachmentDescription.loadOp = (VkAttachmentLoadOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "storeOp");
        attachmentDescription.storeOp = (VkAttachmentStoreOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "stencilLoadOp");
        attachmentDescription.stencilLoadOp = (VkAttachmentLoadOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "stencilStoreOp");
        attachmentDescription.stencilStoreOp = (VkAttachmentStoreOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "initialLayout");
        attachmentDescription.initialLayout = (VkImageLayout)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "finalLayout");
        attachmentDescription.finalLayout = (VkImageLayout)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        vkAttachmentDescriptions[i] = attachmentDescription;
        lua_pop(pLuaState, 1);
    }

    // Get inputAttachmentPtrs array
    lua_len(pLuaState, -6);
    uint32_t inputAttachmentCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);
    TknAttachment **inputAttachmentPtrs = tknMalloc(sizeof(TknAttachment *) * inputAttachmentCount);
    for (uint32_t i = 0; i < inputAttachmentCount; i++)
    {
        lua_rawgeti(pLuaState, -6, i + 1);
        inputAttachmentPtrs[i] = (TknAttachment *)lua_touserdata(pLuaState, -1);
        lua_pop(pLuaState, 1);
    }

    // Get VkClearValue array
    lua_len(pLuaState, -5);
    uint32_t clearValueCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);
    VkClearValue *vkClearValues = tknMalloc(sizeof(VkClearValue) * clearValueCount);
    for (uint32_t i = 0; i < clearValueCount; i++)
    {
        lua_rawgeti(pLuaState, -5, i + 1);
        VkClearValue clearValue = {0};

        // Check if it's a depth/stencil clear value (has depth field)
        lua_getfield(pLuaState, -1, "depth");
        if (!lua_isnil(pLuaState, -1))
        {
            // This is a depth/stencil clear value
            clearValue.depthStencil.depth = (float)lua_tonumber(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "stencil");
            clearValue.depthStencil.stencil = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
        }
        else
        {
            // This is a color clear value (array of 4 floats)
            lua_pop(pLuaState, 1);
            for (uint32_t j = 0; j < 4; j++)
            {
                lua_rawgeti(pLuaState, -1, j + 1);
                clearValue.color.float32[j] = (float)lua_tonumber(pLuaState, -1);
                lua_pop(pLuaState, 1);
            }
        }

        vkClearValues[i] = clearValue;
        lua_pop(pLuaState, 1);
    }

    // Get VkSubpassDescription array
    lua_len(pLuaState, -4);
    uint32_t subpassCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);
    VkSubpassDescription *vkSubpassDescriptions = tknMalloc(sizeof(VkSubpassDescription) * subpassCount);
    for (uint32_t i = 0; i < subpassCount; i++)
    {
        lua_rawgeti(pLuaState, -4, i + 1);
        VkSubpassDescription subpassDescription = {0};

        lua_getfield(pLuaState, -1, "pipelineBindPoint");
        subpassDescription.pipelineBindPoint = (VkPipelineBindPoint)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        // Handle pInputAttachments
        lua_getfield(pLuaState, -1, "pInputAttachments");
        lua_len(pLuaState, -1);
        subpassDescription.inputAttachmentCount = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);
        if (subpassDescription.inputAttachmentCount > 0)
        {
            VkAttachmentReference *pInputAttachments = tknMalloc(sizeof(VkAttachmentReference) * subpassDescription.inputAttachmentCount);
            for (uint32_t j = 0; j < subpassDescription.inputAttachmentCount; j++)
            {
                lua_rawgeti(pLuaState, -1, j + 1);
                lua_getfield(pLuaState, -1, "attachment");
                pInputAttachments[j].attachment = (uint32_t)lua_tointeger(pLuaState, -1);
                lua_pop(pLuaState, 1);
                lua_getfield(pLuaState, -1, "layout");
                pInputAttachments[j].layout = (VkImageLayout)lua_tointeger(pLuaState, -1);
                lua_pop(pLuaState, 2);
            }
            subpassDescription.pInputAttachments = pInputAttachments;
        }
        lua_pop(pLuaState, 1);

        // Handle pColorAttachments
        lua_getfield(pLuaState, -1, "pColorAttachments");
        lua_len(pLuaState, -1);
        subpassDescription.colorAttachmentCount = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);
        if (subpassDescription.colorAttachmentCount > 0)
        {
            VkAttachmentReference *pColorAttachments = tknMalloc(sizeof(VkAttachmentReference) * subpassDescription.colorAttachmentCount);
            for (uint32_t j = 0; j < subpassDescription.colorAttachmentCount; j++)
            {
                lua_rawgeti(pLuaState, -1, j + 1);
                lua_getfield(pLuaState, -1, "attachment");
                pColorAttachments[j].attachment = (uint32_t)lua_tointeger(pLuaState, -1);
                lua_pop(pLuaState, 1);
                lua_getfield(pLuaState, -1, "layout");
                pColorAttachments[j].layout = (VkImageLayout)lua_tointeger(pLuaState, -1);
                lua_pop(pLuaState, 2);
            }
            subpassDescription.pColorAttachments = pColorAttachments;
        }
        lua_pop(pLuaState, 1);

        // Handle pDepthStencilAttachment
        lua_getfield(pLuaState, -1, "pDepthStencilAttachment");
        if (!lua_isnil(pLuaState, -1))
        {
            VkAttachmentReference *pDepthStencilAttachment = tknMalloc(sizeof(VkAttachmentReference));
            lua_getfield(pLuaState, -1, "attachment");
            pDepthStencilAttachment->attachment = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
            lua_getfield(pLuaState, -1, "layout");
            pDepthStencilAttachment->layout = (VkImageLayout)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
            subpassDescription.pDepthStencilAttachment = pDepthStencilAttachment;
        }
        lua_pop(pLuaState, 1);

        vkSubpassDescriptions[i] = subpassDescription;
        lua_pop(pLuaState, 1);
    }

    // Get spvPaths array (2D array)
    lua_len(pLuaState, -3);
    uint32_t spvPathsArrayCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);
    uint32_t *spvPathCounts = tknMalloc(sizeof(uint32_t) * spvPathsArrayCount);
    const char ***spvPathsArray = tknMalloc(sizeof(const char **) * spvPathsArrayCount);
    for (uint32_t i = 0; i < spvPathsArrayCount; i++)
    {
        lua_rawgeti(pLuaState, -3, i + 1);
        lua_len(pLuaState, -1);
        spvPathCounts[i] = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        const char **spvPaths = tknMalloc(sizeof(const char *) * spvPathCounts[i]);
        for (uint32_t j = 0; j < spvPathCounts[i]; j++)
        {
            lua_rawgeti(pLuaState, -1, j + 1);
            spvPaths[j] = lua_tostring(pLuaState, -1);
            lua_pop(pLuaState, 1);
        }
        spvPathsArray[i] = spvPaths;
        lua_pop(pLuaState, 1);
    }

    // Get VkSubpassDependency array
    lua_len(pLuaState, -2);
    uint32_t vkSubpassDependencyCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);
    VkSubpassDependency *vkSubpassDependencies = NULL;
    if (vkSubpassDependencyCount > 0)
    {
        vkSubpassDependencies = tknMalloc(sizeof(VkSubpassDependency) * vkSubpassDependencyCount);
        for (uint32_t i = 0; i < vkSubpassDependencyCount; i++)
        {
            lua_rawgeti(pLuaState, -2, i + 1);
            VkSubpassDependency subpassDependency = {0};

            lua_getfield(pLuaState, -1, "srcSubpass");
            subpassDependency.srcSubpass = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "dstSubpass");
            subpassDependency.dstSubpass = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "srcStageMask");
            subpassDependency.srcStageMask = (VkPipelineStageFlags)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "dstStageMask");
            subpassDependency.dstStageMask = (VkPipelineStageFlags)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "srcAccessMask");
            subpassDependency.srcAccessMask = (VkAccessFlags)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "dstAccessMask");
            subpassDependency.dstAccessMask = (VkAccessFlags)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "dependencyFlags");
            subpassDependency.dependencyFlags = (VkDependencyFlags)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            vkSubpassDependencies[i] = subpassDependency;
            lua_pop(pLuaState, 1);
        }
    }
    uint32_t renderPassIndex = (uint32_t)lua_tointeger(pLuaState, -1);
    // Call the C function
    TknRenderPass *pTknRenderPass = tknCreateRenderPassPtr(pTknGfxContext, attachmentCount, vkAttachmentDescriptions,
                                                  inputAttachmentPtrs, vkClearValues, subpassCount, vkSubpassDescriptions,
                                                  spvPathCounts, spvPathsArray, vkSubpassDependencyCount,
                                                  vkSubpassDependencies, renderPassIndex);

    // Clean up memory
    tknFree(vkAttachmentDescriptions);
    tknFree(inputAttachmentPtrs);
    tknFree(vkClearValues);

    for (uint32_t i = 0; i < subpassCount; i++)
    {
        if (vkSubpassDescriptions[i].pInputAttachments)
            tknFree((void *)vkSubpassDescriptions[i].pInputAttachments);
        if (vkSubpassDescriptions[i].pColorAttachments)
            tknFree((void *)vkSubpassDescriptions[i].pColorAttachments);
        if (vkSubpassDescriptions[i].pDepthStencilAttachment)
            tknFree((void *)vkSubpassDescriptions[i].pDepthStencilAttachment);
    }
    tknFree(vkSubpassDescriptions);

    for (uint32_t i = 0; i < spvPathsArrayCount; i++)
    {
        tknFree(spvPathsArray[i]);
    }
    tknFree(spvPathCounts);
    tknFree(spvPathsArray);

    if (vkSubpassDependencies)
        tknFree(vkSubpassDependencies);

    // Return TknRenderPass as userdata
    lua_pushlightuserdata(pLuaState, pTknRenderPass);
    return 1;
}

static int luaDestroyRenderPassPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknRenderPass *pTknRenderPass = (TknRenderPass *)lua_touserdata(pLuaState, -1);
    tknDestroyRenderPassPtr(pTknGfxContext, pTknRenderPass);
    return 0;
}

static int luaCreatePipelinePtr(lua_State *pLuaState)
{
    // Get parameters from Lua stack (13 parameters total)
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -13);
    TknRenderPass *pTknRenderPass = (TknRenderPass *)lua_touserdata(pLuaState, -12);
    uint32_t subpassIndex = (uint32_t)lua_tointeger(pLuaState, -11);

    // Get spvPaths array (parameter 4 at index -10)
    lua_len(pLuaState, -10);
    uint32_t spvPathCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);
    const char **spvPaths = tknMalloc(sizeof(const char *) * spvPathCount);
    for (uint32_t i = 0; i < spvPathCount; i++)
    {
        lua_rawgeti(pLuaState, -10, i + 1);
        spvPaths[i] = lua_tostring(pLuaState, -1);
        lua_pop(pLuaState, 1);
    }
    // Get vertexAttributeDescriptions (parameter 5 at index -9)
    TknVertexInputLayout *pTknMeshVertexInputLayout = lua_touserdata(pLuaState, -9);

    // Get instanceAttributeDescriptions (parameter 6 at index -8)
    TknVertexInputLayout *pTknInstanceVertexInputLayout = lua_touserdata(pLuaState, -8);

    // Parse VkPipelineInputAssemblyStateCreateInfo (parameter 6 at index -7)
    VkPipelineInputAssemblyStateCreateInfo vkPipelineInputAssemblyStateCreateInfo = {0};
    vkPipelineInputAssemblyStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;

    lua_getfield(pLuaState, -7, "topology");
    vkPipelineInputAssemblyStateCreateInfo.topology = (VkPrimitiveTopology)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -7, "primitiveRestartEnable");
    vkPipelineInputAssemblyStateCreateInfo.primitiveRestartEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    // Parse VkPipelineViewportStateCreateInfo (parameter 7 at index -6)
    VkPipelineViewportStateCreateInfo vkPipelineViewportStateCreateInfo = {0};
    vkPipelineViewportStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;

    // Get viewports
    lua_getfield(pLuaState, -6, "pViewports");
    lua_len(pLuaState, -1);
    vkPipelineViewportStateCreateInfo.viewportCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    VkViewport *pViewports = NULL;
    if (vkPipelineViewportStateCreateInfo.viewportCount > 0)
    {
        pViewports = tknMalloc(sizeof(VkViewport) * vkPipelineViewportStateCreateInfo.viewportCount);
        for (uint32_t i = 0; i < vkPipelineViewportStateCreateInfo.viewportCount; i++)
        {
            lua_rawgeti(pLuaState, -1, i + 1);

            lua_getfield(pLuaState, -1, "x");
            pViewports[i].x = (float)lua_tonumber(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "y");
            pViewports[i].y = (float)lua_tonumber(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "width");
            pViewports[i].width = (float)lua_tonumber(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "height");
            pViewports[i].height = (float)lua_tonumber(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "minDepth");
            pViewports[i].minDepth = (float)lua_tonumber(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "maxDepth");
            pViewports[i].maxDepth = (float)lua_tonumber(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_pop(pLuaState, 1); // Pop viewport table
        }
    }
    vkPipelineViewportStateCreateInfo.pViewports = pViewports;
    lua_pop(pLuaState, 1); // Pop pViewports

    // Get scissors
    lua_getfield(pLuaState, -6, "pScissors");
    lua_len(pLuaState, -1);
    vkPipelineViewportStateCreateInfo.scissorCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    VkRect2D *pScissors = NULL;
    if (vkPipelineViewportStateCreateInfo.scissorCount > 0)
    {
        pScissors = tknMalloc(sizeof(VkRect2D) * vkPipelineViewportStateCreateInfo.scissorCount);
        for (uint32_t i = 0; i < vkPipelineViewportStateCreateInfo.scissorCount; i++)
        {
            lua_rawgeti(pLuaState, -1, i + 1);

            lua_getfield(pLuaState, -1, "offset");
            lua_rawgeti(pLuaState, -1, 1);
            pScissors[i].offset.x = (int32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
            lua_rawgeti(pLuaState, -1, 2);
            pScissors[i].offset.y = (int32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 2); // Pop y and offset

            lua_getfield(pLuaState, -1, "extent");
            lua_rawgeti(pLuaState, -1, 1);
            pScissors[i].extent.width = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
            lua_rawgeti(pLuaState, -1, 2);
            pScissors[i].extent.height = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 2); // Pop height and extent

            lua_pop(pLuaState, 1); // Pop scissor table
        }
    }
    vkPipelineViewportStateCreateInfo.pScissors = pScissors;
    lua_pop(pLuaState, 1); // Pop pScissors

    // Parse VkPipelineRasterizationStateCreateInfo (parameter 8 at index -5)
    VkPipelineRasterizationStateCreateInfo vkPipelineRasterizationStateCreateInfo = {0};
    vkPipelineRasterizationStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;

    lua_getfield(pLuaState, -5, "depthClampEnable");
    vkPipelineRasterizationStateCreateInfo.depthClampEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "rasterizerDiscardEnable");
    vkPipelineRasterizationStateCreateInfo.rasterizerDiscardEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "polygonMode");
    vkPipelineRasterizationStateCreateInfo.polygonMode = (VkPolygonMode)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "cullMode");
    vkPipelineRasterizationStateCreateInfo.cullMode = (VkCullModeFlags)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "frontFace");
    vkPipelineRasterizationStateCreateInfo.frontFace = (VkFrontFace)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "depthBiasEnable");
    vkPipelineRasterizationStateCreateInfo.depthBiasEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "depthBiasConstantFactor");
    vkPipelineRasterizationStateCreateInfo.depthBiasConstantFactor = (float)lua_tonumber(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "depthBiasClamp");
    vkPipelineRasterizationStateCreateInfo.depthBiasClamp = (float)lua_tonumber(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "depthBiasSlopeFactor");
    vkPipelineRasterizationStateCreateInfo.depthBiasSlopeFactor = (float)lua_tonumber(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -5, "lineWidth");
    vkPipelineRasterizationStateCreateInfo.lineWidth = (float)lua_tonumber(pLuaState, -1);
    lua_pop(pLuaState, 1);

    // Parse VkPipelineMultisampleStateCreateInfo (parameter 9 at index -4)
    VkPipelineMultisampleStateCreateInfo vkPipelineMultisampleStateCreateInfo = {0};
    vkPipelineMultisampleStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;

    lua_getfield(pLuaState, -4, "rasterizationSamples");
    vkPipelineMultisampleStateCreateInfo.rasterizationSamples = (VkSampleCountFlagBits)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -4, "sampleShadingEnable");
    vkPipelineMultisampleStateCreateInfo.sampleShadingEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -4, "minSampleShading");
    vkPipelineMultisampleStateCreateInfo.minSampleShading = (float)lua_tonumber(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -4, "alphaToCoverageEnable");
    vkPipelineMultisampleStateCreateInfo.alphaToCoverageEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -4, "alphaToOneEnable");
    vkPipelineMultisampleStateCreateInfo.alphaToOneEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    // Handle pSampleMask array
    VkSampleMask *pSampleMask;
    lua_getfield(pLuaState, -4, "pSampleMask");
    if (lua_isnil(pLuaState, -1))
    {
        pSampleMask = NULL;
    }
    else
    {
        lua_len(pLuaState, -1);
        uint32_t sampleMaskCount = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        if (sampleMaskCount > 0)
        {
            pSampleMask = tknMalloc(sizeof(VkSampleMask) * sampleMaskCount);
            for (uint32_t i = 0; i < sampleMaskCount; i++)
            {
                lua_rawgeti(pLuaState, -1, i + 1);
                pSampleMask[i] = (VkSampleMask)lua_tointeger(pLuaState, -1);
                lua_pop(pLuaState, 1);
            }
            vkPipelineMultisampleStateCreateInfo.pSampleMask = pSampleMask;
        }
    }
    lua_pop(pLuaState, 1);

    // Parse VkPipelineDepthStencilStateCreateInfo (parameter 10 at index -3)
    VkPipelineDepthStencilStateCreateInfo vkPipelineDepthStencilStateCreateInfo = {0};
    vkPipelineDepthStencilStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;

    lua_getfield(pLuaState, -3, "depthTestEnable");
    vkPipelineDepthStencilStateCreateInfo.depthTestEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -3, "depthWriteEnable");
    vkPipelineDepthStencilStateCreateInfo.depthWriteEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -3, "depthCompareOp");
    vkPipelineDepthStencilStateCreateInfo.depthCompareOp = (VkCompareOp)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -3, "depthBoundsTestEnable");
    vkPipelineDepthStencilStateCreateInfo.depthBoundsTestEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -3, "stencilTestEnable");
    vkPipelineDepthStencilStateCreateInfo.stencilTestEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);
    if (vkPipelineDepthStencilStateCreateInfo.stencilTestEnable)
    {
        // Handle front stencil state
        lua_getfield(pLuaState, -3, "front");
        lua_getfield(pLuaState, -1, "failOp");
        vkPipelineDepthStencilStateCreateInfo.front.failOp = (VkStencilOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "passOp");
        vkPipelineDepthStencilStateCreateInfo.front.passOp = (VkStencilOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "depthFailOp");
        vkPipelineDepthStencilStateCreateInfo.front.depthFailOp = (VkStencilOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "compareOp");
        vkPipelineDepthStencilStateCreateInfo.front.compareOp = (VkCompareOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "compareMask");
        vkPipelineDepthStencilStateCreateInfo.front.compareMask = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "writeMask");
        vkPipelineDepthStencilStateCreateInfo.front.writeMask = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "reference");
        vkPipelineDepthStencilStateCreateInfo.front.reference = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 2); // Pop reference and front

        // Handle back stencil state
        lua_getfield(pLuaState, -3, "back");
        lua_getfield(pLuaState, -1, "failOp");
        vkPipelineDepthStencilStateCreateInfo.back.failOp = (VkStencilOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "passOp");
        vkPipelineDepthStencilStateCreateInfo.back.passOp = (VkStencilOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "depthFailOp");
        vkPipelineDepthStencilStateCreateInfo.back.depthFailOp = (VkStencilOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "compareOp");
        vkPipelineDepthStencilStateCreateInfo.back.compareOp = (VkCompareOp)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "compareMask");
        vkPipelineDepthStencilStateCreateInfo.back.compareMask = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "writeMask");
        vkPipelineDepthStencilStateCreateInfo.back.writeMask = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "reference");
        vkPipelineDepthStencilStateCreateInfo.back.reference = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 2); // Pop reference and back
    }
    else
    {
        vkPipelineDepthStencilStateCreateInfo.front = (VkStencilOpState){0};
        vkPipelineDepthStencilStateCreateInfo.back = (VkStencilOpState){0};
    }

    lua_getfield(pLuaState, -3, "minDepthBounds");
    vkPipelineDepthStencilStateCreateInfo.minDepthBounds = (float)lua_tonumber(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -3, "maxDepthBounds");
    vkPipelineDepthStencilStateCreateInfo.maxDepthBounds = (float)lua_tonumber(pLuaState, -1);
    lua_pop(pLuaState, 1);

    // Parse VkPipelineColorBlendStateCreateInfo (parameter 11 at index -2)
    VkPipelineColorBlendStateCreateInfo vkPipelineColorBlendStateCreateInfo = {0};
    vkPipelineColorBlendStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;

    lua_getfield(pLuaState, -2, "logicOpEnable");
    vkPipelineColorBlendStateCreateInfo.logicOpEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -2, "logicOp");
    vkPipelineColorBlendStateCreateInfo.logicOp = (VkLogicOp)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    // Get attachments
    lua_getfield(pLuaState, -2, "pAttachments");
    lua_len(pLuaState, -1);
    vkPipelineColorBlendStateCreateInfo.attachmentCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    VkPipelineColorBlendAttachmentState *pColorBlendAttachments = NULL;
    if (vkPipelineColorBlendStateCreateInfo.attachmentCount > 0)
    {
        pColorBlendAttachments = tknMalloc(sizeof(VkPipelineColorBlendAttachmentState) * vkPipelineColorBlendStateCreateInfo.attachmentCount);
        for (uint32_t i = 0; i < vkPipelineColorBlendStateCreateInfo.attachmentCount; i++)
        {
            lua_rawgeti(pLuaState, -1, i + 1);

            lua_getfield(pLuaState, -1, "blendEnable");
            pColorBlendAttachments[i].blendEnable = lua_toboolean(pLuaState, -1) ? VK_TRUE : VK_FALSE;
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "srcColorBlendFactor");
            pColorBlendAttachments[i].srcColorBlendFactor = (VkBlendFactor)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "dstColorBlendFactor");
            pColorBlendAttachments[i].dstColorBlendFactor = (VkBlendFactor)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "colorBlendOp");
            pColorBlendAttachments[i].colorBlendOp = (VkBlendOp)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "srcAlphaBlendFactor");
            pColorBlendAttachments[i].srcAlphaBlendFactor = (VkBlendFactor)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "dstAlphaBlendFactor");
            pColorBlendAttachments[i].dstAlphaBlendFactor = (VkBlendFactor)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "alphaBlendOp");
            pColorBlendAttachments[i].alphaBlendOp = (VkBlendOp)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_getfield(pLuaState, -1, "colorWriteMask");
            pColorBlendAttachments[i].colorWriteMask = (VkColorComponentFlags)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);

            lua_pop(pLuaState, 1); // Pop attachment table
        }
    }
    vkPipelineColorBlendStateCreateInfo.pAttachments = pColorBlendAttachments;
    lua_pop(pLuaState, 1); // Pop pAttachments

    // Get blend constants
    lua_getfield(pLuaState, -2, "blendConstants");
    for (int i = 0; i < 4; i++)
    {
        lua_rawgeti(pLuaState, -1, i + 1);
        vkPipelineColorBlendStateCreateInfo.blendConstants[i] = (float)lua_tonumber(pLuaState, -1);
        lua_pop(pLuaState, 1);
    }
    lua_pop(pLuaState, 1); // Pop blendConstants

    // Parse VkPipelineDynamicStateCreateInfo (parameter 12 at index -1)
    VkPipelineDynamicStateCreateInfo vkPipelineDynamicStateCreateInfo = {0};
    vkPipelineDynamicStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;

    lua_getfield(pLuaState, -1, "pDynamicStates");
    lua_len(pLuaState, -1);
    vkPipelineDynamicStateCreateInfo.dynamicStateCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    VkDynamicState *pDynamicStates = NULL;
    if (vkPipelineDynamicStateCreateInfo.dynamicStateCount > 0)
    {
        pDynamicStates = tknMalloc(sizeof(VkDynamicState) * vkPipelineDynamicStateCreateInfo.dynamicStateCount);
        for (uint32_t i = 0; i < vkPipelineDynamicStateCreateInfo.dynamicStateCount; i++)
        {
            lua_rawgeti(pLuaState, -1, i + 1);
            pDynamicStates[i] = (VkDynamicState)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
        }
    }
    vkPipelineDynamicStateCreateInfo.pDynamicStates = pDynamicStates;
    lua_pop(pLuaState, 1); // Pop pDynamicStates

    // Call the C function
    TknPipeline *pTknPipeline = tknCreatePipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, spvPathCount, spvPaths,
                                            pTknMeshVertexInputLayout,
                                            pTknInstanceVertexInputLayout,
                                            vkPipelineInputAssemblyStateCreateInfo,
                                            vkPipelineViewportStateCreateInfo,
                                            vkPipelineRasterizationStateCreateInfo,
                                            vkPipelineMultisampleStateCreateInfo,
                                            vkPipelineDepthStencilStateCreateInfo,
                                            vkPipelineColorBlendStateCreateInfo,
                                            vkPipelineDynamicStateCreateInfo);

    // Clean up memory
    tknFree(spvPaths);
    tknFree(pViewports);
    tknFree(pScissors);
    tknFree(pSampleMask);
    tknFree(pColorBlendAttachments);
    tknFree(pDynamicStates);

    // Return TknPipeline as userdata
    lua_pushlightuserdata(pLuaState, pTknPipeline);
    return 1;
}

static int luaDestroyPipelinePtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknPipeline *pTknPipeline = (TknPipeline *)lua_touserdata(pLuaState, -1);
    tknDestroyPipelinePtr(pTknGfxContext, pTknPipeline);
    return 0;
}

static int luaCreateDrawCallPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -5);
    TknPipeline *pTknPipeline = (TknPipeline *)lua_touserdata(pLuaState, -4);
    TknMaterial *pTknMaterial = (TknMaterial *)lua_touserdata(pLuaState, -3);
    TknMesh *pTknMesh = (TknMesh *)lua_touserdata(pLuaState, -2);
    TknInstance *pTknInstance = (TknInstance *)lua_touserdata(pLuaState, -1);
    TknDrawCall *pTknDrawCall = tknCreateDrawCallPtr(pTknGfxContext, pTknPipeline, pTknMaterial, pTknMesh, pTknInstance);
    lua_pushlightuserdata(pLuaState, pTknDrawCall);
    return 1;
}

static int luaDestroyDrawCallPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknDrawCall *pTknDrawCall = (TknDrawCall *)lua_touserdata(pLuaState, -1);
    tknDestroyDrawCallPtr(pTknGfxContext, pTknDrawCall);
    return 0;
}

static int luaInsertDrawCallPtr(lua_State *pLuaState)
{
    TknDrawCall *pTknDrawCall = (TknDrawCall *)lua_touserdata(pLuaState, -2);
    uint32_t index = (uint32_t)lua_tointeger(pLuaState, -1);
    tknInsertDrawCallPtr(pTknDrawCall, index);
    return 0;
}

static int luaRemoveDrawCallPtr(lua_State *pLuaState)
{
    TknDrawCall *pTknDrawCall = (TknDrawCall *)lua_touserdata(pLuaState, -1);
    tknRemoveDrawCallPtr(pTknDrawCall);
    return 0;
}

static int luaCreateVertexInputLayoutPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);

    // Get layout array
    lua_len(pLuaState, -1);
    uint32_t attributeCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    const char **names = tknMalloc(sizeof(char *) * attributeCount);
    uint32_t *sizes = tknMalloc(sizeof(uint32_t) * attributeCount);

    for (uint32_t i = 0; i < attributeCount; i++)
    {
        lua_rawgeti(pLuaState, -1, i + 1);

        lua_getfield(pLuaState, -1, "name");
        names[i] = lua_tostring(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "type");
        uint32_t type = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "count");
        uint32_t count = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        uint32_t typeSize = 0;
        if (type == TYPE_UINT8)
            typeSize = 1;
        else if (type == TYPE_UINT16)
            typeSize = 2;
        else if (type == TYPE_UINT32)
            typeSize = 4;
        else if (type == TYPE_UINT64)
            typeSize = 8;
        else if (type == TYPE_INT8)
            typeSize = 1;
        else if (type == TYPE_INT16)
            typeSize = 2;
        else if (type == TYPE_INT32)
            typeSize = 4;
        else if (type == TYPE_INT64)
            typeSize = 8;
        else if (type == TYPE_FLOAT)
            typeSize = 4;
        else if (type == TYPE_DOUBLE)
            typeSize = 8;
        else
        {
            typeSize = 4; // default
        }

        sizes[i] = typeSize * count;
        lua_pop(pLuaState, 1);
    }

    TknVertexInputLayout *pTknVertexInputLayout = tknCreateVertexInputLayoutPtr(pTknGfxContext, attributeCount, names, sizes);

    tknFree(names);
    tknFree(sizes);

    lua_pushlightuserdata(pLuaState, pTknVertexInputLayout);
    return 1;
}

static int luaDestroyVertexInputLayoutPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknVertexInputLayout *pTknVertexInputLayout = (TknVertexInputLayout *)lua_touserdata(pLuaState, -1);
    tknDestroyVertexInputLayoutPtr(pTknGfxContext, pTknVertexInputLayout);
    return 0;
}

static int luaRemoveDrawCallAtIndex(lua_State *pLuaState)
{
    TknRenderPass *pTknRenderPass = (TknRenderPass *)lua_touserdata(pLuaState, -3);
    uint32_t subpassIndex = (uint32_t)lua_tointeger(pLuaState, -2);
    uint32_t index = (uint32_t)lua_tointeger(pLuaState, -1);
    tknRemoveDrawCallAtIndex(pTknRenderPass, subpassIndex, index);
    return 0;
}

static int luaGetDrawCallAtIndex(lua_State *pLuaState)
{
    TknRenderPass *pTknRenderPass = (TknRenderPass *)lua_touserdata(pLuaState, -3);
    uint32_t subpassIndex = (uint32_t)lua_tointeger(pLuaState, -2);
    uint32_t index = (uint32_t)lua_tointeger(pLuaState, -1);
    TknDrawCall *pTknDrawCall = tknGetDrawCallAtIndex(pTknRenderPass, subpassIndex, index);
    lua_pushlightuserdata(pLuaState, pTknDrawCall);
    return 1;
}

static int luaGetDrawCallCount(lua_State *pLuaState)
{
    TknRenderPass *pTknRenderPass = (TknRenderPass *)lua_touserdata(pLuaState, -2);
    uint32_t subpassIndex = (uint32_t)lua_tointeger(pLuaState, -1);
    uint32_t count = tknGetDrawCallCount(pTknRenderPass, subpassIndex);
    lua_pushinteger(pLuaState, (lua_Integer)count);
    return 1;
}

static int luaCreateUniformBufferPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -3);
    // layout at -2, data at -1

    VkDeviceSize size;
    void *packedData = packDataFromLayout(pLuaState, -2, -1, &size);

    TknUniformBuffer *pTknUniformBuffer = tknCreateUniformBufferPtr(pTknGfxContext, packedData, size);

    tknFree(packedData);
    lua_pushlightuserdata(pLuaState, pTknUniformBuffer);
    return 1;
}

static int luaDestroyUniformBufferPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknUniformBuffer *pTknUniformBuffer = (TknUniformBuffer *)lua_touserdata(pLuaState, -1);
    tknDestroyUniformBufferPtr(pTknGfxContext, pTknUniformBuffer);
    return 0;
}

static int luaUpdateUniformBufferPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -5);
    TknUniformBuffer *pTknUniformBuffer = (TknUniformBuffer *)lua_touserdata(pLuaState, -4);
    // layout at -3, data at -2, size at -1

    VkDeviceSize size;
    void *packedData = packDataFromLayout(pLuaState, -3, -2, &size);

    // Use the provided size if available, otherwise use calculated size
    VkDeviceSize finalSize = lua_isnil(pLuaState, -1) ? size : (VkDeviceSize)lua_tointeger(pLuaState, -1);

    tknUpdateUniformBufferPtr(pTknGfxContext, pTknUniformBuffer, packedData, finalSize);

    tknFree(packedData);
    return 0;
}

static int luaCreateMeshPtrWithData(lua_State *pLuaState)
{
    // Parameters: pTknGfxContext, pTknVertexInputLayout, vertexLayout, vertices, indexType, indices
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -6);
    TknVertexInputLayout *pTknVertexInputLayout = (TknVertexInputLayout *)lua_touserdata(pLuaState, -5);
    // vertexLayout at -4, vertices at -3, indexType at -2, indices at -1

    VkDeviceSize vertexSize;
    void *vertexData = packDataFromLayout(pLuaState, -4, -3, &vertexSize);

    // Calculate vertex count based on layout
    uint32_t vertexCount = 0;
    VkDeviceSize layoutSize = calculateLayoutSize(pLuaState, -4);
    if (layoutSize > 0)
    {
        vertexCount = (uint32_t)(vertexSize / layoutSize);
    }

    // Handle indices
    void *indexData = NULL;
    uint32_t indexCount = 0;
    VkIndexType indexType = (VkIndexType)lua_tointeger(pLuaState, -2);
    if (!lua_isnil(pLuaState, -1))
    {
        lua_len(pLuaState, -1);
        indexCount = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        size_t indexSize = (indexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        indexData = tknMalloc(indexSize * indexCount);

        for (uint32_t i = 0; i < indexCount; i++)
        {
            lua_rawgeti(pLuaState, -1, i + 1);
            if (indexType == VK_INDEX_TYPE_UINT16)
            {
                ((uint16_t *)indexData)[i] = (uint16_t)lua_tointeger(pLuaState, -1);
            }
            else
            {
                ((uint32_t *)indexData)[i] = (uint32_t)lua_tointeger(pLuaState, -1);
            }
            lua_pop(pLuaState, 1);
        }
    }

    TknMesh *pTknMesh = tknCreateMeshPtrWithData(pTknGfxContext, pTknVertexInputLayout, vertexData, vertexCount, indexType, indexData, indexCount);

    tknFree(vertexData);
    if (indexData)
        tknFree(indexData);

    lua_pushlightuserdata(pLuaState, pTknMesh);
    return 1;
}

static int luaDestroyMeshPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknMesh *pTknMesh = (TknMesh *)lua_touserdata(pLuaState, -1);
    tknDestroyMeshPtr(pTknGfxContext, pTknMesh);
    return 0;
}

static int luaSaveMeshPtrToPlyFile(lua_State *pLuaState)
{
    // Parameters: vertexPropertyNames, vertexPropertyTypes, vertexInputLayout, vertices, indices, filePath
    // Get vertexPropertyNames array
    lua_len(pLuaState, -6);
    uint32_t vertexPropertyCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    const char **vertexPropertyNames = tknMalloc(sizeof(const char *) * vertexPropertyCount);
    for (uint32_t i = 0; i < vertexPropertyCount; i++)
    {
        lua_rawgeti(pLuaState, -6, i + 1);
        vertexPropertyNames[i] = lua_tostring(pLuaState, -1);
        lua_pop(pLuaState, 1);
    }

    // Get vertexPropertyTypes array
    const char **vertexPropertyTypes = tknMalloc(sizeof(const char *) * vertexPropertyCount);
    for (uint32_t i = 0; i < vertexPropertyCount; i++)
    {
        lua_rawgeti(pLuaState, -5, i + 1);
        vertexPropertyTypes[i] = lua_tostring(pLuaState, -1);
        lua_pop(pLuaState, 1);
    }

    TknVertexInputLayout *pTknMeshVertexInputLayout = (TknVertexInputLayout *)lua_touserdata(pLuaState, -4);

    // Pack vertex data from layout
    VkDeviceSize vertexSize;
    void *vertices = packDataFromLayout(pLuaState, -4, -3, &vertexSize);

    // Calculate vertex count
    uint32_t vertexCount = 0;
    VkDeviceSize layoutSize = calculateLayoutSize(pLuaState, -4);
    if (layoutSize > 0)
    {
        vertexCount = (uint32_t)(vertexSize / layoutSize);
    }

    // Handle indices (can be nil)
    void *indices = NULL;
    uint32_t indexCount = 0;
    VkIndexType vkIndexType = VK_INDEX_TYPE_UINT32;

    if (!lua_isnil(pLuaState, -2))
    {
        lua_len(pLuaState, -2);
        indexCount = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        indices = tknMalloc(sizeof(uint32_t) * indexCount);
        uint32_t *indexArray = (uint32_t *)indices;

        for (uint32_t i = 0; i < indexCount; i++)
        {
            lua_rawgeti(pLuaState, -2, i + 1);
            indexArray[i] = (uint32_t)lua_tointeger(pLuaState, -1);
            lua_pop(pLuaState, 1);
        }
    }

    // Get file path
    const char *plyFilePath = lua_tostring(pLuaState, -1);

    // Call the C function
    tknSaveMeshPtrToPlyFile(vertexPropertyCount, vertexPropertyNames, vertexPropertyTypes,
                         pTknMeshVertexInputLayout, vertices, vertexCount, vkIndexType, indices, indexCount, plyFilePath);

    // Clean up
    tknFree(vertexPropertyNames);
    tknFree(vertexPropertyTypes);
    tknFree(vertices);
    if (indices)
        tknFree(indices);

    return 0;
}

static int luaCreateInstancePtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -4);
    TknVertexInputLayout *pTknVertexInputLayout = (TknVertexInputLayout *)lua_touserdata(pLuaState, -3);
    // instanceLayout at -2, instances at -1

    VkDeviceSize instanceSize;
    void *instanceData = packDataFromLayout(pLuaState, -2, -1, &instanceSize);

    // Calculate instance count based on layout
    uint32_t instanceCount = 1;
    VkDeviceSize layoutSize = calculateLayoutSize(pLuaState, -2);
    if (layoutSize > 0)
    {
        instanceCount = (uint32_t)(instanceSize / layoutSize);
    }

    TknInstance *pTknInstance = tknCreateInstancePtr(pTknGfxContext, pTknVertexInputLayout, instanceCount, instanceData);

    tknFree(instanceData);
    lua_pushlightuserdata(pLuaState, pTknInstance);
    return 1;
}

static int luaDestroyInstancePtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknInstance *pTknInstance = (TknInstance *)lua_touserdata(pLuaState, -1);
    tknDestroyInstancePtr(pTknGfxContext, pTknInstance);
    return 0;
}

static int luaUpdateInstancePtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -4);
    TknInstance *pTknInstance = (TknInstance *)lua_touserdata(pLuaState, -3);
    // instanceLayout at -2, instances at -1

    VkDeviceSize instanceSize;
    void *instanceData = packDataFromLayout(pLuaState, -2, -1, &instanceSize);

    // Calculate instance count based on layout
    uint32_t instanceCount = 1;
    VkDeviceSize layoutSize = calculateLayoutSize(pLuaState, -2);
    if (layoutSize > 0)
    {
        instanceCount = (uint32_t)(instanceSize / layoutSize);
    }

    tknUpdateInstancePtr(pTknGfxContext, pTknInstance, instanceData, instanceCount);

    tknFree(instanceData);
    return 0;
}

static int luaGetGlobalMaterialPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -1);
    TknMaterial *pTknMaterial = tknGetGlobalMaterialPtr(pTknGfxContext);
    lua_pushlightuserdata(pLuaState, pTknMaterial);
    return 1;
}

static int luaGetSubpassMaterialPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -3);
    TknRenderPass *pTknRenderPass = (TknRenderPass *)lua_touserdata(pLuaState, -2);
    uint32_t subpassIndex = (uint32_t)lua_tointeger(pLuaState, -1);
    TknMaterial *pTknMaterial = tknGetSubpassMaterialPtr(pTknGfxContext, pTknRenderPass, subpassIndex);
    printf("Subpass TknMaterial: %p\n", (void *)pTknMaterial);
    lua_pushlightuserdata(pLuaState, pTknMaterial);
    return 1;
}

static int luaCreatePipelineMaterialPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknPipeline *pTknPipeline = (TknPipeline *)lua_touserdata(pLuaState, -1);
    TknMaterial *pTknMaterial = tknCreatePipelineMaterialPtr(pTknGfxContext, pTknPipeline);
    lua_pushlightuserdata(pLuaState, pTknMaterial);
    return 1;
}

static int luaDestroyPipelineMaterialPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknMaterial *pTknMaterial = (TknMaterial *)lua_touserdata(pLuaState, -1);
    tknDestroyPipelineMaterialPtr(pTknGfxContext, pTknMaterial);
    return 0;
}

static int luaUpdateMaterialPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -3);
    TknMaterial *pTknMaterial = (TknMaterial *)lua_touserdata(pLuaState, -2);

    // Get tknInputBindings array
    lua_len(pLuaState, -1);
    uint32_t inputBindingCount = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    TknInputBinding *tknInputBindings = tknMalloc(sizeof(TknInputBinding) * inputBindingCount);

    for (uint32_t i = 0; i < inputBindingCount; i++)
    {
        lua_rawgeti(pLuaState, -1, i + 1);

        // Get vkDescriptorType
        lua_getfield(pLuaState, -1, "vkDescriptorType");
        VkDescriptorType vkDescriptorType = (VkDescriptorType)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        // Get binding
        lua_getfield(pLuaState, -1, "binding");
        uint32_t binding = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        tknInputBindings[i].vkDescriptorType = vkDescriptorType;
        tknInputBindings[i].binding = binding;

        // Parse different descriptor types based on current supported types
        if (vkDescriptorType == VK_DESCRIPTOR_TYPE_SAMPLER)
        {
            lua_getfield(pLuaState, -1, "pTknSampler");
            TknSampler *pTknSampler = (TknSampler *)lua_touserdata(pLuaState, -1);
            lua_pop(pLuaState, 1);
            tknInputBindings[i].tknInputBindingUnion.tknCombinedImageSamplerBinding.pTknSampler = pTknSampler;
        }
        else if (vkDescriptorType == VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER)
        {
            lua_getfield(pLuaState, -1, "pTknUniformBuffer");
            TknUniformBuffer *pTknUniformBuffer = (TknUniformBuffer *)lua_touserdata(pLuaState, -1);
            lua_pop(pLuaState, 1);

            tknInputBindings[i].tknInputBindingUnion.tknUniformBufferBinding.pTknUniformBuffer = pTknUniformBuffer;
        }
        else if (vkDescriptorType == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER)
        {
            lua_getfield(pLuaState, -1, "pTknSampler");
            TknSampler *pTknSampler = (TknSampler *)lua_touserdata(pLuaState, -1);
            lua_pop(pLuaState, 1);
            tknInputBindings[i].tknInputBindingUnion.tknCombinedImageSamplerBinding.pTknSampler = pTknSampler;

            lua_getfield(pLuaState, -1, "pTknImage");
            TknImage *pTknImage = (TknImage *)lua_touserdata(pLuaState, -1);
            lua_pop(pLuaState, 1);
            tknInputBindings[i].tknInputBindingUnion.tknCombinedImageSamplerBinding.pTknImage = pTknImage;
        }
        else
        {
            tknError("Unsupported descriptor type in TknInputBinding: %d", vkDescriptorType);
        }

        lua_pop(pLuaState, 1); // Remove the binding table
    }

    tknUpdateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindingCount, tknInputBindings);

    tknFree(tknInputBindings);
    return 0;
}

static int luaUpdateMeshPtr(lua_State *pLuaState)
{
    // Parameters: pTknGfxContext, pTknMesh, vertexLayout, vertices, indexType, indices
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -6);
    TknMesh *pTknMesh = (TknMesh *)lua_touserdata(pLuaState, -5);
    // vertexLayout at -4, vertices at -3, indexType at -2, indices at -1

    VkDeviceSize vertexSize;
    void *vertexData = NULL;
    uint32_t vertexCount = 0;

    if (!lua_isnil(pLuaState, -3))
    {
        vertexData = packDataFromLayout(pLuaState, -4, -3, &vertexSize);

        // Calculate vertex count based on layout
        VkDeviceSize layoutSize = calculateLayoutSize(pLuaState, -4);
        if (layoutSize > 0)
        {
            vertexCount = (uint32_t)(vertexSize / layoutSize);
        }
    }

    // Handle indices
    void *indexData = NULL;
    uint32_t indexCount = 0;
    VkIndexType indexType = (VkIndexType)lua_tointeger(pLuaState, -2);
    if (!lua_isnil(pLuaState, -1))
    {
        lua_len(pLuaState, -1);
        indexCount = (uint32_t)lua_tointeger(pLuaState, -1);
        lua_pop(pLuaState, 1);

        size_t indexSize = (indexType == VK_INDEX_TYPE_UINT16) ? sizeof(uint16_t) : sizeof(uint32_t);
        indexData = tknMalloc(indexSize * indexCount);

        for (uint32_t i = 0; i < indexCount; i++)
        {
            lua_rawgeti(pLuaState, -1, i + 1);
            if (indexType == VK_INDEX_TYPE_UINT16)
            {
                ((uint16_t *)indexData)[i] = (uint16_t)lua_tointeger(pLuaState, -1);
            }
            else

            {
                ((uint32_t *)indexData)[i] = (uint32_t)lua_tointeger(pLuaState, -1);
            }
            lua_pop(pLuaState, 1);
        }
    }

    tknUpdateMeshPtr(pTknGfxContext, pTknMesh, NULL, vertexData, vertexCount, (uint32_t)indexType, indexData, indexCount);

    if (vertexData)
        tknFree(vertexData);
    if (indexData)
        tknFree(indexData);

    return 0;
}

static int luaCreateImagePtr(lua_State *pLuaState)
{
    // Parameters: pTknGfxContext, vkExtent3D, vkFormat, vkImageTiling, vkImageUsageFlags, vkMemoryPropertyFlags, vkImageAspectFlags, data (optional)
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -8);

    // Parse VkExtent3D (table with width, height, depth)
    VkExtent3D vkExtent3D;
    lua_getfield(pLuaState, -7, "width");
    vkExtent3D.width = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -7, "height");
    vkExtent3D.height = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    lua_getfield(pLuaState, -7, "depth");
    vkExtent3D.depth = (uint32_t)lua_tointeger(pLuaState, -1);
    lua_pop(pLuaState, 1);

    VkFormat vkFormat = (VkFormat)lua_tointeger(pLuaState, -6);
    VkImageTiling vkImageTiling = (VkImageTiling)lua_tointeger(pLuaState, -5);
    VkImageUsageFlags vkImageUsageFlags = (VkImageUsageFlags)lua_tointeger(pLuaState, -4);
    VkMemoryPropertyFlags vkMemoryPropertyFlags = (VkMemoryPropertyFlags)lua_tointeger(pLuaState, -3);
    VkImageAspectFlags vkImageAspectFlags = (VkImageAspectFlags)lua_tointeger(pLuaState, -2);

    // Handle optional data parameter
    void *data = NULL;
    VkDeviceSize dataSize = 0;
    if (!lua_isnil(pLuaState, -1))
    {
        // If data is provided, it should be a Lua string (char*)
        if (lua_isstring(pLuaState, -1))
        {
            size_t luaDataSize;
            const char *luaData = lua_tolstring(pLuaState, -1, &luaDataSize);
            if (luaDataSize > 0)
            {
                dataSize = (VkDeviceSize)luaDataSize;
                data = tknMalloc(dataSize);
                memcpy(data, luaData, dataSize);
            }
        }
    }

    TknImage *pTknImage = tknCreateImagePtr(pTknGfxContext, vkExtent3D, vkFormat, vkImageTiling,
                                   vkImageUsageFlags, vkMemoryPropertyFlags,
                                   vkImageAspectFlags, data, dataSize);
    if (data != NULL)
    {
        tknFree(data);
    }
    lua_pushlightuserdata(pLuaState, pTknImage);
    return 1;
}

static int luaCreateSamplerPtr(lua_State *pLuaState)
{
    // Parameters: pTknGfxContext, magFilter, minFilter, mipmapMode, addressModeU, addressModeV, addressModeW, mipLodBias, anisotropyEnable, maxAnisotropy, minLod, maxLod, borderColor
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -13);
    VkFilter magFilter = (VkFilter)lua_tointeger(pLuaState, -12);
    VkFilter minFilter = (VkFilter)lua_tointeger(pLuaState, -11);
    VkSamplerMipmapMode mipmapMode = (VkSamplerMipmapMode)lua_tointeger(pLuaState, -10);
    VkSamplerAddressMode addressModeU = (VkSamplerAddressMode)lua_tointeger(pLuaState, -9);
    VkSamplerAddressMode addressModeV = (VkSamplerAddressMode)lua_tointeger(pLuaState, -8);
    VkSamplerAddressMode addressModeW = (VkSamplerAddressMode)lua_tointeger(pLuaState, -7);
    float mipLodBias = (float)lua_tonumber(pLuaState, -6);
    VkBool32 anisotropyEnable = (VkBool32)lua_toboolean(pLuaState, -5);
    float maxAnisotropy = (float)lua_tonumber(pLuaState, -4);
    float minLod = (float)lua_tonumber(pLuaState, -3);
    float maxLod = (float)lua_tonumber(pLuaState, -2);
    VkBorderColor borderColor = (VkBorderColor)lua_tointeger(pLuaState, -1);

    TknSampler *pTknSampler = tknCreateSamplerPtr(pTknGfxContext, magFilter, minFilter, mipmapMode,
                                         addressModeU, addressModeV, addressModeW, mipLodBias,
                                         anisotropyEnable, maxAnisotropy, minLod, maxLod, borderColor);

    lua_pushlightuserdata(pLuaState, pTknSampler);
    return 1;
}

static int luaDestroySamplerPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknSampler *pTknSampler = (TknSampler *)lua_touserdata(pLuaState, -1);
    tknDestroySamplerPtr(pTknGfxContext, pTknSampler);
    return 0;
}

static int luaDestroyImagePtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknImage *pTknImage = (TknImage *)lua_touserdata(pLuaState, -1);
    tknDestroyImagePtr(pTknGfxContext, pTknImage);
    return 0;
}

static int luaCreateASTCFromMemory(lua_State *pLuaState)
{
    // Parameter: Lua string (from io.open():read("*all"))
    if (!lua_isstring(pLuaState, 1))
    {
        lua_pushnil(pLuaState);
        return 1;
    }
    size_t bufferSize;
    const char *data = lua_tolstring(pLuaState, 1, &bufferSize);
    if (!data || bufferSize == 0)
    {
        lua_pushnil(pLuaState);
        return 1;
    }
    TknASTCImage *tknAstcImage = tknCreateASTCFromMemory(data, bufferSize);
    if (!tknAstcImage)
    {
        lua_pushnil(pLuaState);
        return 1;
    }
    // Return multiple values: tknAstcImage pointer, data, width, height, vkFormat, dataSize
    lua_pushlightuserdata(pLuaState, tknAstcImage);                  // TknASTCImage pointer
    lua_pushlstring(pLuaState, tknAstcImage->data, tknAstcImage->size); // Binary data with exact length
    lua_pushinteger(pLuaState, tknAstcImage->width);                 // width
    lua_pushinteger(pLuaState, tknAstcImage->height);                // height
    lua_pushinteger(pLuaState, tknAstcImage->vkFormat);              // vkFormat
    lua_pushinteger(pLuaState, tknAstcImage->size);                  // dataSize
    return 6;
}

static int luaDestroyASTCImage(lua_State *pLuaState)
{
    // Parameters: tknAstcImage (as lightuserdata)
    TknASTCImage *tknAstcImage = (TknASTCImage *)lua_touserdata(pLuaState, -1);
    if (tknAstcImage)
    {
        tknDestroyASTCImage(tknAstcImage);
    }
    return 0;
}

static int luaCreateTknFontLibraryPtr(lua_State *pLuaState)
{
    TknFontLibrary *pTknFontLibrary = createTknFontLibraryPtr();
    lua_pushlightuserdata(pLuaState, pTknFontLibrary);
    return 1;
}

static int luaDestroyTknFontLibraryPtr(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -2);
    TknFontLibrary *pTknFontLibrary = (TknFontLibrary *)lua_touserdata(pLuaState, -1);
    destroyTknFontLibraryPtr(pTknFontLibrary, pTknGfxContext);
    return 0;
}

static int luaCreateTknFontPtr(lua_State *pLuaState)
{
    TknFontLibrary *pTknFontLibrary = (TknFontLibrary *)lua_touserdata(pLuaState, -5);
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -4);
    const char *fontPath = lua_tostring(pLuaState, -3);
    uint32_t fontSize = (uint32_t)lua_tointeger(pLuaState, -2);
    uint32_t atlasLength = (uint32_t)lua_tointeger(pLuaState, -1);

    TknFont *pTknFont = createTknFontPtr(pTknFontLibrary, pTknGfxContext, fontPath, fontSize, atlasLength);
    lua_pushlightuserdata(pLuaState, pTknFont);
    lua_pushlightuserdata(pLuaState, pTknFont->pTknImage);
    return 2;
}

static int luaDestroyTknFontPtr(lua_State *pLuaState)
{
    TknFontLibrary *pTknFontLibrary = (TknFontLibrary *)lua_touserdata(pLuaState, -3);
    TknFont *pTknFont = (TknFont *)lua_touserdata(pLuaState, -2);
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -1);
    destroyTknFontPtr(pTknFontLibrary, pTknFont, pTknGfxContext);
    return 0;
}

static int luaFlushTknFontPtr(lua_State *pLuaState)
{
    TknFont *pTknFont = (TknFont *)lua_touserdata(pLuaState, -2);
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -1);
    flushTknFontPtr(pTknFont, pTknGfxContext);
    return 0;
}

static int luaLoadTknChar(lua_State *pLuaState)
{
    TknFont *pTknFont = (TknFont *)lua_touserdata(pLuaState, -2);
    uint32_t unicode = (uint32_t)lua_tointeger(pLuaState, -1);

    TknChar *pTknChar = loadTknChar(pTknFont, unicode);
    if (pTknChar)
    {
        lua_pushlightuserdata(pLuaState, pTknChar);
        lua_pushinteger(pLuaState, pTknChar->x);
        lua_pushinteger(pLuaState, pTknChar->y);
        lua_pushinteger(pLuaState, pTknChar->width);
        lua_pushinteger(pLuaState, pTknChar->height);
        lua_pushinteger(pLuaState, pTknChar->bearingX);
        lua_pushinteger(pLuaState, pTknChar->bearingY);
        lua_pushinteger(pLuaState, pTknChar->advance);
        return 8;
    }
    else
    {
        lua_pushnil(pLuaState);
        return 1;
    }
}

static int luaWaitRenderFence(lua_State *pLuaState)
{
    TknGfxContext *pTknGfxContext = (TknGfxContext *)lua_touserdata(pLuaState, -1);
    tknWaitGfxRenderFence(pTknGfxContext);
    return 0;
}

void bindFunctions(lua_State *pLuaState)
{
    luaL_Reg regs[] = {
        {"tknGetSupportedFormat", luaGetSupportedFormat},
        {"tknCreateDynamicAttachmentPtr", luaCreateDynamicAttachmentPtr},
        {"tknCreateFixedAttachmentPtr", luaCreateFixedAttachmentPtr},
        {"tknGetSwapchainAttachmentPtr", luaGetSwapchainAttachmentPtr},
        {"tknDestroyDynamicAttachmentPtr", luaDestroyDynamicAttachmentPtr},
        {"tknDestroyFixedAttachmentPtr", luaDestroyFixedAttachmentPtr},
        {"tknCreateVertexInputLayoutPtr", luaCreateVertexInputLayoutPtr},
        {"tknDestroyVertexInputLayoutPtr", luaDestroyVertexInputLayoutPtr},
        {"tknCreateRenderPassPtr", luaCreateRenderPassPtr},
        {"tknDestroyRenderPassPtr", luaDestroyRenderPassPtr},
        {"tknCreatePipelinePtr", luaCreatePipelinePtr},
        {"tknDestroyPipelinePtr", luaDestroyPipelinePtr},
        {"tknCreateDrawCallPtr", luaCreateDrawCallPtr},
        {"tknDestroyDrawCallPtr", luaDestroyDrawCallPtr},
        {"tknInsertDrawCallPtr", luaInsertDrawCallPtr},
        {"tknRemoveDrawCallPtr", luaRemoveDrawCallPtr},
        {"tknRemoveDrawCallAtIndex", luaRemoveDrawCallAtIndex},
        {"tknGetDrawCallAtIndex", luaGetDrawCallAtIndex},
        {"tknGetDrawCallCount", luaGetDrawCallCount},
        {"tknCreateImagePtr", luaCreateImagePtr},
        {"tknDestroyImagePtr", luaDestroyImagePtr},
        {"tknCreateSamplerPtr", luaCreateSamplerPtr},
        {"tknDestroySamplerPtr", luaDestroySamplerPtr},
        {"tknCreateASTCFromMemory", luaCreateASTCFromMemory},
        {"tknDestroyASTCImage", luaDestroyASTCImage},
        {"tknCreateUniformBufferPtr", luaCreateUniformBufferPtr},
        {"tknDestroyUniformBufferPtr", luaDestroyUniformBufferPtr},
        {"tknUpdateUniformBufferPtr", luaUpdateUniformBufferPtr},
        {"tknCreateMeshPtrWithData", luaCreateMeshPtrWithData},
        {"tknDestroyMeshPtr", luaDestroyMeshPtr},
        {"tknSaveMeshPtrToPlyFile", luaSaveMeshPtrToPlyFile},
        {"tknCreateInstancePtr", luaCreateInstancePtr},
        {"tknUpdateInstancePtr", luaUpdateInstancePtr},
        {"tknDestroyInstancePtr", luaDestroyInstancePtr},
        {"tknGetGlobalMaterialPtr", luaGetGlobalMaterialPtr},
        {"tknGetSubpassMaterialPtr", luaGetSubpassMaterialPtr},
        {"tknCreatePipelineMaterialPtr", luaCreatePipelineMaterialPtr},
        {"tknDestroyPipelineMaterialPtr", luaDestroyPipelineMaterialPtr},
        {"tknUpdateMaterialPtr", luaUpdateMaterialPtr},
        {"tknUpdateMeshPtr", luaUpdateMeshPtr},
        {"tknCreateTknFontLibraryPtr", luaCreateTknFontLibraryPtr},
        {"tknDestroyTknFontLibraryPtr", luaDestroyTknFontLibraryPtr},
        {"tknCreateTknFontPtr", luaCreateTknFontPtr},
        {"tknDestroyTknFontPtr", luaDestroyTknFontPtr},
        {"tknFlushTknFontPtr", luaFlushTknFontPtr},
        {"tknLoadTknChar", luaLoadTknChar},
        {"tknWaitRenderFence", luaWaitRenderFence},
        {NULL, NULL},
    };
    luaL_newlib(pLuaState, regs);
    lua_setglobal(pLuaState, "tkn");
}
