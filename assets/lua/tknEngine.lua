local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer/deferredRenderPass")
local ui = require("ui.ui")
local game = require("game.game")
local input = require("input")
local widget = require("ui.widgets.widget")
local tknEngine = {}

function tknEngine.start(pTknGfxContext, assetsPath)
    print("Lua start")
    tknEngine.assetsPath = assetsPath
    local renderPassIndex = 0
    deferredRenderPass.setup(pTknGfxContext, assetsPath, renderPassIndex)
    renderPassIndex = renderPassIndex + 1
    ui.setup(pTknGfxContext, deferredRenderPass.pSwapchainAttachment, deferredRenderPass.pDepthStencilAttachment, assetsPath, renderPassIndex)

    widget.setup(pTknGfxContext, assetsPath)
    game.start(pTknGfxContext, assetsPath)
end

function tknEngine.stop(pTknGfxContext)
    game.stop()
    tkn.tknWaitRenderFence(pTknGfxContext)
    game.stopGfx(pTknGfxContext)
    widget.teardown(pTknGfxContext)
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
