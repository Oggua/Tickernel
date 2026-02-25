local tkn = require("tkn")
local vulkan = require("vulkan")
local imagePipeline = require("ui.imagePipeline")
local textPipeline = require("ui.textPipeline")
local uiRenderPass = {}

function uiRenderPass.setup(pTknGfxContext, pSwapchainAttachment, pDepthStencilAttachment, assetsPath, pUIVertexInputLayout, pUIInstanceInputLayout, renderPassIndex)
    local swapchainAttachmentDescription = {
        samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
        loadOp = vulkan.VK_ATTACHMENT_LOAD_OP_LOAD,
        storeOp = vulkan.VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp = vulkan.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = vulkan.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };
    local depthStencilAttachmentDescription = {
        samples = vulkan.VK_SAMPLE_COUNT_1_BIT,
        loadOp = vulkan.VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp = vulkan.VK_ATTACHMENT_LOAD_OP_CLEAR,
        stencilStoreOp = vulkan.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = vulkan.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    local vkAttachmentDescriptions = {swapchainAttachmentDescription, depthStencilAttachmentDescription};

    local vkClearValues = {{0.0, 0.0, 0.0, 1.0}, {1.0, 0}};

    local uiSubpassDescription = {
        pipelineBindPoint = vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {},
        pColorAttachments = {{
            attachment = 0,
            layout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pResolveAttachments = {},
        pDepthStencilAttachment = {
            attachment = 1,
            layout = vulkan.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        },
        pPreserveAttachments = {},
    }

    local vkSubpassDescriptions = {uiSubpassDescription}

    local spvPathsArray = {{}}

    local vkSubpassDependencies = {{
        srcSubpass = vulkan.VK_SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = vulkan.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        dstStageMask = vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        srcAccessMask = vulkan.VK_ACCESS_MEMORY_READ_BIT,
        dstAccessMask = vulkan.VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dependencyFlags = vulkan.VK_DEPENDENCY_BY_REGION_BIT,
    }, {
        srcSubpass = 0,
        dstSubpass = vulkan.VK_SUBPASS_EXTERNAL,
        srcStageMask = vulkan.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        dstStageMask = vulkan.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        srcAccessMask = vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dstAccessMask = vulkan.VK_ACCESS_MEMORY_READ_BIT,
        dependencyFlags = vulkan.VK_DEPENDENCY_BY_REGION_BIT,
    }}

    uiRenderPass.pTknRenderPass = tkn.tknCreateRenderPassPtr(pTknGfxContext, vkAttachmentDescriptions, {pSwapchainAttachment, pDepthStencilAttachment}, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)
    uiRenderPass.pImagePipeline = imagePipeline.createPipelinePtr(pTknGfxContext, uiRenderPass.pTknRenderPass, 0, assetsPath, pUIVertexInputLayout, pUIInstanceInputLayout)
    uiRenderPass.pTextPipeline = textPipeline.createPipelinePtr(pTknGfxContext, uiRenderPass.pTknRenderPass, 0, assetsPath, pUIVertexInputLayout, pUIInstanceInputLayout)
end

function uiRenderPass.teardown(pTknGfxContext)
    textPipeline.destroyPipelinePtr(pTknGfxContext, uiRenderPass.pTextPipeline)
    imagePipeline.destroyPipelinePtr(pTknGfxContext, uiRenderPass.pImagePipeline)
    tkn.tknDestroyRenderPassPtr(pTknGfxContext, uiRenderPass.pTknRenderPass)
    uiRenderPass.pTknRenderPass = nil
    uiRenderPass.pImagePipeline = nil
    uiRenderPass.pTextPipeline = nil
end

return uiRenderPass
