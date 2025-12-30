local game = {}
local mainScene = require("game.mainScene")
local ui = require("ui.ui")

function game.start(pTknGfxContext, assetsPath)
    game.assetsPath = assetsPath
    print(ui)
    game.font = ui.loadFont(pTknGfxContext, "/fonts/Monaco.ttf", 32, 2048)
    game.uiDefaultImagePath = "/textures/uiDefault.astc"
    game.uiDefaultImage = ui.loadImage(pTknGfxContext, game.uiDefaultImagePath)
    game.currentScene = mainScene
    game.nextScene = mainScene
    game.currentScene.start(game, pTknGfxContext, assetsPath)
end

function game.stop()
    game.currentScene.stop(game)
end

function game.stopGfx(pTknGfxContext)
    game.currentScene.stopGfx(game, pTknGfxContext)
    game.currentScene = nil
    
    ui.unloadImage(pTknGfxContext, game.uiDefaultImage)
    game.uiDefaultImage = nil
    ui.unloadFont(pTknGfxContext, game.font)
    game.font = nil
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

return game
