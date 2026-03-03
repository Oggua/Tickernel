local tkn = require("tkn")
local vulkan = require("vulkan")
local geometryPipeline = require("deferredRenderer.geometryPipeline")
local lightingPipeline = require("deferredRenderer.lightingPipeline")
local deferredRenderPass = {}

function deferredRenderPass.setup(pTknGfxContext, assetsPath, renderPassIndex, pDepthStencilAttachment, pSwapchainAttachment)
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
    }, {
        name = "pbr",
        type = tkn.type.uint32,
        count = 1,
    }}

    -- Instance format for model matrices
    deferredRenderPass.instanceFormat = {{
        name = "model",
        type = tkn.type.float,
        count = 16,
    }}

    deferredRenderPass.geometryUniformBufferFormat = {{
        name = "pointSize",
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

    deferredRenderPass.pAlbedoAttachment = tkn.tknCreateDynamicAttachmentPtr(pTknGfxContext, vulkan.VK_FORMAT_R8G8B8A8_UNORM, vulkan.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, vulkan.VK_IMAGE_ASPECT_COLOR_BIT, 1)
    deferredRenderPass.pNormalAttachment = tkn.tknCreateDynamicAttachmentPtr(pTknGfxContext, vulkan.VK_FORMAT_A8B8G8R8_UNORM_PACK32, vulkan.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, vulkan.VK_IMAGE_ASPECT_COLOR_BIT, 1)

    local pAttachments = {pDepthStencilAttachment, deferredRenderPass.pAlbedoAttachment, deferredRenderPass.pNormalAttachment, pSwapchainAttachment}

    local depthAttachmentDescription = {
        samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
        loadOp = vulkan.VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = vulkan.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = vulkan.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };
    local albedoAttachmentDescription = {
        samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
        loadOp = vulkan.VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = vulkan.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    };
    local normalAttachmentDescription = {
        samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
        loadOp = vulkan.VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = vulkan.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    };
    local swapchainAttachmentDescription = {
        samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
        loadOp = vulkan.VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = vulkan.VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp = vulkan.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = vulkan.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    local vkAttachmentDescriptions = {depthAttachmentDescription, albedoAttachmentDescription, normalAttachmentDescription, swapchainAttachmentDescription};

    local vkClearValues = {{
        depth = 1.0,
        stencil = 0,
    }, {0.0, 0.0, 0.0, 1.0}, {0.0, 0.0, 0.0, 1.0}, {0.15, 0.28, 0.20, 1.0}};

    local geometrySubpassDescription = {
        pipelineBindPoint = vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {},
        pColorAttachments = {{
            attachment = 1,
            layout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }, {
            attachment = 2,
            layout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pDepthStencilAttachment = {
            attachment = 0,
            layout = vulkan.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        },
        pPreserveAttachments = {},
    }

    local ligthtingSubpassDescription = {
        pipelineBindPoint = vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {{
            attachment = 0,
            layout = vulkan.VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL,
        }, {
            attachment = 1,
            layout = vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        }, {
            attachment = 2,
            layout = vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        }},
        pColorAttachments = {{
            attachment = 3,
            layout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pResolveAttachments = {},
        pDepthStencilAttachment = nil,
        pPreserveAttachments = {},
    }

    local vkSubpassDescriptions = {geometrySubpassDescription, ligthtingSubpassDescription}

    local spvPathsArray = {{assetsPath .. "/shaders/geometry.subpass.vert.spv"}, {assetsPath .. "/shaders/lighting.subpass.frag.spv"}}

    local vkSubpassDependencies = {{
        srcSubpass = vulkan.VK_SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = vulkan.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        dstStageMask = vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vulkan.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        srcAccessMask = vulkan.VK_ACCESS_MEMORY_READ_BIT,
        dstAccessMask = vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | vulkan.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        dependencyFlags = vulkan.VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 0,
        dstSubpass = 1,
        srcStageMask = vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vulkan.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
        dstStageMask = vulkan.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        srcAccessMask = vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | vulkan.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        dstAccessMask = vulkan.VK_ACCESS_INPUT_ATTACHMENT_READ_BIT,
        dependencyFlags = vulkan.VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 1,
        dstSubpass = vulkan.VK_SUBPASS_EXTERNAL,
        srcStageMask = vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        dstStageMask = vulkan.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        srcAccessMask = vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dstAccessMask = vulkan.VK_ACCESS_MEMORY_READ_BIT,
        dependencyFlags = vulkan.VK_DEPENDENCY_BY_REGION_BIT,
    }}
    deferredRenderPass.pTknRenderPass = tkn.tknCreateRenderPassPtr(pTknGfxContext, vkAttachmentDescriptions, pAttachments, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)

    -- Create vertex input layouts
    deferredRenderPass.pVoxelVertexInputLayout = tkn.tknCreateVertexInputLayoutPtr(pTknGfxContext, deferredRenderPass.vertexFormat)
    deferredRenderPass.pInstanceVertexInputLayout = tkn.tknCreateVertexInputLayoutPtr(pTknGfxContext, deferredRenderPass.instanceFormat)

    deferredRenderPass.pGeometrySubpassMaterial = tkn.tknGetSubpassMaterialPtr(pTknGfxContext, deferredRenderPass.pTknRenderPass, 0)
    local geometryUniformBuffer = {
        pointSize = 512.0,
    }
    deferredRenderPass.pGeometryUniformBuffer = tkn.tknCreateUniformBufferPtr(pTknGfxContext, deferredRenderPass.geometryUniformBufferFormat, geometryUniformBuffer)
    local geometryInputBindings = {{
        vkDescriptorType = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pTknUniformBuffer = deferredRenderPass.pGeometryUniformBuffer,
        binding = 0,
    }}
    tkn.tknUpdateMaterialPtr(pTknGfxContext, deferredRenderPass.pGeometrySubpassMaterial, geometryInputBindings)

    -- Create lights uniform buffer
    local lightsUniformBuffer = {
        directionalLightColor = {1.0, 1.0, 1.0, 2.0},
        directionalLightDirection = {0.4, 0.4, -0.8, 0.0},
        pointLights = { -- Light 3: warm orange
        0.6, 0.3, 0.9, 8.0, 4, 4, 1, 4.0, 0.6, 0.5, 0.3, 4.0, 8, 8, 1, 4.0, 0.6, 0.5, 0.3, 4.0, 8, 4, 1, 4.0},
        pointLightCount = 3,
    }
    -- pad pointLights to exactly 128 * 8 floats
    local desiredCount = 128 * 8
    local cur = #lightsUniformBuffer.pointLights
    for i = cur + 1, desiredCount do
        table.insert(lightsUniformBuffer.pointLights, 0.0)
    end
    deferredRenderPass.pLightsUniformBuffer = tkn.tknCreateUniformBufferPtr(pTknGfxContext, deferredRenderPass.lightsUniformBufferFormat, lightsUniformBuffer)

    -- Bind lights uniform buffer to lighting subpass material
    deferredRenderPass.pLightingSubpassMaterial = tkn.tknGetSubpassMaterialPtr(pTknGfxContext, deferredRenderPass.pTknRenderPass, 1)
    local lightingInputBindings = {{
        vkDescriptorType = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pTknUniformBuffer = deferredRenderPass.pLightsUniformBuffer,
        binding = 3,
    }}
    tkn.tknUpdateMaterialPtr(pTknGfxContext, deferredRenderPass.pLightingSubpassMaterial, lightingInputBindings)

    local pipelineIndex = 0
    deferredRenderPass.pGeometryPipeline = geometryPipeline.createPipelinePtr(pTknGfxContext, deferredRenderPass.pTknRenderPass, pipelineIndex, assetsPath, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.pInstanceVertexInputLayout)
    pipelineIndex = pipelineIndex + 1
    deferredRenderPass.pLightingPipeline = lightingPipeline.createPipelinePtr(pTknGfxContext, deferredRenderPass.pTknRenderPass, pipelineIndex, assetsPath)
    deferredRenderPass.pGeometryMaterial = tkn.tknCreatePipelineMaterialPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline)
    deferredRenderPass.pLightingMaterial = tkn.tknCreatePipelineMaterialPtr(pTknGfxContext, deferredRenderPass.pLightingPipeline)

    deferredRenderPass.pLightingDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pLightingPipeline, deferredRenderPass.pLightingMaterial, nil, nil)
end

function deferredRenderPass.teardown(pTknGfxContext)
    tkn.tknDestroyDrawCallPtr(pTknGfxContext, deferredRenderPass.pLightingDrawCall)

    geometryPipeline.destroyPipelinePtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline)
    lightingPipeline.destroyPipelinePtr(pTknGfxContext, deferredRenderPass.pLightingPipeline)
    deferredRenderPass.pGeometryMaterial = nil
    deferredRenderPass.pLightingMaterial = nil

    -- Destroy uniform buffers
    tkn.tknDestroyUniformBufferPtr(pTknGfxContext, deferredRenderPass.pLightsUniformBuffer)
    deferredRenderPass.pLightsUniformBuffer = nil
    deferredRenderPass.pLightingSubpassMaterial = nil

    tkn.tknDestroyUniformBufferPtr(pTknGfxContext, deferredRenderPass.pGeometryUniformBuffer)
    deferredRenderPass.pGeometryUniformBuffer = nil
    deferredRenderPass.pGeometrySubpassMaterial = nil

    tkn.tknDestroyRenderPassPtr(pTknGfxContext, deferredRenderPass.pTknRenderPass)

    deferredRenderPass.pTknRenderPass = nil
    deferredRenderPass.pGeometryPipeline = nil
    deferredRenderPass.pLightingPipeline = nil

    tkn.tknDestroyDynamicAttachmentPtr(pTknGfxContext, deferredRenderPass.pNormalAttachment)
    tkn.tknDestroyDynamicAttachmentPtr(pTknGfxContext, deferredRenderPass.pAlbedoAttachment)

    -- Destroy vertex input layouts
    tkn.tknDestroyVertexInputLayoutPtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout)
    tkn.tknDestroyVertexInputLayoutPtr(pTknGfxContext, deferredRenderPass.pVoxelVertexInputLayout)
    deferredRenderPass.pInstanceVertexInputLayout = nil
    deferredRenderPass.pVoxelVertexInputLayout = nil
end

return deferredRenderPass
