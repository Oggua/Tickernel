local tkn = require("tkn")
local geometryPipeline = require("geometryPipeline")
local lightingPipeline = require("lightingPipeline")
local postProcessPipeline = require("postProcessPipeline")
local deferredRenderPass = {}

function deferredRenderPass.setup(pGfxContext, pAttachments, assetsPath, pMeshVertexInputLayout, pInstanceVertexInputLayout, renderPassIndex)
    local colorAttachmentDescription = {
        samples = VK_SAMPLE_COUNT_1_BIT,
        loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    };
    local depthAttachmentDescription = {
        samples = VK_SAMPLE_COUNT_1_BIT,
        loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
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
        loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    local vkAttachmentDescriptions = {colorAttachmentDescription, depthAttachmentDescription, albedoAttachmentDescription, normalAttachmentDescription, swapchainAttachmentDescription};

    local vkClearValues = {{0.0, 0.0, 0.0, 1.0}, {
        depth = 1.0,
        stencil = 0,
    }, {0.0, 0.0, 0.0, 1.0}, {0.0, 0.0, 0.0, 1.0}, {0.0, 0.0, 0.0, 1.0}};

    local geometrySubpassDescription = {
        pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {},
        pColorAttachments = {{
            attachment = 2,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }, {
            attachment = 3,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pResolveAttachments = {},
        pDepthStencilAttachment = {
            attachment = 1,
            layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        },
        pPreserveAttachments = {},
    }

    local ligthtingSubpassDescription = {
        pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {{
            attachment = 1,
            layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL,
        }, {
            attachment = 2,
            layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        }, {
            attachment = 3,
            layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        }},
        pColorAttachments = {{
            attachment = 0,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pResolveAttachments = {},
        pDepthStencilAttachment = nil,
        pPreserveAttachments = {},
    }

    local postProcessSubpassDescription = {
        pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {{
            attachment = 0,
            layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        }},
        pColorAttachments = {{
            attachment = 4,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pResolveAttachments = {},
        pDepthStencilAttachment = nil,
        pPreserveAttachments = {},
    }

    local vkSubpassDescriptions = {geometrySubpassDescription, ligthtingSubpassDescription, postProcessSubpassDescription}

    local spvPathsArray = {{}, {assetsPath .. "/shaders/lighting.subpass.frag.spv"}, {assetsPath .. "/shaders/postProcess.subpass.frag.spv"}}

    local vkSubpassDependencies = {{
        srcSubpass = VK_SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        srcAccessMask = VK_ACCESS_MEMORY_READ_BIT,
        dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 0,
        dstSubpass = 1,
        srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        dstStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dstAccessMask = VK_ACCESS_INPUT_ATTACHMENT_READ_BIT,
        dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 1,
        dstSubpass = 2,
        srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        dstStageMask = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dstAccessMask = VK_ACCESS_INPUT_ATTACHMENT_READ_BIT,
        dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 2,
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
    pipelineIndex = pipelineIndex + 1
    deferredRenderPass.pPostProcessPipeline = postProcessPipeline.createPipelinePtr(pGfxContext, deferredRenderPass.pRenderPass, pipelineIndex, assetsPath)
    deferredRenderPass.pGeometryMaterial = tkn.createPipelineMaterialPtr(pGfxContext, deferredRenderPass.pGeometryPipeline)
    deferredRenderPass.pLightingMaterial = tkn.createPipelineMaterialPtr(pGfxContext, deferredRenderPass.pLightingPipeline)
    deferredRenderPass.pPostProcessMaterial = tkn.createPipelineMaterialPtr(pGfxContext, deferredRenderPass.pPostProcessPipeline)

    local pLightingDrawCall = tkn.createDrawCallPtr(pGfxContext, deferredRenderPass.pLightingPipeline, deferredRenderPass.pLightingMaterial, nil, nil)
    tkn.insertDrawCallPtr(pLightingDrawCall, 0)
    local pPostProcessDrawCall = tkn.createDrawCallPtr(pGfxContext, deferredRenderPass.pPostProcessPipeline, deferredRenderPass.pPostProcessMaterial, nil, nil)
    tkn.insertDrawCallPtr(pPostProcessDrawCall, 0)
    return renderPassIndex
end

function deferredRenderPass.teardown(pGfxContext)
    postProcessPipeline.destroyPipelinePtr(pGfxContext, deferredRenderPass.pGeometryPipeline)
    deferredRenderPass.pGeometryMaterial = nil
    lightingPipeline.destroyPipelinePtr(pGfxContext, deferredRenderPass.pLightingPipeline)
    geometryPipeline.destroyPipelinePtr(pGfxContext, deferredRenderPass.pPostProcessPipeline)

    tkn.destroyRenderPassPtr(pGfxContext, deferredRenderPass.pRenderPass)

    deferredRenderPass.pRenderPass = nil
    deferredRenderPass.pGeometryPipeline = nil
    deferredRenderPass.pLightingPipeline = nil
    deferredRenderPass.pPostProcessPipeline = nil
end

return deferredRenderPass
