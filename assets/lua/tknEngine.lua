local tkn = require("tkn")
local ui = require("ui.ui")
local game = require("game.game")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local editorPanel = require("engine.panels.editorPanel")
local tknEngine = {}

local function formatDuration(seconds)
    return string.format("%.3f ms", seconds * 1000)
end

local function addCoreNodes(pTknGfxContext)
    tknEngine.gameRootNode = ui.addNode(pTknGfxContext, ui.rootNode, 1, "TickernelEngine", tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform)
    tknEngine.editorRootNode = ui.addNode(pTknGfxContext, ui.rootNode, 2, "Editor", tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform)
end

local function removeCoreNodes(pTknGfxContext)
    ui.removeNode(pTknGfxContext, tknEngine.editorRootNode)
    ui.removeNode(pTknGfxContext, tknEngine.gameRootNode)
end

function tknEngine.start(pTknGfxContext, assetsPath)
    tknEngine.assetsPath = assetsPath
    local depthVkFormat = tkn.tknGetSupportedFormat(pTknGfxContext, {VK_FORMAT_D24_UNORM_S8_UINT, VK_FORMAT_D32_SFLOAT_S8_UINT}, VK_IMAGE_TILING_OPTIMAL, VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT)
    tknEngine.pDepthStencilAttachment = tkn.tknCreateDynamicAttachmentPtr(pTknGfxContext, depthVkFormat, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, VK_IMAGE_ASPECT_DEPTH_BIT, 1)
    tknEngine.pSwapchainAttachment = tkn.tknGetSwapchainAttachmentPtr(pTknGfxContext)
    ui.setup(pTknGfxContext, tknEngine.pSwapchainAttachment, tknEngine.pDepthStencilAttachment, assetsPath, 1)
    tknWidgetConfig.setup(pTknGfxContext, assetsPath)
    addCoreNodes(pTknGfxContext)

    tknEngine.editorPanel = editorPanel.create(pTknGfxContext, tknEngine.editorRootNode)
    game.start(pTknGfxContext, tknEngine.pSwapchainAttachment, tknEngine.pDepthStencilAttachment, 0, assetsPath, tknEngine.gameRootNode)
end

function tknEngine.stop(pTknGfxContext)
    game.stop()
    tkn.tknWaitRenderFence(pTknGfxContext)
    game.stopGfx(pTknGfxContext)
    editorPanel.destroy(pTknGfxContext, tknEngine.editorPanel)

    removeCoreNodes(pTknGfxContext)
    tknWidgetConfig.teardown(pTknGfxContext)
    ui.teardown(pTknGfxContext)

    tkn.tknDestroyDynamicAttachmentPtr(pTknGfxContext, tknEngine.pDepthStencilAttachment)
    tknEngine.pDepthStencilAttachment = nil
    tknEngine.pSwapchainAttachment = nil
end

function tknEngine.update(pTknGfxContext, width, height)
    -- print("Lua update")
    game.update()
    tkn.tknWaitRenderFence(pTknGfxContext)
    local shouldQuit = game.updateGfx(pTknGfxContext, width, height)
    ui.update(pTknGfxContext, width, height)
    return shouldQuit
end

function tknEngine.recordFrame(pTknGfxContext, pTknFrame)
    game.recordFrame(pTknGfxContext, pTknFrame)
    ui.recordFrame(pTknGfxContext, pTknFrame)
end

_G.tknEngine = tknEngine
return tknEngine
