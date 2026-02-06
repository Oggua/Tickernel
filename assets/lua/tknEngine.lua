local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer/deferredRenderPass")
local ui = require("ui.ui")
local game = require("game.game")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local editorTopBarPanel = require("engine.panels.editorTopBarPanel")
local editorPanel = require("engine.panels.editorPanel")
local tknEngine = {}

local function addCoreNodes(pTknGfxContext)
    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }

    local fullScreenHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local fullScreenVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    tknEngine.gameRootNode = ui.addNode(pTknGfxContext, ui.rootNode, 1, "TickernelEngine", fullScreenHorizontal, fullScreenVertical, defaultTransform)

    local editorTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = false,
    }
    tknEngine.editorRootNode = ui.addNode(pTknGfxContext, ui.rootNode, 2, "Editor", fullScreenHorizontal, fullScreenVertical, editorTransform)

    tknEngine.editorTopBarNode = ui.addNode(pTknGfxContext, ui.rootNode, 3, "EditorTopBar", fullScreenHorizontal, fullScreenVertical, defaultTransform)
end

local function removeCoreNodes(pTknGfxContext)
    ui.removeNode(pTknGfxContext, tknEngine.editorTopBarNode)
    ui.removeNode(pTknGfxContext, tknEngine.editorRootNode)
    ui.removeNode(pTknGfxContext, tknEngine.gameRootNode)
end

function tknEngine.start(pTknGfxContext, assetsPath)
    print("Lua start")
    tknEngine.assetsPath = assetsPath
    local renderPassIndex = 0
    deferredRenderPass.setup(pTknGfxContext, assetsPath, renderPassIndex)
    renderPassIndex = renderPassIndex + 1
    ui.setup(pTknGfxContext, deferredRenderPass.pSwapchainAttachment, deferredRenderPass.pDepthStencilAttachment, assetsPath, renderPassIndex)
    tknWidgetConfig.setup(pTknGfxContext, assetsPath)
    addCoreNodes(pTknGfxContext)
    editorTopBarPanel.create(pTknGfxContext, tknEngine.editorRootNode, tknEngine.editorTopBarNode)
    editorPanel.create(pTknGfxContext, tknEngine.editorRootNode)
    game.start(pTknGfxContext, assetsPath, tknEngine.gameRootNode)
end

function tknEngine.stop(pTknGfxContext)
    game.stop()
    tkn.tknWaitRenderFence(pTknGfxContext)
    game.stopGfx(pTknGfxContext)
    editorPanel.destroy(pTknGfxContext)
    editorTopBarPanel.destroy(pTknGfxContext)
    removeCoreNodes(pTknGfxContext)
    tknWidgetConfig.teardown(pTknGfxContext)
    ui.teardown(pTknGfxContext)
    deferredRenderPass.teardown(pTknGfxContext)
end

function tknEngine.update(pTknGfxContext, width, height)
    -- print("Lua update")
    game.update()
    tkn.tknWaitRenderFence(pTknGfxContext)
    -- print("Lua updateGfx")
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
