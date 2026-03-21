local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local mainPanel = require("game.panels.mainPanel")
local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local mapSystem = require("game.mapSystem")
local tknVoxel = require("game.tknVoxel")
local structure = require("game.structure")
function mainScene.start(game, pTknGfxContext)
    mainScene.mainPanel = mainPanel.create(pTknGfxContext, game, game.gameRootNode, function()
        print("Start Game button clicked")
        game.switchScene(game)
    end, function()
        print("Settings button clicked")
    end, function()
        game.switchScene(nil)
        print("Quit Game button clicked")
    end)

    mapSystem.setup()
    print("Generating map...")
    mapSystem.generateRoom(321312, 32, 32, game.voxelPerMeter)

    print("Generated map with " .. #mapSystem.groundMap .. "x" .. #mapSystem.groundMap[1] .. " tiles")
    mainScene.pGroundTknMesh, mainScene.pGroundTknInstance, mainScene.pGroundTknDrawCall = mapSystem.createMesh(pTknGfxContext)

    structure.setup(game.assetsPath, game.voxelPerMeter)
    mainScene.structures = {}
    for i = 1, 256 do
        local x = math.random(1, mapSystem.length)
        local y = math.random(1, mapSystem.width)
        if x % 3 == 1 then
            table.insert(mainScene.structures, structure.create(pTknGfxContext, "iceWall", x, y))
        elseif x % 3 == 2 then
            table.insert(mainScene.structures, structure.create(pTknGfxContext, "rockWall", x, y))
        else
            table.insert(mainScene.structures, structure.create(pTknGfxContext, "mushroom", x, y))
        end
    end
end

function mainScene.stop(game)
    mapSystem.teardown()
end

function mainScene.stopGfx(game, pTknGfxContext)
    for i, v in ipairs(mainScene.structures) do
        structure.destroy(pTknGfxContext, v)
    end
    structure.teardown()

    mapSystem.destroyMesh(pTknGfxContext, mainScene.pGroundTknMesh, mainScene.pGroundTknInstance, mainScene.pGroundTknDrawCall)

    mainPanel.destroy(mainScene.mainPanel, pTknGfxContext)
    mainScene.mainPanel = nil
end

function mainScene.update(game)

end

function mainScene.updateGfx(game, pTknGfxContext, width, height)
    structure.updateInstances(pTknGfxContext)
end

function mainScene.recordFrame(game, pTknGfxContext, pTknFrame)
    tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, mainScene.pGroundTknDrawCall)
    for k, v in pairs(structure.typeToPDrawCall) do
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, v)
    end
end

return mainScene
