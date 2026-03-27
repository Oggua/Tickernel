local mainScene = {}
local mainPanel = require("game.panels.mainPanel")
function mainScene.start(pTknGfxContext, game)
    mainScene.mainPanel = mainPanel.create(pTknGfxContext, game, game.rootUINode)
end

function mainScene.stop(game)
end

function mainScene.stopGfx(game, pTknGfxContext)
    mainPanel.destroy(pTknGfxContext, mainScene.mainPanel)
end

function mainScene.update(game)
end

function mainScene.updateGfx(game, pTknGfxContext, width, height)
end

function mainScene.recordFrame(game, pTknGfxContext, pTknFrame)
end

return mainScene
