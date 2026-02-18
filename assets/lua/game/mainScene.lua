local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local mainPanel = require("game.panels.mainPanel")
local tkn = require("tkn")
local tknVox = require("tknVox")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")

function mainScene.start(game, pTknGfxContext)
    mainScene.mainPanel = mainPanel.create(pTknGfxContext, game, game.gameRootNode, function()
        print("Start Game button clicked")
    end, function()
        print("Settings button clicked")
    end, function()
        game.switchScene(nil)
        print("Quit Game button clicked")
    end)

    mainScene.terrainMeshData = tknVox.loadVoxFile(game.assetsPath .. "/models/Garden_0.tknvox")
    -- mainScene.terrainMeshData = tknVox.loadVoxFile(game.assetsPath .. "/models/TallBuilding02_0.tknvox")
    mainScene.pTknMesh = tkn.tknCreateMeshPtrWithData(pTknGfxContext, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.vertexFormat, mainScene.terrainMeshData, 0, nil)
    mainScene.pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {
        model = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
    })
    mainScene.pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, mainScene.pTknMesh, mainScene.pTknInstance)


end

function mainScene.stop(game)

end

function mainScene.stopGfx(game, pTknGfxContext)
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
