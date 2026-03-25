local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local mainPanel = require("game.panels.mainPanel")
local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local groundSystem = require("game.groundSystem")
local tknVoxel = require("game.tknVoxel")
local structure = require("game.structureSystem")
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
