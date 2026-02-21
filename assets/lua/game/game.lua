local game = {}
local mainScene = require("game.mainScene")
local ui = require("ui.ui")
local tkn = require("tkn")
local tknMath = require("tknMath")
local input = require("input")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local tknSliderWidget = require("engine.widgets.tknSliderWidget")

function game.start(pTknGfxContext, pSwapchainAttachment, pDepthStencilAttachment, renderPassIndex, assetsPath, rootUINode)
    deferredRenderPass.setup(pTknGfxContext, assetsPath, renderPassIndex, pDepthStencilAttachment, pSwapchainAttachment)
    game.assetsPath = assetsPath
    game.currentScene = mainScene
    game.nextScene = mainScene
    game.rootUINode = rootUINode
    game.rootGameNode = game.addTransform("rootGameNode", {
        x = 0,
        y = 0,
        z = 0,
    }, {
        x = 0,
        y = 0,
        z = 0,
        w = 0,
    }, {
        x = 1,
        y = 1,
        z = 1,
    }, true, nil, nil)

    game.currentScene.start(game, pTknGfxContext)
end

function game.stop()
    game.currentScene.stop(game)
end

function game.stopGfx(pTknGfxContext)
    game.currentScene.stopGfx(game, pTknGfxContext)
    game.currentScene = nil
    deferredRenderPass.teardown(pTknGfxContext)
    game.removeNode(game.rootGameNode)
end

function game.update()
    game.currentScene.update(game)
    updateGameNodeRecursively(game.rootGameNode, {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}, true, false, false)

end

function game.updateGfx(pTknGfxContext, width, height)
    game.currentScene.updateGfx(game, pTknGfxContext, width, height)
    local shouldQuit = false
    if game.nextScene == nil then
        shouldQuit = true
    else
        if game.nextScene ~= game.currentScene then
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
