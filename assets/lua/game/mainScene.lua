local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local mainPanel = require("game.panels.mainPanel")
local tkn = require("tkn")
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

    mainScene.pTknMesh = tkn.tknCreateMeshPtrWithTknVoxFile(pTknGfxContext, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.vertexFormat, game.assetsPath .. "/models/LargeBuilding01_0.tknvox", VK_INDEX_TYPE_UINT16)
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
