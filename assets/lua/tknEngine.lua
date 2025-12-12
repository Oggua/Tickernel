local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer/deferredRenderPass")
local ui = require("ui.ui")
local input = require("input")
local game = require("game.game")
local tknEngine = {}

function tknEngine.start(pGfxContext, assetsPath)
    print("Lua start")
    tknEngine.assetsPath = assetsPath
    local renderPassIndex = 0
    deferredRenderPass.setup(pGfxContext, assetsPath, renderPassIndex)
    renderPassIndex = renderPassIndex + 1
    ui.setup(pGfxContext, deferredRenderPass.pSwapchainAttachment, assetsPath, renderPassIndex)
    game.start(pGfxContext, assetsPath)
end

function tknEngine.stop(pGfxContext)
    game.stop()
    tkn.tknWaitRenderFence(pGfxContext)
    game.stopGfx(pGfxContext)
    ui.teardown(pGfxContext)
    deferredRenderPass.teardown(pGfxContext)
end

function tknEngine.update(pGfxContext, width, height)
    print("Lua update")
    game.update()
    tkn.tknWaitRenderFence(pGfxContext)
    print("Lua updateGfx")
    local shouldQuit = game.updateGfx(pGfxContext, width, height)
    ui.update(pGfxContext, width, height)
    return shouldQuit
end

_G.tknEngine = tknEngine
return tknEngine
