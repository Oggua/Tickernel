local gameScene = {}
local wildMap = require("game.maps.wildMap")
local characterSystem = require("game.characterSystem")
local transformSystem = require("game.transformSystem")
local tkn = require("tkn")

function gameScene.start(pTknGfxContext, game)
    gameScene.map = wildMap.create(pTknGfxContext)
    gameScene.player = characterSystem.add(pTknGfxContext, 1, 1, 0, 42)
    transformSystem.update()
    characterSystem.updateInstances(pTknGfxContext)
end

function gameScene.stop(game)
end

function gameScene.stopGfx(game, pTknGfxContext)
    wildMap.destroy(pTknGfxContext, gameScene.map)
    gameScene.map = nil
end

function gameScene.update(game)
end

function gameScene.updateGfx(game, pTknGfxContext, width, height)
end

function gameScene.recordFrame(game, pTknGfxContext, pTknFrame)
    if gameScene.map then
        -- Record ground mesh
        if gameScene.map.pTknDrawCall then
            tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, gameScene.map.pTknDrawCall)
        end

        -- Record structures
        if gameScene.map.structureMap then
            for structureType, pTknDrawCall in pairs(gameScene.map.structureMap.typeToPDrawCall) do
                if pTknDrawCall then
                    tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, pTknDrawCall)
                end
            end
        end
    end

    -- Record characters
    for _, char in ipairs(characterSystem.characters) do
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, char.body.pTknDrawCall)
    end
    if characterSystem.mask then
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, characterSystem.mask.pTknDrawCall)
    end
end

return gameScene
