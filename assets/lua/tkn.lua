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
function tkn.createImagePtrWithPath(tknContext, path)
    local astcFile = io.open(path, "rb")
    if astcFile then
        local content = astcFile:read("*all")
        astcFile:close()
        local pASTC, data, width, height, vkFormat, size = tkn.createASTCFromMemory(content)
        if pASTC then
            local vkExtent3D = {
                width = width,
                height = height,
                depth = 1,
            }
            local pImage = tkn.createImagePtr(tknContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, VK_IMAGE_USAGE_TEXTURE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, VK_IMAGE_ASPECT_COLOR_BIT, data)
            tkn.destroyASTCImage(pASTC)
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
function tkn.createDefaultMeshPtr(pGfxContext, format, pMeshVertexInputLayout, vertexCount, indexType, indexCount)
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

    return tkn.createMeshPtrWithData(pGfxContext, pMeshVertexInputLayout, format, vertices, indexType, indices)
end

-- Function declarations for IDE support (only used if C binding not available)
if not tkn.getSupportedFormat then
    function tkn.getSupportedFormat(pGfxContext, candidates, tiling, features)
        error("tkn.getSupportedFormat: C binding not loaded")
    end
end

if not tkn.createDynamicAttachmentPtr then
    function tkn.createDynamicAttachmentPtr(pGfxContext, vkFormat, vkImageUsageFlags, vkImageAspectFlags, scaler)
        error("tkn.createDynamicAttachmentPtr: C binding not loaded")
    end
end

if not tkn.destroyDynamicAttachmentPtr then
    function tkn.destroyDynamicAttachmentPtr(pGfxContext, pAttachment)
        error("tkn.destroyDynamicAttachmentPtr: C binding not loaded")
    end
end

if not tkn.getSwapchainAttachmentPtr then
    function tkn.getSwapchainAttachmentPtr(pGfxContext)
        error("tkn.getSwapchainAttachmentPtr: C binding not loaded")
    end
end

if not tkn.createVertexInputLayoutPtr then
    function tkn.createVertexInputLayoutPtr(pGfxContext, format)
        error("tkn.createVertexInputLayoutPtr: C binding not loaded")
    end
end

if not tkn.destroyVertexInputLayoutPtr then
    function tkn.destroyVertexInputLayoutPtr(pGfxContext, pLayout)
        error("tkn.destroyVertexInputLayoutPtr: C binding not loaded")
    end
end

if not tkn.createRenderPassPtr then
    function tkn.createRenderPassPtr(pGfxContext, vkAttachmentDescriptions, inputAttachmentPtrs, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)
        error("tkn.createRenderPassPtr: C binding not loaded")
    end
end

if not tkn.destroyRenderPassPtr then
    function tkn.destroyRenderPassPtr(pGfxContext, pRenderPass)
        error("tkn.destroyRenderPassPtr: C binding not loaded")
    end
end

if not tkn.createPipelinePtr then
    function tkn.createPipelinePtr(pGfxContext, pRenderPass, subpassIndex, spvPaths, pMeshVertexInputLayout, pInstanceVertexInputLayout, vkPipelineInputAssemblyStateCreateInfo, vkPipelineViewportStateCreateInfo, vkPipelineRasterizationStateCreateInfo, vkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, vkPipelineDynamicStateCreateInfo)
        error("tkn.createPipelinePtr: C binding not loaded")
    end
end

if not tkn.destroyPipelinePtr then
    function tkn.destroyPipelinePtr(pGfxContext, pPipeline)
        error("tkn.destroyPipelinePtr: C binding not loaded")
    end
end

if not tkn.createDrawCallPtr then
    function tkn.createDrawCallPtr(pGfxContext, pMaterial, pMesh, pInstance)
        error("tkn.createDrawCallPtr: C binding not loaded")
    end
end

if not tkn.destroyDrawCallPtr then
    function tkn.destroyDrawCallPtr(pGfxContext, pDrawCall)
        error("tkn.destroyDrawCallPtr: C binding not loaded")
    end
end

if not tkn.insertDrawCallPtr then
    function tkn.insertDrawCallPtr(pDrawCall, index)
        error("tkn.insertDrawCallPtr: C binding not loaded")
    end
end

if not tkn.removeDrawCallPtr then
    function tkn.removeDrawCallPtr(pDrawCall)
        error("tkn.removeDrawCallPtr: C binding not loaded")
    end
end

if not tkn.removeDrawCallAtIndex then
    function tkn.removeDrawCallAtIndex(pPipeline, index)
        error("tkn.removeDrawCallAtIndex: C binding not loaded")
    end
end

if not tkn.getDrawCallAtIndex then
    function tkn.getDrawCallAtIndex(pPipeline, index)
        error("tkn.getDrawCallAtIndex: C binding not loaded")
    end
end

if not tkn.getDrawCallCount then
    function tkn.getDrawCallCount(pPipeline)
        error("tkn.getDrawCallCount: C binding not loaded")
    end
end

if not tkn.createUniformBufferPtr then
    function tkn.createUniformBufferPtr(pGfxContext, format, buffer)
        error("tkn.createUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.destroyUniformBufferPtr then
    function tkn.destroyUniformBufferPtr(pGfxContext, pUniformBuffer)
        error("tkn.destroyUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.updateUniformBufferPtr then
    function tkn.updateUniformBufferPtr(pGfxContext, pUniformBuffer, format, buffer, size)
        error("tkn.updateUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.createInstancePtr then
    function tkn.createInstancePtr(pGfxContext, pVertexInputLayout, format, instances)
        error("tkn.createInstancePtr: C binding not loaded")
    end
end

if not tkn.destroyInstancePtr then
    function tkn.destroyInstancePtr(pGfxContext, pInstance)
        error("tkn.destroyInstancePtr: C binding not loaded")
    end
end

if not tkn.createMeshPtrWithData then
    function tkn.createMeshPtrWithData(pGfxContext, pMeshVertexInputLayout, format, vertices, indexType, indices)
        error("tkn.createMeshPtrWithData: C binding not loaded")
    end
end

if not tkn.updateMeshPtr then
    function tkn.updateMeshPtr(pGfxContext, pMesh, format, vertices, indexType, indices)
        error("tkn.updateMeshPtr: C binding not loaded")
    end
end

if not tkn.destroyMeshPtr then
    function tkn.destroyMeshPtr(pGfxContext, pMesh)
        error("tkn.destroyMeshPtr: C binding not loaded")
    end
end

if not tkn.getGlobalMaterialPtr then
    function tkn.getGlobalMaterialPtr(pGfxContext)
        error("tkn.getGlobalMaterialPtr: C binding not loaded")
    end
end

if not tkn.getSubpassMaterialPtr then
    function tkn.getSubpassMaterialPtr(pGfxContext, pRenderPass, subpassIndex)
        error("tkn.getSubpassMaterialPtr: C binding not loaded")
    end
end

if not tkn.createPipelineMaterialPtr then
    function tkn.createPipelineMaterialPtr(pGfxContext, pPipeline)
        error("tkn.createPipelineMaterialPtr: C binding not loaded")
    end
end

if not tkn.destroyPipelineMaterialPtr then
    function tkn.destroyPipelineMaterialPtr(pGfxContext, pMaterial)
        error("tkn.destroyPipelineMaterialPtr: C binding not loaded")
    end
end

if not tkn.updateMaterialPtr then
    function tkn.updateMaterialPtr(pGfxContext, pMaterial, inputBindings)
        error("tkn.updateMaterialPtr: C binding not loaded")
    end
end

if not tkn.createImagePtr then
    function tkn.createImagePtr(pGfxContext, vkExtent3D, vkFormat, vkImageTiling, vkImageUsageFlags, vkMemoryPropertyFlags, vkImageAspectFlags, data)
        error("tkn.createImagePtr: C binding not loaded")
    end
end

if not tkn.destroyImagePtr then
    function tkn.destroyImagePtr(pGfxContext, pImage)
        error("tkn.destroyImagePtr: C binding not loaded")
    end
end

if not tkn.createASTCFromMemory then
    function tkn.createASTCFromMemory(buffer, size)
        error("tkn.createASTCFromMemory: C binding not loaded")
    end
end

if not tkn.destroyASTCImage then
    function tkn.destroyASTCImage(astcImage)
        error("tkn.destroyASTCImage: C binding not loaded")
    end
end

-- Sampler creation convenience functions
if not tkn.createSamplerPtr then
    function tkn.createSamplerPtr(pGfxContext, magFilter, minFilter, mipmapMode, addressModeU, addressModeV, addressModeW, mipLodBias, anisotropyEnable, maxAnisotropy, minLod, maxLod, borderColor)
        error("tkn.createSamplerPtr: C binding not loaded")
    end
end

if not tkn.destroySamplerPtr then
    function tkn.destroySamplerPtr(pGfxContext, pSampler)
        error("tkn.destroySamplerPtr: C binding not loaded")
    end
end

-- Font library functions
if not tkn.createTknFontLibraryPtr then
    function tkn.createTknFontLibraryPtr()
        error("tkn.createTknFontLibraryPtr: C binding not loaded")
    end
end

if not tkn.destroyTknFontLibraryPtr then
    function tkn.destroyTknFontLibraryPtr(pTknFontLibrary)
        error("tkn.destroyTknFontLibraryPtr: C binding not loaded")
    end
end

if not tkn.createTknFontPtr then
    function tkn.createTknFontPtr(pTknFontLibrary, fontPath, fontSize, atlasLength)
        error("tkn.createTknFontPtr: C binding not loaded")
    end
end

if not tkn.destroyTknFontPtr then
    function tkn.destroyTknFontPtr(pTknFont)
        error("tkn.destroyTknFontPtr: C binding not loaded")
    end
end

if not tkn.flushTknFontPtr then
    function tkn.flushTknFontPtr(pTknFont, pGfxContext)
        error("tkn.flushTknFontPtr: C binding not loaded")
    end
end

if not tkn.loadTknChar then
    function tkn.loadTknChar(pTknFont, unicode)
        error("tkn.loadTknChar: C binding not loaded")
    end
end

return tkn
