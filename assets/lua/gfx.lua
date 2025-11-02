-- Document not code!
-- This file provides type hints and documentation for the gfx module
-- Actual implementations are provided by C bindings
-- Initialize gfx table if not already loaded by C bindings
require("vulkan")
local gfx = _G.gfx

-- Type constants (Lua style naming)
gfx.type = {
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

gfx.defaultVkPipelineViewportStateCreateInfo = {
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

gfx.defaultVkPipelineMultisampleStateCreateInfo = {
    rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
    sampleShadingEnable = false,
    minSampleShading = 0,
    pSampleMask = nil,
    alphaToCoverageEnable = false,
    alphaToOneEnable = false,
}

gfx.defaultVkPipelineDynamicStateCreateInfo = {
    pDynamicStates = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR},
}

gfx.defaultVkPipelineRasterizationStateCreateInfo = {
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
function gfx.createImagePtrWithPath(gfxContext, path)
    local astcFile = io.open(path, "rb")
    if astcFile then
        local content = astcFile:read("*all")
        astcFile:close()
        local pASTC, data, width, height, vkFormat, size = gfx.createASTCFromMemory(content)
        if pASTC then
            local vkExtent3D = {
                width = width,
                height = height,
                depth = 1,
            }
            local pImage = gfx.createImagePtr(gfxContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, VK_IMAGE_USAGE_TEXTURE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, VK_IMAGE_ASPECT_COLOR_BIT, data)
            gfx.destroyASTCImage(pASTC)
            return pImage, width, height
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
function gfx.createDefaultMeshPtr(pGfxContext, format, pMeshVertexInputLayout, vertexCount, indexType, indexCount)
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

    -- Print vertices table for debugging
    print("vertices table contents:")
    for fieldName, fieldData in pairs(vertices) do
        print("  " .. fieldName .. ": [" .. table.concat(fieldData, ", ") .. "]")
    end

    -- Initialize indices with zeros (0-based for C compatibility)
    for i = 1, indexCount do
        table.insert(indices, 0)
    end

    return gfx.createMeshPtrWithData(pGfxContext, pMeshVertexInputLayout, format, vertices, indexType, indices)
end

-- Function declarations for IDE support (only used if C binding not available)
if not gfx.getSupportedFormat then
    function gfx.getSupportedFormat(pGfxContext, candidates, tiling, features)
        error("gfx.getSupportedFormat: C binding not loaded")
    end
end

if not gfx.createDynamicAttachmentPtr then
    function gfx.createDynamicAttachmentPtr(pGfxContext, vkFormat, vkImageUsageFlags, vkImageAspectFlags, scaler)
        error("gfx.createDynamicAttachmentPtr: C binding not loaded")
    end
end

if not gfx.destroyDynamicAttachmentPtr then
    function gfx.destroyDynamicAttachmentPtr(pGfxContext, pAttachment)
        error("gfx.destroyDynamicAttachmentPtr: C binding not loaded")
    end
end

if not gfx.getSwapchainAttachmentPtr then
    function gfx.getSwapchainAttachmentPtr(pGfxContext)
        error("gfx.getSwapchainAttachmentPtr: C binding not loaded")
    end
end

if not gfx.createVertexInputLayoutPtr then
    function gfx.createVertexInputLayoutPtr(pGfxContext, format)
        error("gfx.createVertexInputLayoutPtr: C binding not loaded")
    end
end

if not gfx.destroyVertexInputLayoutPtr then
    function gfx.destroyVertexInputLayoutPtr(pGfxContext, pLayout)
        error("gfx.destroyVertexInputLayoutPtr: C binding not loaded")
    end
end

if not gfx.createRenderPassPtr then
    function gfx.createRenderPassPtr(pGfxContext, vkAttachmentDescriptions, inputAttachmentPtrs, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)
        error("gfx.createRenderPassPtr: C binding not loaded")
    end
end

if not gfx.destroyRenderPassPtr then
    function gfx.destroyRenderPassPtr(pGfxContext, pRenderPass)
        error("gfx.destroyRenderPassPtr: C binding not loaded")
    end
end

if not gfx.createPipelinePtr then
    function gfx.createPipelinePtr(pGfxContext, pRenderPass, subpassIndex, spvPaths, pMeshVertexInputLayout, pInstanceVertexInputLayout, vkPipelineInputAssemblyStateCreateInfo, vkPipelineViewportStateCreateInfo, vkPipelineRasterizationStateCreateInfo, vkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, vkPipelineDynamicStateCreateInfo)
        error("gfx.createPipelinePtr: C binding not loaded")
    end
end

if not gfx.destroyPipelinePtr then
    function gfx.destroyPipelinePtr(pGfxContext, pPipeline)
        error("gfx.destroyPipelinePtr: C binding not loaded")
    end
end

if not gfx.createDrawCallPtr then
    function gfx.createDrawCallPtr(pGfxContext, pMaterial, pMesh, pInstance)
        error("gfx.createDrawCallPtr: C binding not loaded")
    end
end

if not gfx.destroyDrawCallPtr then
    function gfx.destroyDrawCallPtr(pGfxContext, pDrawCall)
        error("gfx.destroyDrawCallPtr: C binding not loaded")
    end
end

if not gfx.insertDrawCallPtr then
    function gfx.insertDrawCallPtr(pDrawCall, index)
        error("gfx.insertDrawCallPtr: C binding not loaded")
    end
end

if not gfx.removeDrawCallPtr then
    function gfx.removeDrawCallPtr(pDrawCall)
        error("gfx.removeDrawCallPtr: C binding not loaded")
    end
end

if not gfx.removeDrawCallAtIndex then
    function gfx.removeDrawCallAtIndex(pPipeline, index)
        error("gfx.removeDrawCallAtIndex: C binding not loaded")
    end
end

if not gfx.getDrawCallAtIndex then
    function gfx.getDrawCallAtIndex(pPipeline, index)
        error("gfx.getDrawCallAtIndex: C binding not loaded")
    end
end

if not gfx.getDrawCallCount then
    function gfx.getDrawCallCount(pPipeline)
        error("gfx.getDrawCallCount: C binding not loaded")
    end
end

if not gfx.createUniformBufferPtr then
    function gfx.createUniformBufferPtr(pGfxContext, format, buffer)
        error("gfx.createUniformBufferPtr: C binding not loaded")
    end
end

if not gfx.destroyUniformBufferPtr then
    function gfx.destroyUniformBufferPtr(pGfxContext, pUniformBuffer)
        error("gfx.destroyUniformBufferPtr: C binding not loaded")
    end
end

if not gfx.updateUniformBufferPtr then
    function gfx.updateUniformBufferPtr(pGfxContext, pUniformBuffer, format, buffer, size)
        error("gfx.updateUniformBufferPtr: C binding not loaded")
    end
end

if not gfx.createInstancePtr then
    function gfx.createInstancePtr(pGfxContext, pVertexInputLayout, format, instances)
        error("gfx.createInstancePtr: C binding not loaded")
    end
end

if not gfx.destroyInstancePtr then
    function gfx.destroyInstancePtr(pGfxContext, pInstance)
        error("gfx.destroyInstancePtr: C binding not loaded")
    end
end

if not gfx.createMeshPtrWithData then
    function gfx.createMeshPtrWithData(pGfxContext, pMeshVertexInputLayout, format, vertices, indexType, indices)
        error("gfx.createMeshPtrWithData: C binding not loaded")
    end
end

if not gfx.updateMeshPtr then
    function gfx.updateMeshPtr(pGfxContext, pMesh, format, vertices, indexType, indices)
        error("gfx.updateMeshPtr: C binding not loaded")
    end
end

if not gfx.destroyMeshPtr then
    function gfx.destroyMeshPtr(pGfxContext, pMesh)
        error("gfx.destroyMeshPtr: C binding not loaded")
    end
end

if not gfx.getGlobalMaterialPtr then
    function gfx.getGlobalMaterialPtr(pGfxContext)
        error("gfx.getGlobalMaterialPtr: C binding not loaded")
    end
end

if not gfx.getSubpassMaterialPtr then
    function gfx.getSubpassMaterialPtr(pGfxContext, pRenderPass, subpassIndex)
        error("gfx.getSubpassMaterialPtr: C binding not loaded")
    end
end

if not gfx.createPipelineMaterialPtr then
    function gfx.createPipelineMaterialPtr(pGfxContext, pPipeline)
        error("gfx.createPipelineMaterialPtr: C binding not loaded")
    end
end

if not gfx.destroyPipelineMaterialPtr then
    function gfx.destroyPipelineMaterialPtr(pGfxContext, pMaterial)
        error("gfx.destroyPipelineMaterialPtr: C binding not loaded")
    end
end

if not gfx.updateMaterialPtr then
    function gfx.updateMaterialPtr(pGfxContext, pMaterial, inputBindings)
        error("gfx.updateMaterialPtr: C binding not loaded")
    end
end

if not gfx.createImagePtr then
    function gfx.createImagePtr(pGfxContext, vkExtent3D, vkFormat, vkImageTiling, vkImageUsageFlags, vkMemoryPropertyFlags, vkImageAspectFlags, data)
        error("gfx.createImagePtr: C binding not loaded")
    end
end

if not gfx.destroyImagePtr then
    function gfx.destroyImagePtr(pGfxContext, pImage)
        error("gfx.destroyImagePtr: C binding not loaded")
    end
end

if not gfx.createASTCFromMemory then
    function gfx.createASTCFromMemory(buffer, size)
        error("gfx.createASTCFromMemory: C binding not loaded")
    end
end

if not gfx.destroyASTCImage then
    function gfx.destroyASTCImage(astcImage)
        error("gfx.destroyASTCImage: C binding not loaded")
    end
end

-- Sampler creation convenience functions
if not gfx.createSamplerPtr then
    function gfx.createSamplerPtr(pGfxContext, magFilter, minFilter, mipmapMode, addressModeU, addressModeV, addressModeW, mipLodBias, anisotropyEnable, maxAnisotropy, minLod, maxLod, borderColor)
        error("gfx.createSamplerPtr: C binding not loaded")
    end
end

if not gfx.destroySamplerPtr then
    function gfx.destroySamplerPtr(pGfxContext, pSampler)
        error("gfx.destroySamplerPtr: C binding not loaded")
    end
end

-- Font library functions
if not gfx.createTknFontLibraryPtr then
    function gfx.createTknFontLibraryPtr()
        error("gfx.createTknFontLibraryPtr: C binding not loaded")
    end
end

if not gfx.destroyTknFontLibraryPtr then
    function gfx.destroyTknFontLibraryPtr(pTknFontLibrary)
        error("gfx.destroyTknFontLibraryPtr: C binding not loaded")
    end
end

if not gfx.createTknFontPtr then
    function gfx.createTknFontPtr(pTknFontLibrary, fontPath, fontSize, atlasLength)
        error("gfx.createTknFontPtr: C binding not loaded")
    end
end

if not gfx.destroyTknFontPtr then
    function gfx.destroyTknFontPtr(pTknFont)
        error("gfx.destroyTknFontPtr: C binding not loaded")
    end
end

if not gfx.loadTknChar then
    function gfx.loadTknChar(pTknFont, unicode)
        error("gfx.loadTknChar: C binding not loaded")
    end
end

return gfx
