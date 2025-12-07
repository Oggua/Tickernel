local tkn = require("tkn")
local geometryPipeline = require("deferredRenderer.geometryPipeline")
local lightingPipeline = require("deferredRenderer.lightingPipeline")
local deferredRenderPass = {}

function deferredRenderPass.setup(pGfxContext, assetsPath, renderPassIndex)
    -- Vertex format for voxel meshes
    deferredRenderPass.vertexFormat = {{
        name = "position",
        type = tkn.type.float,
        count = 3,
    }, {
        name = "color",
        type = tkn.type.uint32,
        count = 1,
    }, {
        name = "normal",
        type = tkn.type.uint32,
        count = 1,
    }}

    -- Instance format for model matrices
    deferredRenderPass.instanceFormat = {{
        name = "model",
        type = tkn.type.float,
        count = 16,
    }}

    -- Global uniform buffer format (view, projection, etc.)
    deferredRenderPass.globalUniformBufferFormat = {{
        name = "view",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "proj",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "inv_view_proj",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "pointSizeFactor",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "time",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "frameCount",
        type = tkn.type.int32,
        count = 1,
    }, {
        name = "near",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "far",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "fov",
        type = tkn.type.float,
        count = 1,
    }}

    -- Lights uniform buffer format
    deferredRenderPass.lightsUniformBufferFormat = {{
        name = "directionalLightColor",
        type = tkn.type.float,
        count = 4,
    }, {
        name = "directionalLightDirection",
        type = tkn.type.float,
        count = 4,
    }, {
        -- PointLight array: 128 lights × (vec4 color + vec3 position + float range) = 128 × 8 floats
        name = "pointLights",
        type = tkn.type.float,
        count = 128 * 8,
    }, {
        name = "pointLightCount",
        type = tkn.type.int32,
        count = 1,
    }}

    local depthVkFormat = tkn.getSupportedFormat(pGfxContext, {VK_FORMAT_D32_SFLOAT, VK_FORMAT_D24_UNORM_S8_UINT, VK_FORMAT_D32_SFLOAT_S8_UINT}, VK_IMAGE_TILING_OPTIMAL, VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT)
    deferredRenderPass.pDepthAttachment = tkn.createDynamicAttachmentPtr(pGfxContext, depthVkFormat, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_DEPTH_BIT, 1)
    deferredRenderPass.pAlbedoAttachment = tkn.createDynamicAttachmentPtr(pGfxContext, VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_COLOR_BIT, 1)
    deferredRenderPass.pNormalAttachment = tkn.createDynamicAttachmentPtr(pGfxContext, VK_FORMAT_A2R10G10B10_UNORM_PACK32, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_COLOR_BIT, 1)
    deferredRenderPass.pSwapchainAttachment = tkn.getSwapchainAttachmentPtr(pGfxContext)
    local pAttachments = {deferredRenderPass.pDepthAttachment, deferredRenderPass.pAlbedoAttachment, deferredRenderPass.pNormalAttachment, deferredRenderPass.pSwapchainAttachment}

    local depthAttachmentDescription = {
        samples = VK_SAMPLE_COUNT_1_BIT,
        loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };
    local albedoAttachmentDescription = {
        samples = VK_SAMPLE_COUNT_1_BIT,
        loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    };
    local normalAttachmentDescription = {
        samples = VK_SAMPLE_COUNT_1_BIT,
        loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    };
    local swapchainAttachmentDescription = {
        samples = VK_SAMPLE_COUNT_1_BIT,
        loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    local vkAttachmentDescriptions = {depthAttachmentDescription, albedoAttachmentDescription, normalAttachmentDescription, swapchainAttachmentDescription};

    local vkClearValues = {{
        depth = 1.0,
        stencil = 0,
    }, {0.0, 0.0, 0.0, 1.0}, {0.0, 0.0, 0.0, 1.0}, {0.0, 0.0, 0.0, 1.0}};

    local geometrySubpassDescription = {
        pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {},
        pColorAttachments = {{
            attachment = 1,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }, {
            attachment = 2,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pDepthStencilAttachment = {
            attachment = 0,
            layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        },
        pPreserveAttachments = {},
    }

    local ligthtingSubpassDescription = {
        pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {{
            attachment = 0,
            layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL,
        }, {
            attachment = 1,
            layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        }, {
            attachment = 2,
            layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        }},
        pColorAttachments = {{
            attachment = 3,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pResolveAttachments = {},
        pDepthStencilAttachment = nil,
        pPreserveAttachments = {},
    }

    local vkSubpassDescriptions = {geometrySubpassDescription, ligthtingSubpassDescription}

    local spvPathsArray = {{}, {assetsPath .. "/shaders/lighting.subpass.frag.spv"}}

    local vkSubpassDependencies = {{
        srcSubpass = VK_SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        srcAccessMask = VK_ACCESS_MEMORY_READ_BIT,
        dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 0,
        dstSubpass = 1,
        srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
        dstStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        dstAccessMask = VK_ACCESS_INPUT_ATTACHMENT_READ_BIT,
        dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 1,
        dstSubpass = VK_SUBPASS_EXTERNAL,
        srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        dstStageMask = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dstAccessMask = VK_ACCESS_MEMORY_READ_BIT,
        dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT,
    }}
    deferredRenderPass.pRenderPass = tkn.createRenderPassPtr(pGfxContext, vkAttachmentDescriptions, pAttachments, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)

    -- Create vertex input layouts
    deferredRenderPass.pVoxelVertexInputLayout = tkn.createVertexInputLayoutPtr(pGfxContext, deferredRenderPass.vertexFormat)
    deferredRenderPass.pInstanceVertexInputLayout = tkn.createVertexInputLayoutPtr(pGfxContext, deferredRenderPass.instanceFormat)

    -- Create global uniform buffer
    local pGlobalUniformBuffer = {
        view = {0.7071, -0.4082, 0.5774, 0, 0, 0.8165, 0.5774, 0, -0.7071, -0.4082, 0.5774, 0, 0, 0, -8.6603, 1},
        proj = {1.3584, 0, 0, 0, 0, 2.4142, 0, 0, 0, 0, -1.0020, -1, 0, 0, -0.2002, 0},
        inv_view_proj = {0.5206, 0, -0.5206, 0, -0.3007, 0.6013, -0.3007, 0, 0.0231, 0.0231, 0.0231, 0, 2.3077, 4.3301, 2.3077, 43.301},
        pointSizeFactor = 1000.0,
        time = 0.0,
        frameCount = 0,
        near = 0.1,
        far = 100.0,
        fov = 90.0,
    }
    deferredRenderPass.pGlobalUniformBuffer = tkn.createUniformBufferPtr(pGfxContext, deferredRenderPass.globalUniformBufferFormat, pGlobalUniformBuffer)
    local inputBindings = {{
        vkDescriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pUniformBuffer = deferredRenderPass.pGlobalUniformBuffer,
        binding = 0,
    }}
    deferredRenderPass.pGlobalMaterial = tkn.getGlobalMaterialPtr(pGfxContext)
    tkn.updateMaterialPtr(pGfxContext, deferredRenderPass.pGlobalMaterial, inputBindings)

    -- Create lights uniform buffer
    local pLightsUniformBuffer = {
        directionalLightColor = {1.0, 1.0, 0.9, 1.0},
        directionalLightDirection = {0.5, -1.0, 0.3, 0.0},
        pointLights = {},
        pointLightCount = 0,
    }
    for i = 1, 128 * 8 do
        table.insert(pLightsUniformBuffer.pointLights, 0.0)
    end
    deferredRenderPass.pLightsUniformBuffer = tkn.createUniformBufferPtr(pGfxContext, deferredRenderPass.lightsUniformBufferFormat, pLightsUniformBuffer)

    -- Bind lights uniform buffer to lighting subpass material
    deferredRenderPass.pLightingSubpassMaterial = tkn.getSubpassMaterialPtr(pGfxContext, deferredRenderPass.pRenderPass, 1)
    local lightingInputBindings = {{
        vkDescriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pUniformBuffer = deferredRenderPass.pLightsUniformBuffer,
        binding = 3,
    }}
    tkn.updateMaterialPtr(pGfxContext, deferredRenderPass.pLightingSubpassMaterial, lightingInputBindings)

    local pipelineIndex = 0
    deferredRenderPass.pGeometryPipeline = geometryPipeline.createPipelinePtr(pGfxContext, deferredRenderPass.pRenderPass, pipelineIndex, assetsPath, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.pInstanceVertexInputLayout)
    pipelineIndex = pipelineIndex + 1
    deferredRenderPass.pLightingPipeline = lightingPipeline.createPipelinePtr(pGfxContext, deferredRenderPass.pRenderPass, pipelineIndex, assetsPath)
    deferredRenderPass.pGeometryMaterial = tkn.createPipelineMaterialPtr(pGfxContext, deferredRenderPass.pGeometryPipeline)
    deferredRenderPass.pLightingMaterial = tkn.createPipelineMaterialPtr(pGfxContext, deferredRenderPass.pLightingPipeline)

    local pLightingDrawCall = tkn.createDrawCallPtr(pGfxContext, deferredRenderPass.pLightingPipeline, deferredRenderPass.pLightingMaterial, nil, nil)
    tkn.insertDrawCallPtr(pLightingDrawCall, 0)
    return renderPassIndex
end

function deferredRenderPass.teardown(pGfxContext)
    geometryPipeline.destroyPipelinePtr(pGfxContext, deferredRenderPass.pGeometryPipeline)
    lightingPipeline.destroyPipelinePtr(pGfxContext, deferredRenderPass.pLightingPipeline)
    deferredRenderPass.pGeometryMaterial = nil
    deferredRenderPass.pLightingMaterial = nil

    -- Destroy uniform buffers
    tkn.destroyUniformBufferPtr(pGfxContext, deferredRenderPass.pGlobalUniformBuffer)
    deferredRenderPass.pGlobalUniformBuffer = nil
    deferredRenderPass.pGlobalMaterial = nil
    tkn.destroyUniformBufferPtr(pGfxContext, deferredRenderPass.pLightsUniformBuffer)
    deferredRenderPass.pLightsUniformBuffer = nil
    deferredRenderPass.pLightingSubpassMaterial = nil

    tkn.destroyRenderPassPtr(pGfxContext, deferredRenderPass.pRenderPass)

    deferredRenderPass.pRenderPass = nil
    deferredRenderPass.pGeometryPipeline = nil
    deferredRenderPass.pLightingPipeline = nil

    tkn.destroyDynamicAttachmentPtr(pGfxContext, deferredRenderPass.pNormalAttachment)
    tkn.destroyDynamicAttachmentPtr(pGfxContext, deferredRenderPass.pAlbedoAttachment)
    tkn.destroyDynamicAttachmentPtr(pGfxContext, deferredRenderPass.pDepthAttachment)

    -- Destroy vertex input layouts
    tkn.destroyVertexInputLayoutPtr(pGfxContext, deferredRenderPass.pInstanceVertexInputLayout)
    tkn.destroyVertexInputLayoutPtr(pGfxContext, deferredRenderPass.pVoxelVertexInputLayout)
    deferredRenderPass.pInstanceVertexInputLayout = nil
    deferredRenderPass.pVoxelVertexInputLayout = nil
end

return deferredRenderPass
