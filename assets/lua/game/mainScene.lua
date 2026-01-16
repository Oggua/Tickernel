local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local mainPanel = require("game.panels.mainPanel")

function mainScene.start(game, pTknGfxContext, assetsPath)
    mainPanel.create(pTknGfxContext, game, ui.rootNode, function()
        print("Start Game button clicked")
    end, function()
        print("Settings button clicked")
        
    end, function()
        game.switchScene(nil)
        print("Quit Game button clicked")
    end)
end

function mainScene.stop(game)
end

function mainScene.stopGfx(game, pTknGfxContext)
    mainPanel.destroy(mainPanel, pTknGfxContext)
end

function mainScene.update(game)
end

function mainScene.updateGfx(game, pTknGfxContext, width, height)

end

return mainScene
