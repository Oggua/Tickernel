local tkn = require("tkn")
local imagePipeline = require("ui.imagePipeline")
local textPipeline = require("ui.textPipeline")
local uiRenderPass = {}

function uiRenderPass.setup(pTknGfxContext, pSwapchainAttachment, assetsPath, pUIVertexInputLayout, pUIInstanceInputLayout, renderPassIndex)
    local swapchainAttachmentDescription = {
        samples = VK_SAMPLE_COUNT_1_BIT,
        loadOp = VK_ATTACHMENT_LOAD_OP_LOAD,
        storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    local vkAttachmentDescriptions = {swapchainAttachmentDescription};

    local vkClearValues = {{0.0, 0.0, 0.0, 1.0}};

    local uiSubpassDescription = {
        pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        pInputAttachments = {},
        pColorAttachments = {{
            attachment = 0,
            layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }},
        pResolveAttachments = {},
        pDepthStencilAttachment = nil,
        pPreserveAttachments = {},
    }

    local vkSubpassDescriptions = {uiSubpassDescription}

    local spvPathsArray = {{}}

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
        dstSubpass = VK_SUBPASS_EXTERNAL,
        srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        dstStageMask = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        dstAccessMask = VK_ACCESS_MEMORY_READ_BIT,
        dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT,
    }}

    uiRenderPass.pTknRenderPass = tkn.tknCreateRenderPassPtr(pTknGfxContext, vkAttachmentDescriptions, {pSwapchainAttachment}, vkClearValues, vkSubpassDescriptions, spvPathsArray, vkSubpassDependencies, renderPassIndex)
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
