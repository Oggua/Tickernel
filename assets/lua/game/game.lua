local game = {}
local mainScene = require("game.mainScene")
local ui = require("ui.ui")
local tkn = require("tkn")
local tknMath = require("tknMath")
local input = require("input")
local tknSliderWidget = require("engine.widgets.tknSliderWidget")

function game.start(pTknGfxContext, assetsPath, rootUINode, voxelPerMeter)
    game.assetsPath = assetsPath
    game.currentScene = mainScene
    game.nextScene = mainScene
    game.rootUINode = rootUINode
    game.voxelPerMeter = voxelPerMeter
    game.currentScene.start(game, pTknGfxContext)
end

function game.stop()
    game.currentScene.stop(game)
end

function game.stopGfx(pTknGfxContext)
    game.currentScene.stopGfx(game, pTknGfxContext)
    game.currentScene = nil
end

function game.update()
    game.currentScene.update(game)
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
    game.currentScene.recordFrame(game, pTknGfxContext, pTknFrame)
end

return game
