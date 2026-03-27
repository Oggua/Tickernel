local game = {}
local mainScene = require("game.scenes.mainScene")

local groundSystem = require("game.groundSystem")
local structureSystem = require("game.structureSystem")
function game.start(pTknGfxContext, assetsPath, rootUINode, voxelPerMeter)
    game.assetsPath = assetsPath
    game.currentScene = mainScene
    game.nextScene = mainScene
    game.rootUINode = rootUINode
    game.voxelPerMeter = voxelPerMeter

    groundSystem.setup(game.voxelPerMeter)
    structureSystem.setup(game.assetsPath, game.voxelPerMeter)

    game.currentScene.start(pTknGfxContext, game)
end

function game.stop()
    game.currentScene.stop(game)

    groundSystem.teardown()
    structureSystem.teardown()
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
            game.currentScene.start(pTknGfxContext, game, game.assetsPath)
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
