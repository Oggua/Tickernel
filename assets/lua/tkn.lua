-- Document not code!
-- This file provides type hints and documentation for the tkn module
-- Actual implementations are provided by C bindings
-- Initialize tkn table if not already loaded by C bindings
require("vulkan")
local tkn = _G.tkn

-- Type constants (Lua style naming)
tkn.type = {
    uint8 = 0,
    uint16 = 1,
    uint32 = 2,
    uint64 = 3,
    int8 = 4,
    int16 = 5,
    int32 = 6,
    int64 = 7,
    float = 8,
    double = 9,
}

tkn.defaultVkPipelineViewportStateCreateInfo = {
    pViewports = {{
        x = 0.0,
        y = 0.0,
        width = 1.0,
        height = 1.0,
        minDepth = 0.0,
        maxDepth = 1.0,
    }},
    pScissors = {{
        offset = {
            x = 0,
            y = 0,
        },
        extent = {
            width = 0,
            height = 0,
        },
    }},
}

tkn.defaultVkPipelineMultisampleStateCreateInfo = {
    rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
    sampleShadingEnable = false,
    minSampleShading = 0,
    pSampleMask = nil,
    alphaToCoverageEnable = false,
    alphaToOneEnable = false,
}

tkn.defaultVkPipelineDynamicStateCreateInfo = {
    pDynamicStates = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR},
}

tkn.defaultVkPipelineRasterizationStateCreateInfo = {
    depthClampEnable = false,
    rasterizerDiscardEnable = false,
    polygonMode = VK_POLYGON_MODE_FILL,
    cullMode = VK_CULL_MODE_NONE,
    frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE,
    depthBiasEnable = false,
    depthBiasConstantFactor = 0.0,
    depthBiasClamp = 0.0,
    depthBiasSlopeFactor = 0.0,
    lineWidth = 1.0,
}

function tkn.rgbaToAbgr(rgba)
    local r = (rgba >> 24) & 0xFF
    local g = (rgba >> 16) & 0xFF
    local b = (rgba >> 8) & 0xFF
    local a = rgba & 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r
end

function tkn.tknCreateImagePtrWithPath(tknContext, path)
    local astcFile = io.open(path, "rb")
    if astcFile then
        local content = astcFile:read("*all")
        astcFile:close()
        local pASTC, data, width, height, vkFormat, size = tkn.tknCreateASTCFromMemory(content)
        if pASTC then
            local vkExtent3D = {
                width = width,
                height = height,
                depth = 1,
            }
            local pTknImage = tkn.tknCreateImagePtr(tknContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, VK_IMAGE_USAGE_TEXTURE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, VK_IMAGE_ASPECT_COLOR_BIT, data)
            tkn.tknDestroyASTCImage(pASTC)
            return pTknImage, width, height
        else
            print("Failed to create ASTC image from file: " .. path)
            return nil
        end
    else
        print("Failed to open ASTC file: " .. path)
        return nil
    end
end

-- Creates a mesh with default zero-initialized vertex and index data
function tkn.tknCreateDefaultMeshPtr(pTknGfxContext, format, pTknMeshVertexInputLayout, vertexCount, indexType, indexCount)
    local vertices = {}
    local indices = {}

    -- Initialize vertex data with zeros for each field
    for i, fieldFormat in ipairs(format) do
        local fieldData = {}
        for j = 1, vertexCount * fieldFormat.count do
            table.insert(fieldData, 0)
        end
        vertices[fieldFormat.name] = fieldData
    end

    -- Initialize indices with zeros (0-based for C compatibility)
    for i = 1, indexCount do
        table.insert(indices, 0)
    end

    return tkn.tknCreateMeshPtrWithData(pTknGfxContext, pTknMeshVertexInputLayout, format, vertices, indexType, indices)
end

-- Function declarations for IDE support (only used if C binding not available)
if not tkn.tknGetSupportedFormat then
    ---Find first supported image format from candidates list
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param candidates table List of VkFormat candidates to test
    ---@param tiling integer VkImageTiling mode (LINEAR or OPTIMAL)
    ---@param features integer Required VkFormatFeatureFlags
    ---@return integer Supported VkFormat, or VK_FORMAT_UNDEFINED if none match
    function tkn.tknGetSupportedFormat(pTknGfxContext, candidates, tiling, features)
        error("tkn.tknGetSupportedFormat: C binding not loaded")
    end
end

if not tkn.tknCreateDynamicAttachmentPtr then
    ---Create a dynamically-scaled render attachment
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param vkFormat integer VkFormat for the attachment
    ---@param vkImageUsageFlags integer Usage flags (e.g., VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)
    ---@param vkImageAspectFlags integer Aspect flags (e.g., VK_IMAGE_ASPECT_COLOR_BIT)
    ---@param scaler number Scale factor (0.0-1.0) relative to swapchain size
    ---@return lightuserdata TknAttachment pointer
    function tkn.tknCreateDynamicAttachmentPtr(pTknGfxContext, vkFormat, vkImageUsageFlags, vkImageAspectFlags, scaler)
        error("tkn.tknCreateDynamicAttachmentPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyDynamicAttachmentPtr then
    ---Destroy a dynamic render attachment
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pAttachment lightuserdata TknAttachment pointer
    function tkn.tknDestroyDynamicAttachmentPtr(pTknGfxContext, pAttachment)
        error("tkn.tknDestroyDynamicAttachmentPtr: C binding not loaded")
    end
end

if not tkn.tknGetSwapchainAttachmentPtr then
    ---Get the swapchain attachment (presentation surface)
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@return lightuserdata TknAttachment pointer (swapchain)
    function tkn.tknGetSwapchainAttachmentPtr(pTknGfxContext)
        error("tkn.tknGetSwapchainAttachmentPtr: C binding not loaded")
    end
end

if not tkn.tknCreateVertexInputLayoutPtr then
    ---Create a vertex input layout from field descriptions
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param format table Array of {name, type, count} field descriptors
    ---@return lightuserdata TknVertexInputLayout pointer
    function tkn.tknCreateVertexInputLayoutPtr(pTknGfxContext, format)
        error("tkn.tknCreateVertexInputLayoutPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyVertexInputLayoutPtr then
    ---Destroy a vertex input layout
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pLayout lightuserdata TknVertexInputLayout pointer
    function tkn.tknDestroyVertexInputLayoutPtr(pTknGfxContext, pLayout)
        error("tkn.tknDestroyVertexInputLayoutPtr: C binding not loaded")
    end
end

if not tkn.tknCreateRenderPassPtr then
    ---Create a render pass with multiple attachments and subpasses
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param vkAttachmentDescriptions table Array of VkAttachmentDescription
    ---@param inputAttachmentPtrs table Array of TknAttachment pointers
    ---@param vkClearValues table Array of VkClearValue for each attachment
    ---@param vkSubpassDescriptions table Array of VkSubpassDescription
    ---@param spvPathsArray table 2D array of shader paths for each subpass
    ---@param vkSubpassDependencies table Array of VkSubpassDependency for synchronization
    ---@param renderPassIndex integer Index for this render pass
    ---@return lightuserdata TknRenderPass pointer
    function tkn.tknCreateRenderPassPtr(pTknGfxContext, vkAttachmentDescriptions, inputAttachmentPtrs, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)
        error("tkn.tknCreateRenderPassPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyRenderPassPtr then
    ---Destroy a render pass and all associated pipelines
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknRenderPass lightuserdata TknRenderPass pointer
    function tkn.tknDestroyRenderPassPtr(pTknGfxContext, pTknRenderPass)
        error("tkn.tknDestroyRenderPassPtr: C binding not loaded")
    end
end

if not tkn.tknCreatePipelinePtr then
    ---Create a graphics pipeline for a specific subpass
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknRenderPass lightuserdata TknRenderPass pointer
    ---@param subpassIndex integer Target subpass index within the render pass
    ---@param spvPaths table Array of compiled shader paths (vertex, fragment, etc.)
    ---@param pTknMeshVertexInputLayout lightuserdata Mesh vertex layout or nil
    ---@param pInstanceVertexInputLayout lightuserdata Instance vertex layout or nil
    ---@param vkPipelineInputAssemblyStateCreateInfo table Input assembly state (topology, etc.)
    ---@param vkPipelineViewportStateCreateInfo table Viewport/scissor state
    ---@param vkPipelineRasterizationStateCreateInfo table Rasterization state
    ---@param vkPipelineMultisampleStateCreateInfo table Multisample state
    ---@param vkPipelineDepthStencilStateCreateInfo table Depth/stencil state
    ---@param vkPipelineColorBlendStateCreateInfo table Color blend state
    ---@param vkPipelineDynamicStateCreateInfo table Dynamic states (viewport, scissor, etc.)
    ---@return lightuserdata TknPipeline pointer
    function tkn.tknCreatePipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, spvPaths, pTknMeshVertexInputLayout, pInstanceVertexInputLayout, vkPipelineInputAssemblyStateCreateInfo, vkPipelineViewportStateCreateInfo, vkPipelineRasterizationStateCreateInfo, vkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, vkPipelineDynamicStateCreateInfo)
        error("tkn.tknCreatePipelinePtr: C binding not loaded")
    end
end

if not tkn.tknDestroyPipelinePtr then
    ---Destroy a graphics pipeline
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknPipeline lightuserdata TknPipeline pointer
    function tkn.tknDestroyPipelinePtr(pTknGfxContext, pTknPipeline)
        error("tkn.tknDestroyPipelinePtr: C binding not loaded")
    end
end

if not tkn.tknCreateDrawCallPtr then
    ---Create a draw call combining pipeline, material, mesh, and instance data
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknMaterial lightuserdata TknMaterial pointer
    ---@param pTknMesh lightuserdata TknMesh pointer or nil
    ---@param pTknInstance lightuserdata TknInstance pointer or nil
    ---@return lightuserdata TknDrawCall pointer
    function tkn.tknCreateDrawCallPtr(pTknGfxContext, pTknMaterial, pTknMesh, pTknInstance)
        error("tkn.tknCreateDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyDrawCallPtr then
    ---Destroy a draw call
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknDrawCall lightuserdata TknDrawCall pointer
    function tkn.tknDestroyDrawCallPtr(pTknGfxContext, pTknDrawCall)
        error("tkn.tknDestroyDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknInsertDrawCallPtr then
    ---Insert a draw call at specified index in the subpass queue
    ---@param pTknDrawCall lightuserdata TknDrawCall pointer
    ---@param index integer Position to insert (0-based)
    function tkn.tknInsertDrawCallPtr(pTknDrawCall, index)
        error("tkn.tknInsertDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknRemoveDrawCallPtr then
    ---Remove a draw call from the subpass queue
    ---@param pTknDrawCall lightuserdata TknDrawCall pointer
    function tkn.tknRemoveDrawCallPtr(pTknDrawCall)
        error("tkn.tknRemoveDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknRemoveDrawCallAtIndex then
    ---Remove a draw call at specified index from a subpass
    ---@param pTknRenderPass lightuserdata TknRenderPass pointer
    ---@param subpassIndex integer Target subpass index
    ---@param index integer Index of draw call to remove (0-based)
    function tkn.tknRemoveDrawCallAtIndex(pTknRenderPass, subpassIndex, index)
        error("tkn.tknRemoveDrawCallAtIndex: C binding not loaded")
    end
end

if not tkn.tknGetDrawCallAtIndex then
    ---Get a draw call at specified index from a subpass
    ---@param pTknRenderPass lightuserdata TknRenderPass pointer
    ---@param subpassIndex integer Target subpass index
    ---@param index integer Index of draw call to retrieve (0-based)
    ---@return lightuserdata TknDrawCall pointer
    function tkn.tknGetDrawCallAtIndex(pTknRenderPass, subpassIndex, index)
        error("tkn.tknGetDrawCallAtIndex: C binding not loaded")
    end
end

if not tkn.tknGetDrawCallCount then
    ---Get the number of draw calls in a subpass
    ---@param pTknRenderPass lightuserdata TknRenderPass pointer
    ---@param subpassIndex integer Target subpass index
    ---@return integer Number of draw calls
    function tkn.tknGetDrawCallCount(pTknRenderPass, subpassIndex)
        error("tkn.tknGetDrawCallCount: C binding not loaded")
    end
end

if not tkn.tknCreateUniformBufferPtr then
    ---Create a uniform buffer with initial data
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param format table Field layout descriptors
    ---@param buffer table Data table with named arrays
    ---@return lightuserdata TknUniformBuffer pointer
    function tkn.tknCreateUniformBufferPtr(pTknGfxContext, format, buffer)
        error("tkn.tknCreateUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyUniformBufferPtr then
    ---Destroy a uniform buffer
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknUniformBuffer lightuserdata TknUniformBuffer pointer
    function tkn.tknDestroyUniformBufferPtr(pTknGfxContext, pTknUniformBuffer)
        error("tkn.tknDestroyUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.tknUpdateUniformBufferPtr then
    ---Update contents of a uniform buffer
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknUniformBuffer lightuserdata TknUniformBuffer pointer
    ---@param format table Field layout descriptors
    ---@param buffer table Data table with named arrays
    ---@param size integer Optional override size, or nil for auto-calculated
    function tkn.tknUpdateUniformBufferPtr(pTknGfxContext, pTknUniformBuffer, format, buffer, size)
        error("tkn.tknUpdateUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.tknCreateInstancePtr then
    ---Create instance data with vertex attributes
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknVertexInputLayout lightuserdata TknVertexInputLayout pointer
    ---@param format table Field layout descriptors
    ---@param instances table Data table with named arrays
    ---@return lightuserdata TknInstance pointer
    function tkn.tknCreateInstancePtr(pTknGfxContext, pTknVertexInputLayout, format, instances)
        error("tkn.tknCreateInstancePtr: C binding not loaded")
    end
end

if not tkn.tknDestroyInstancePtr then
    ---Destroy instance data
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknInstance lightuserdata TknInstance pointer
    function tkn.tknDestroyInstancePtr(pTknGfxContext, pTknInstance)
        error("tkn.tknDestroyInstancePtr: C binding not loaded")
    end
end

if not tkn.tknCreateMeshPtrWithData then
    ---Create a mesh with vertex and index data
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknMeshVertexInputLayout lightuserdata TknVertexInputLayout pointer
    ---@param format table Field layout descriptors
    ---@param vertices table Data table with named vertex arrays
    ---@param indexType integer VkIndexType (UINT16 or UINT32)
    ---@param indices table Index array or nil for non-indexed geometry
    ---@return lightuserdata TknMesh pointer
    function tkn.tknCreateMeshPtrWithData(pTknGfxContext, pTknMeshVertexInputLayout, format, vertices, indexType, indices)
        error("tkn.tknCreateMeshPtrWithData: C binding not loaded")
    end
end

if not tkn.tknUpdateMeshPtr then
    ---Update mesh vertex and index data
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknMesh lightuserdata TknMesh pointer
    ---@param format string Format string for data layout
    ---@param vertices table Vertex data
    ---@param indexType integer VkIndexType (UINT16 or UINT32)
    ---@param indices table Index array or nil
    function tkn.tknUpdateMeshPtr(pTknGfxContext, pTknMesh, format, vertices, indexType, indices)
        error("tkn.tknUpdateMeshPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyMeshPtr then
    ---Destroy a mesh
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknMesh lightuserdata TknMesh pointer
    function tkn.tknDestroyMeshPtr(pTknGfxContext, pTknMesh)
        error("tkn.tknDestroyMeshPtr: C binding not loaded")
    end
end

if not tkn.tknGetGlobalMaterialPtr then
    ---Get the global material descriptor set
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@return lightuserdata TknMaterial pointer (global descriptor set)
    function tkn.tknGetGlobalMaterialPtr(pTknGfxContext)
        error("tkn.tknGetGlobalMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknGetSubpassMaterialPtr then
    ---Get the subpass-level material descriptor set
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknRenderPass lightuserdata TknRenderPass pointer
    ---@param subpassIndex integer Target subpass index
    ---@return lightuserdata TknMaterial pointer (subpass descriptor set)
    function tkn.tknGetSubpassMaterialPtr(pTknGfxContext, pTknRenderPass, subpassIndex)
        error("tkn.tknGetSubpassMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknCreatePipelineMaterialPtr then
    ---Create a pipeline-specific material descriptor set
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknPipeline lightuserdata TknPipeline pointer
    ---@return lightuserdata TknMaterial pointer (pipeline-specific descriptor set)
    function tkn.tknCreatePipelineMaterialPtr(pTknGfxContext, pTknPipeline)
        error("tkn.tknCreatePipelineMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyPipelineMaterialPtr then
    ---Destroy a pipeline-specific material descriptor set
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknMaterial lightuserdata TknMaterial pointer
    function tkn.tknDestroyPipelineMaterialPtr(pTknGfxContext, pTknMaterial)
        error("tkn.tknDestroyPipelineMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknUpdateMaterialPtr then
    ---Update material descriptor bindings
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknMaterial lightuserdata TknMaterial pointer
    ---@param inputBindings table Input bindings with buffer/image/sampler pointers
    function tkn.tknUpdateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindings)
        error("tkn.tknUpdateMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknCreateImagePtr then
    ---Create a VkImage with specified properties
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param vkExtent3D table Image dimensions {width, height, depth}
    ---@param vkFormat integer VkFormat enum value
    ---@param vkImageTiling integer VkImageTiling (LINEAR or OPTIMAL)
    ---@param vkImageUsageFlags integer VkImageUsageFlags combination
    ---@param vkMemoryPropertyFlags integer VkMemoryPropertyFlags combination
    ---@param vkImageAspectFlags integer VkImageAspectFlags (COLOR, DEPTH, STENCIL)
    ---@param data lightuserdata Raw image data pointer or nil
    ---@return lightuserdata TknImage pointer
    function tkn.tknCreateImagePtr(pTknGfxContext, vkExtent3D, vkFormat, vkImageTiling, vkImageUsageFlags, vkMemoryPropertyFlags, vkImageAspectFlags, data)
        error("tkn.tknCreateImagePtr: C binding not loaded")
    end
end

if not tkn.tknDestroyImagePtr then
    ---Destroy a VkImage
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknImage lightuserdata TknImage pointer
    function tkn.tknDestroyImagePtr(pTknGfxContext, pTknImage)
        error("tkn.tknDestroyImagePtr: C binding not loaded")
    end
end

if not tkn.tknCreateASTCFromMemory then
    ---Load ASTC compressed image from memory buffer
    ---@param buffer lightuserdata Pointer to ASTC data
    ---@param size integer Size of buffer in bytes
    ---@return table ASTC image structure with width/height/data
    function tkn.tknCreateASTCFromMemory(buffer, size)
        error("tkn.tknCreateASTCFromMemory: C binding not loaded")
    end
end

if not tkn.tknDestroyASTCImage then
    ---Destroy ASTC image structure
    ---@param astcImage table ASTC image structure
    function tkn.tknDestroyASTCImage(astcImage)
        error("tkn.tknDestroyASTCImage: C binding not loaded")
    end
end

-- Sampler creation convenience functions
if not tkn.tknCreateSamplerPtr then
    ---Create a VkSampler with specified filtering and addressing modes
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param magFilter integer VkFilter (NEAREST or LINEAR)
    ---@param minFilter integer VkFilter (NEAREST or LINEAR)
    ---@param mipmapMode integer VkSamplerMipmapMode (NEAREST or LINEAR)
    ---@param addressModeU integer VkSamplerAddressMode (REPEAT, MIRRORED_REPEAT, CLAMP_TO_EDGE, etc)
    ---@param addressModeV integer VkSamplerAddressMode
    ---@param addressModeW integer VkSamplerAddressMode
    ---@param mipLodBias number Mipmap LOD bias
    ---@param anisotropyEnable boolean Enable anisotropic filtering
    ---@param maxAnisotropy number Maximum anisotropy level
    ---@param minLod number Minimum LOD
    ---@param maxLod number Maximum LOD
    ---@param borderColor integer VkBorderColor
    ---@return lightuserdata TknSampler pointer
    function tkn.tknCreateSamplerPtr(pTknGfxContext, magFilter, minFilter, mipmapMode, addressModeU, addressModeV, addressModeW, mipLodBias, anisotropyEnable, maxAnisotropy, minLod, maxLod, borderColor)
        error("tkn.tknCreateSamplerPtr: C binding not loaded")
    end
end

if not tkn.tknDestroySamplerPtr then
    ---Destroy a VkSampler
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknSampler lightuserdata TknSampler pointer
    function tkn.tknDestroySamplerPtr(pTknGfxContext, pTknSampler)
        error("tkn.tknDestroySamplerPtr: C binding not loaded")
    end
end

-- Font library functions
if not tkn.tknCreateTknFontLibraryPtr then
    ---Create a font library instance
    ---@return lightuserdata TknFontLibrary pointer
    function tkn.tknCreateTknFontLibraryPtr()
        error("tkn.tknCreateTknFontLibraryPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyTknFontLibraryPtr then
    ---Destroy a font library instance
    ---@param pTknFontLibrary lightuserdata TknFontLibrary pointer
    function tkn.tknDestroyTknFontLibraryPtr(pTknFontLibrary)
        error("tkn.tknDestroyTknFontLibraryPtr: C binding not loaded")
    end
end

if not tkn.tknCreateTknFontPtr then
    ---Create a font from a file
    ---@param pTknFontLibrary lightuserdata TknFontLibrary pointer
    ---@param fontPath string Path to font file
    ---@param fontSize integer Font size in pixels
    ---@param atlasLength integer Size of text atlas
    ---@return lightuserdata TknFont pointer
    function tkn.tknCreateTknFontPtr(pTknFontLibrary, fontPath, fontSize, atlasLength)
        error("tkn.tknCreateTknFontPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyTknFontPtr then
    ---Destroy a font and associated resources
    ---@param pTknFontLibrary lightuserdata TknFontLibrary pointer
    ---@param pTknFont lightuserdata TknFont pointer
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    function tkn.tknDestroyTknFontPtr(pTknFontLibrary, pTknFont, pTknGfxContext)
        error("tkn.tknDestroyTknFontPtr: C binding not loaded")
    end
end

if not tkn.tknFlushTknFontPtr then
    ---Flush pending font atlas updates to GPU
    ---@param pTknFont lightuserdata TknFont pointer
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    function tkn.tknFlushTknFontPtr(pTknFont, pTknGfxContext)
        error("tkn.tknFlushTknFontPtr: C binding not loaded")
    end
end

if not tkn.tknLoadTknChar then
    ---Load a character into font atlas
    ---@param pTknFont lightuserdata TknFont pointer
    ---@param unicode integer Unicode codepoint to load
    function tkn.tknLoadTknChar(pTknFont, unicode)
        error("tkn.tknLoadTknChar: C binding not loaded")
    end
end

if not tkn.tknWaitRenderFence then
    ---Wait for GPU render fence before modifying GPU resources
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    function tkn.tknWaitRenderFence(pTknGfxContext)
        error("tkn.tknWaitRenderFence: C binding not loaded")
    end
end

if not tkn.tknBeginRenderPassPtr then
    ---Begin a render pass
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknFrame lightuserdata Frame pointer
    ---@param pTknRenderPass lightuserdata RenderPass pointer
    function tkn.tknBeginRenderPassPtr(pTknGfxContext, pTknFrame, pTknRenderPass)
        error("tkn.tknBeginRenderPassPtr: C binding not loaded")
    end
end

if not tkn.tknEndRenderPassPtr then
    ---End current render pass
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknFrame lightuserdata Frame pointer
    function tkn.tknEndRenderPassPtr(pTknGfxContext, pTknFrame)
        error("tkn.tknEndRenderPassPtr: C binding not loaded")
    end
end

if not tkn.tknNextSubpassPtr then
    ---Move to next subpass in current render pass
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknFrame lightuserdata Frame pointer
    function tkn.tknNextSubpassPtr(pTknGfxContext, pTknFrame)
        error("tkn.tknNextSubpassPtr: C binding not loaded")
    end
end

if not tkn.tknRecordDrawCallPtr then
    ---Record a draw call with pipeline binding and draw commands
    ---@param pTknGfxContext lightuserdata Graphics context pointer
    ---@param pTknFrame lightuserdata Frame pointer
    ---@param pTknDrawCall lightuserdata DrawCall pointer
    function tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, pTknDrawCall)
        error("tkn.tknRecordDrawCallPtr: C binding not loaded")
    end
end

return tkn
