local tkn = require("tkn")
local geometryPipeline = require("geometryPipeline")
local lightingPipeline = require("lightingPipeline")
local deferredRenderPass = {}

function deferredRenderPass.setup(pGfxContext, pAttachments, assetsPath, pMeshVertexInputLayout, pInstanceVertexInputLayout, renderPassIndex)
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
    local pipelineIndex = 0
    deferredRenderPass.pGeometryPipeline = geometryPipeline.createPipelinePtr(pGfxContext, deferredRenderPass.pRenderPass, pipelineIndex, assetsPath, pMeshVertexInputLayout, pInstanceVertexInputLayout)
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

    tkn.destroyRenderPassPtr(pGfxContext, deferredRenderPass.pRenderPass)

    deferredRenderPass.pRenderPass = nil
    deferredRenderPass.pGeometryPipeline = nil
    deferredRenderPass.pLightingPipeline = nil
end

return deferredRenderPass
