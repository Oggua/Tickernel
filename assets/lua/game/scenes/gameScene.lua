local gameScene = {}
local wildMap = require("game.maps.wildMap")
local tkn = require("tkn")

function gameScene.start(pTknGfxContext, game)
    gameScene.map = wildMap.create(pTknGfxContext)
end

function gameScene.stop(game)
end

function gameScene.stopGfx(game, pTknGfxContext)
    if gameScene.map then
        wildMap.destroy(pTknGfxContext, gameScene.map)
        gameScene.map = nil
    end
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
end

return gameScene
