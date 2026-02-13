local game = {}
local mainScene = require("game.mainScene")
local ui = require("ui.ui")
local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
function game.start(pTknGfxContext, pSwapchainAttachment, pDepthStencilAttachment, renderPassIndex, assetsPath, gameRootNode)
    deferredRenderPass.setup(pTknGfxContext, assetsPath, renderPassIndex, pDepthStencilAttachment, pSwapchainAttachment)
    game.assetsPath = assetsPath
    game.currentScene = mainScene
    game.nextScene = mainScene
    game.gameRootNode = gameRootNode
    game.currentScene.start(game, pTknGfxContext)
end

function game.stop()
    game.currentScene.stop(game)
end

function game.stopGfx(pTknGfxContext)
    game.currentScene.stopGfx(game, pTknGfxContext)
    game.currentScene = nil
    deferredRenderPass.teardown(pTknGfxContext)
end

-- Returns: nil = quit, self = continue, other scene = switch
function game.update()
    game.currentScene.update(game)
end

-- Called after waitRenderFence, handles GPU resources and scene switching
function game.updateGfx(pTknGfxContext, width, height)
    game.currentScene.updateGfx(game, pTknGfxContext, width, height)
    local shouldQuit = false
    -- Check if scene wants to switch (set by update)
    if game.nextScene == nil then
        shouldQuit = true
    else
        if game.nextScene ~= game.currentScene then
            -- Switch scene: cleanup old, setup new
            game.currentScene.stop(game)
            game.currentScene.stopGfx(game, pTknGfxContext)
            game.currentScene = game.nextScene
            game.currentScene.start(game, pTknGfxContext, game.assetsPath)
            game.currentScene.updateGfx(game, pTknGfxContext, width, height)
        end
    end
    return shouldQuit
end

function game.switchScene(nextScene)
    game.nextScene = nextScene
end

function game.recordFrame(pTknGfxContext, pTknFrame)
    tkn.tknBeginRenderPassPtr(pTknGfxContext, pTknFrame, deferredRenderPass.pTknRenderPass)
    game.currentScene.recordFrame(game, pTknGfxContext, pTknFrame)
    tkn.tknNextSubpassPtr(pTknGfxContext, pTknFrame)
    tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, deferredRenderPass.pLightingDrawCall)
    tkn.tknEndRenderPassPtr(pTknGfxContext, pTknFrame)
end

return game
