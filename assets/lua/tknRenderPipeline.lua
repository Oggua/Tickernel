local tkn = require("tkn")
local tknRenderPipeline = {}
local deferredRenderPass = require("deferredRenderPass")
tknRenderPipeline.deferredRenderPass = deferredRenderPass

function tknRenderPipeline.setup(pGfxContext, assetsPath, pMeshVertexInputLayout, pInstanceVertexInputLayout, renderPassIndex)
    local depthVkFormat = tkn.getSupportedFormat(pGfxContext, {VK_FORMAT_D32_SFLOAT, VK_FORMAT_D24_UNORM_S8_UINT, VK_FORMAT_D32_SFLOAT_S8_UINT}, VK_IMAGE_TILING_OPTIMAL, VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT)
    tknRenderPipeline.pColorAttachment = tkn.createDynamicAttachmentPtr(pGfxContext, VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_COLOR_BIT, 1)
    tknRenderPipeline.pDepthAttachment = tkn.createDynamicAttachmentPtr(pGfxContext, depthVkFormat, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_DEPTH_BIT, 1)
    tknRenderPipeline.pAlbedoAttachment = tkn.createDynamicAttachmentPtr(pGfxContext, VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_COLOR_BIT, 1)
    tknRenderPipeline.pNormalAttachment = tkn.createDynamicAttachmentPtr(pGfxContext, VK_FORMAT_A2R10G10B10_UNORM_PACK32, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_COLOR_BIT, 1)
    tknRenderPipeline.pSwapchainAttachment = tkn.getSwapchainAttachmentPtr(pGfxContext)
    local pAttachments = {tknRenderPipeline.pColorAttachment, tknRenderPipeline.pDepthAttachment, tknRenderPipeline.pAlbedoAttachment, tknRenderPipeline.pNormalAttachment, tknRenderPipeline.pSwapchainAttachment}
    deferredRenderPass.setup(pGfxContext, pAttachments, assetsPath, pMeshVertexInputLayout, pInstanceVertexInputLayout, renderPassIndex)
end

function tknRenderPipeline.teardown(pGfxContext)
    deferredRenderPass.teardown(pGfxContext)
    tkn.destroyDynamicAttachmentPtr(pGfxContext, tknRenderPipeline.pNormalAttachment)
    tkn.destroyDynamicAttachmentPtr(pGfxContext, tknRenderPipeline.pAlbedoAttachment)
    tkn.destroyDynamicAttachmentPtr(pGfxContext, tknRenderPipeline.pDepthAttachment)
    tkn.destroyDynamicAttachmentPtr(pGfxContext, tknRenderPipeline.pColorAttachment)
end

return tknRenderPipeline
