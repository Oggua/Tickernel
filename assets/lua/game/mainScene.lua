local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local mainPanel = require("game.panels.mainPanel")
local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local mapSystem = require("game.mapSystem")
local voxParser = require("game.voxParser")
function mainScene.start(game, pTknGfxContext)
    mainScene.mainPanel = mainPanel.create(pTknGfxContext, game, game.gameRootNode, function()
        print("Start Game button clicked")
    end, function()
        print("Settings button clicked")
    end, function()
        game.switchScene(nil)
        print("Quit Game button clicked")
    end)

    mapSystem.setup()
    print("Generating map...")
    mapSystem.generateRoom(321312, 16, 16, game.voxelPerMeter)
    print("Generated map with " .. #mapSystem.groundMap .. "x" .. #mapSystem.groundMap[1] .. " tiles")
    mainScene.pTknMesh, mainScene.pTknInstance, mainScene.pTknDrawCall = mapSystem.createMesh(pTknGfxContext)

    mainScene.rockWallCount = 0
    mainScene.pRockWallMesh = nil
    mainScene.pRockWallInstance = nil
    mainScene.pRockWallDrawCall = nil
    local rockWallPath = game.assetsPath .. "/models/rockWall.tvox"
    local ok, pRockWallMeshOrErr = pcall(voxParser.readTvox, rockWallPath, pTknGfxContext)
    if not ok then
        print("Failed to load rockWall mesh via voxParser.readTvox: " .. tostring(pRockWallMeshOrErr))
    else
        mainScene.pRockWallMesh = pRockWallMeshOrErr
        local count = 1
        local s = 1.0 / game.voxelPerMeter
        local models = {}
        local tx = 0
        local ty = 0
        local tz = 0
        table.insert(models, s)
        table.insert(models, 0)
        table.insert(models, 0)
        table.insert(models, tx)
        table.insert(models, 0)
        table.insert(models, s)
        table.insert(models, 0)
        table.insert(models, ty)
        table.insert(models, 0)
        table.insert(models, 0)
        table.insert(models, s)
        table.insert(models, tz)
        table.insert(models, 0)
        table.insert(models, 0)
        table.insert(models, 0)
        table.insert(models, 1)
        mainScene.pRockWallInstance = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {
            model = models,
        })
        mainScene.pRockWallDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, mainScene.pRockWallMesh, mainScene.pRockWallInstance)
        mainScene.rockWallCount = count
    end
    print("Loaded random rockWalls: " .. tostring(mainScene.rockWallCount))
end

function mainScene.stop(game)
    mapSystem.teardown()
end

function mainScene.stopGfx(game, pTknGfxContext)

    mapSystem.destroyMesh(pTknGfxContext, mainScene.pTknMesh, mainScene.pTknInstance, mainScene.pTknDrawCall)

    if mainScene.pRockWallDrawCall then
        tkn.tknDestroyDrawCallPtr(pTknGfxContext, mainScene.pRockWallDrawCall)
        mainScene.pRockWallDrawCall = nil
    end

    if mainScene.pRockWallInstance then
        tkn.tknDestroyInstancePtr(pTknGfxContext, mainScene.pRockWallInstance)
        mainScene.pRockWallInstance = nil
    end

    if mainScene.pRockWallMesh then
        voxParser.destroyMesh(pTknGfxContext, mainScene.pRockWallMesh)
        mainScene.pRockWallMesh = nil
    end
    mainScene.rockWallCount = 0

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
    if mainScene.pRockWallDrawCall then
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, mainScene.pRockWallDrawCall)
    end
end

return mainScene
