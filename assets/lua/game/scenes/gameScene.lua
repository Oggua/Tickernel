local gameScene = {}
local ui = require("ui.ui")
local input = require("input")
local tkn = require("tkn")
local deferredRenderPass = require("game.deferredRenderer.deferredRenderPass")
local groundSystem = require("game.groundSystem")
local tknVoxel = require("game.tknVoxel")
local structureSystem = require("game.structureSystem")
function gameScene.start(pTknGfxContext, game)
end

function gameScene.stop(game)
end

function gameScene.stopGfx(game, pTknGfxContext)
end

function gameScene.update(game)
end

function gameScene.updateGfx(game, pTknGfxContext, width, height)
end

function gameScene.recordFrame(game, pTknGfxContext, pTknFrame)
end

return gameScene
