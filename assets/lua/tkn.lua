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
            local pImage = tkn.tknCreateImagePtr(tknContext, vkExtent3D, vkFormat, VK_IMAGE_TILING_OPTIMAL, VK_IMAGE_USAGE_TEXTURE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, VK_IMAGE_ASPECT_COLOR_BIT, data)
            tkn.tknDestroyASTCImage(pASTC)
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
function tkn.tknCreateDefaultMeshPtr(pGfxContext, format, pMeshVertexInputLayout, vertexCount, indexType, indexCount)
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

    return tkn.tknCreateMeshPtrWithData(pGfxContext, pMeshVertexInputLayout, format, vertices, indexType, indices)
end

-- Function declarations for IDE support (only used if C binding not available)
if not tkn.tknGetSupportedFormat then
    function tkn.tknGetSupportedFormat(pGfxContext, candidates, tiling, features)
        error("tkn.tknGetSupportedFormat: C binding not loaded")
    end
end

if not tkn.tknCreateDynamicAttachmentPtr then
    function tkn.tknCreateDynamicAttachmentPtr(pGfxContext, vkFormat, vkImageUsageFlags, vkImageAspectFlags, scaler)
        error("tkn.tknCreateDynamicAttachmentPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyDynamicAttachmentPtr then
    function tkn.tknDestroyDynamicAttachmentPtr(pGfxContext, pAttachment)
        error("tkn.tknDestroyDynamicAttachmentPtr: C binding not loaded")
    end
end

if not tkn.tknGetSwapchainAttachmentPtr then
    function tkn.tknGetSwapchainAttachmentPtr(pGfxContext)
        error("tkn.tknGetSwapchainAttachmentPtr: C binding not loaded")
    end
end

if not tkn.tknCreateVertexInputLayoutPtr then
    function tkn.tknCreateVertexInputLayoutPtr(pGfxContext, format)
        error("tkn.tknCreateVertexInputLayoutPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyVertexInputLayoutPtr then
    function tkn.tknDestroyVertexInputLayoutPtr(pGfxContext, pLayout)
        error("tkn.tknDestroyVertexInputLayoutPtr: C binding not loaded")
    end
end

if not tkn.tknCreateRenderPassPtr then
    function tkn.tknCreateRenderPassPtr(pGfxContext, vkAttachmentDescriptions, inputAttachmentPtrs, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)
        error("tkn.tknCreateRenderPassPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyRenderPassPtr then
    function tkn.tknDestroyRenderPassPtr(pGfxContext, pRenderPass)
        error("tkn.tknDestroyRenderPassPtr: C binding not loaded")
    end
end

if not tkn.tknCreatePipelinePtr then
    function tkn.tknCreatePipelinePtr(pGfxContext, pRenderPass, subpassIndex, spvPaths, pMeshVertexInputLayout, pInstanceVertexInputLayout, vkPipelineInputAssemblyStateCreateInfo, vkPipelineViewportStateCreateInfo, vkPipelineRasterizationStateCreateInfo, vkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, vkPipelineDynamicStateCreateInfo)
        error("tkn.tknCreatePipelinePtr: C binding not loaded")
    end
end

if not tkn.tknDestroyPipelinePtr then
    function tkn.tknDestroyPipelinePtr(pGfxContext, pPipeline)
        error("tkn.tknDestroyPipelinePtr: C binding not loaded")
    end
end

if not tkn.tknCreateDrawCallPtr then
    function tkn.tknCreateDrawCallPtr(pGfxContext, pMaterial, pMesh, pInstance)
        error("tkn.tknCreateDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyDrawCallPtr then
    function tkn.tknDestroyDrawCallPtr(pGfxContext, pDrawCall)
        error("tkn.tknDestroyDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknInsertDrawCallPtr then
    function tkn.tknInsertDrawCallPtr(pDrawCall, index)
        error("tkn.tknInsertDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknRemoveDrawCallPtr then
    function tkn.tknRemoveDrawCallPtr(pDrawCall)
        error("tkn.tknRemoveDrawCallPtr: C binding not loaded")
    end
end

if not tkn.tknRemoveDrawCallAtIndex then
    function tkn.tknRemoveDrawCallAtIndex(pRenderPass, subpassIndex, index)
        error("tkn.tknRemoveDrawCallAtIndex: C binding not loaded")
    end
end

if not tkn.tknGetDrawCallAtIndex then
    function tkn.tknGetDrawCallAtIndex(pRenderPass, subpassIndex, index)
        error("tkn.tknGetDrawCallAtIndex: C binding not loaded")
    end
end

if not tkn.tknGetDrawCallCount then
    function tkn.tknGetDrawCallCount(pRenderPass, subpassIndex)
        error("tkn.tknGetDrawCallCount: C binding not loaded")
    end
end

if not tkn.tknCreateUniformBufferPtr then
    function tkn.tknCreateUniformBufferPtr(pGfxContext, format, buffer)
        error("tkn.tknCreateUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyUniformBufferPtr then
    function tkn.tknDestroyUniformBufferPtr(pGfxContext, pUniformBuffer)
        error("tkn.tknDestroyUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.tknUpdateUniformBufferPtr then
    function tkn.tknUpdateUniformBufferPtr(pGfxContext, pUniformBuffer, format, buffer, size)
        error("tkn.tknUpdateUniformBufferPtr: C binding not loaded")
    end
end

if not tkn.tknCreateInstancePtr then
    function tkn.tknCreateInstancePtr(pGfxContext, pVertexInputLayout, format, instances)
        error("tkn.tknCreateInstancePtr: C binding not loaded")
    end
end

if not tkn.tknDestroyInstancePtr then
    function tkn.tknDestroyInstancePtr(pGfxContext, pInstance)
        error("tkn.tknDestroyInstancePtr: C binding not loaded")
    end
end

if not tkn.tknCreateMeshPtrWithData then
    function tkn.tknCreateMeshPtrWithData(pGfxContext, pMeshVertexInputLayout, format, vertices, indexType, indices)
        error("tkn.tknCreateMeshPtrWithData: C binding not loaded")
    end
end

if not tkn.tknUpdateMeshPtr then
    function tkn.tknUpdateMeshPtr(pGfxContext, pMesh, format, vertices, indexType, indices)
        error("tkn.tknUpdateMeshPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyMeshPtr then
    function tkn.tknDestroyMeshPtr(pGfxContext, pMesh)
        error("tkn.tknDestroyMeshPtr: C binding not loaded")
    end
end

if not tkn.tknGetGlobalMaterialPtr then
    function tkn.tknGetGlobalMaterialPtr(pGfxContext)
        error("tkn.tknGetGlobalMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknGetSubpassMaterialPtr then
    function tkn.tknGetSubpassMaterialPtr(pGfxContext, pRenderPass, subpassIndex)
        error("tkn.tknGetSubpassMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknCreatePipelineMaterialPtr then
    function tkn.tknCreatePipelineMaterialPtr(pGfxContext, pPipeline)
        error("tkn.tknCreatePipelineMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyPipelineMaterialPtr then
    function tkn.tknDestroyPipelineMaterialPtr(pGfxContext, pMaterial)
        error("tkn.tknDestroyPipelineMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknUpdateMaterialPtr then
    function tkn.tknUpdateMaterialPtr(pGfxContext, pMaterial, inputBindings)
        error("tkn.tknUpdateMaterialPtr: C binding not loaded")
    end
end

if not tkn.tknCreateImagePtr then
    function tkn.tknCreateImagePtr(pGfxContext, vkExtent3D, vkFormat, vkImageTiling, vkImageUsageFlags, vkMemoryPropertyFlags, vkImageAspectFlags, data)
        error("tkn.tknCreateImagePtr: C binding not loaded")
    end
end

if not tkn.tknDestroyImagePtr then
    function tkn.tknDestroyImagePtr(pGfxContext, pImage)
        error("tkn.tknDestroyImagePtr: C binding not loaded")
    end
end

if not tkn.tknCreateASTCFromMemory then
    function tkn.tknCreateASTCFromMemory(buffer, size)
        error("tkn.tknCreateASTCFromMemory: C binding not loaded")
    end
end

if not tkn.tknDestroyASTCImage then
    function tkn.tknDestroyASTCImage(astcImage)
        error("tkn.tknDestroyASTCImage: C binding not loaded")
    end
end

-- Sampler creation convenience functions
if not tkn.tknCreateSamplerPtr then
    function tkn.tknCreateSamplerPtr(pGfxContext, magFilter, minFilter, mipmapMode, addressModeU, addressModeV, addressModeW, mipLodBias, anisotropyEnable, maxAnisotropy, minLod, maxLod, borderColor)
        error("tkn.tknCreateSamplerPtr: C binding not loaded")
    end
end

if not tkn.tknDestroySamplerPtr then
    function tkn.tknDestroySamplerPtr(pGfxContext, pSampler)
        error("tkn.tknDestroySamplerPtr: C binding not loaded")
    end
end

-- Font library functions
if not tkn.tknCreateTknFontLibraryPtr then
    function tkn.tknCreateTknFontLibraryPtr()
        error("tkn.tknCreateTknFontLibraryPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyTknFontLibraryPtr then
    function tkn.tknDestroyTknFontLibraryPtr(pTknFontLibrary)
        error("tkn.tknDestroyTknFontLibraryPtr: C binding not loaded")
    end
end

if not tkn.tknCreateTknFontPtr then
    function tkn.tknCreateTknFontPtr(pTknFontLibrary, fontPath, fontSize, atlasLength)
        error("tkn.tknCreateTknFontPtr: C binding not loaded")
    end
end

if not tkn.tknDestroyTknFontPtr then
    function tkn.tknDestroyTknFontPtr(pTknFontLibrary, pTknFont, pGfxContext)
        error("tkn.tknDestroyTknFontPtr: C binding not loaded")
    end
end

if not tkn.tknFlushTknFontPtr then
    function tkn.tknFlushTknFontPtr(pTknFont, pGfxContext)
        error("tkn.tknFlushTknFontPtr: C binding not loaded")
    end
end

if not tkn.tknLoadTknChar then
    function tkn.tknLoadTknChar(pTknFont, unicode)
        error("tkn.tknLoadTknChar: C binding not loaded")
    end
end

if not tkn.tknWaitRenderFence then
    ---Wait for GPU render fence before modifying GPU resources
    ---@param pGfxContext lightuserdata Graphics context pointer
    function tkn.tknWaitRenderFence(pGfxContext)
        error("tkn.tknWaitRenderFence: C binding not loaded")
    end
end

return tkn
