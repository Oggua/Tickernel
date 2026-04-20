local mainScene = {}
local mainPanel = require("game.panels.mainPanel")
local characterSystem = require("game.characterSystem")
local transformSystem = require("game.transformSystem")
local tkn = require("tkn")

function mainScene.start(pTknGfxContext, game)
    mainScene.mainPanel = mainPanel.create(pTknGfxContext, game, game.rootUINode)
    transformSystem.update()
    characterSystem.updateInstances(pTknGfxContext)
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
    for _, char in ipairs(characterSystem.characters) do
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, char.body.pTknDrawCall)
    end
    if characterSystem.mask then
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, characterSystem.mask.pTknDrawCall)
    end
end

return mainScene
