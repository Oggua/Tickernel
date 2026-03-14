local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local mainPanel = require("game.panels.mainPanel")
local tkn = require("tkn")
local tknVoxel = require("game.tknVoxel")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local mapSystem = require("game.mapSystem")
function mainScene.start(game, pTknGfxContext)
    mainScene.mainPanel = mainPanel.create(pTknGfxContext, game, game.gameRootNode, function()
        print("Start Game button clicked")
    end, function()
        print("Settings button clicked")
    end, function()
        game.switchScene(nil)
        print("Quit Game button clicked")
    end)

    -- mainScene.groundMeshData = tknVoxel.loadVoxFile(game.assetsPath .. "/models/Garden_0.tknvox")
    -- -- mainScene.groundMeshData = tknVoxel.loadVoxFile(game.assetsPath .. "/models/TallBuilding02_0.tknvox")
    -- mainScene.pTknMesh = tkn.tknCreateMeshPtrWithData(pTknGfxContext, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.vertexFormat, mainScene.groundMeshData, 0, nil)
    -- local scale = 1.0 / 64
    -- mainScene.pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {
    --     model = {scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1},
    -- })
    -- mainScene.pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, mainScene.pTknMesh, mainScene.pTknInstance)
    mapSystem.setup()
    print("Generating map...")
    mapSystem.generateRoom(321312, 16, 16, game.voxelPerMeter)
    print("Generated map with " .. #mapSystem.groundMap .. "x" .. #mapSystem.groundMap[1] .. " tiles")
    mainScene.pTknMesh, mainScene.pTknInstance, mainScene.pTknDrawCall = mapSystem.createMesh(pTknGfxContext)
end

function mainScene.stop(game)
    mapSystem.teardown()
end

function mainScene.stopGfx(game, pTknGfxContext)
    -- tkn.tknDestroyDrawCallPtr(pTknGfxContext, mainScene.pTknDrawCall)
    -- tkn.tknDestroyMeshPtr(pTknGfxContext, mainScene.pTknMesh)
    -- tkn.tknDestroyInstancePtr(pTknGfxContext, mainScene.pTknInstance)
    mapSystem.destroyMesh(pTknGfxContext, mainScene.pTknMesh, mainScene.pTknInstance, mainScene.pTknDrawCall)

    mainPanel.destroy(mainScene.mainPanel, pTknGfxContext)
    mainScene.mainPanel = nil
end

function mainScene.update(game)

end

function mainScene.updateGfx(game, pTknGfxContext, width, height)

end

function mainScene.recordFrame(game, pTknGfxContext, pTknFrame)
    -- Main scene rendering logic here
    tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, mainScene.pTknDrawCall)
end

return mainScene
