local tkn = require("tkn")
local tknVoxel = require("game.tknVoxel")
local deferredRenderPass = require("game.deferredRenderer.deferredRenderPass")
local transformSystem = require("game.transformSystem")
local tknMath = require("tknMath")
local structureSystem = {}

function structureSystem.setup(assetsPath, voxelPerMeter)
    structureSystem.assetPath = assetsPath
    structureSystem.scale = 1.0 / voxelPerMeter

    structureSystem.structure = {
        iceWall = 1,
        dirtWall = 2,
        volcanicWall = 3,
    }

    structureSystem.structureConfig = {
        [1] = {
            name = "iceWall",
            temperature = 1,
            humidity = 7,
            integrity = 256,
        },
        [2] = {
            name = "dirtWall",
            temperature = 4,
            humidity = 4,
            integrity = 256,
        },
        [3] = {
            name = "volcanicWall",
            temperature = 7,
            humidity = 1,
            integrity = 256,
        },
    }
end

function structureSystem.teardown()
    structureSystem.assetPath = nil
    structureSystem.scale = nil
    structureSystem.structure = nil
    structureSystem.structureConfig = nil
end

function structureSystem.createMap(length, width)
    local map = {
        spatialMap = {},
        typeToStructures = {},
        typeToPTknMesh = {},
        typeToPInstance = {},
        typeToPDrawCall = {},
    }
    for x = 1, length do
        map.spatialMap[x] = {}
        for y = 1, width do
            map.spatialMap[x][y] = nil
        end
    end
    return map
end

function structureSystem.destroyMap(structureMap)
    for x, column in pairs(structureMap.spatialMap) do
        for y, structureObj in pairs(column) do
            if structureObj then
                structureSystem.remove(structureMap, structureObj)
            end
        end
    end
    structureMap = nil
end

function structureSystem.add(pTknGfxContext, structureMap, id, x, y)
    -- Calculate rotation based on coordinate pairing
    -- Use cantorPair to combine x, y into single value, then lcgRandom for direction
    local pairKey = tknMath.cantorPair(x, y)
    local directionRand = tknMath.lcgRandom(pairKey) % 4

    -- Convert direction (0-3) to Z-axis rotation quaternion
    -- rotation = directionRand * 90 degrees around Z-axis (vertical)
    -- rz = sin(directionRand * π/4), rw = cos(directionRand * π/4)
    local rotations = {{0, 0, 0, 1}, -- 0°
    {0, 0, 0.7071067811865476, 0.7071067811865476}, -- 90°
    {0, 0, 1, 0}, -- 180°
    {0, 0, 0.7071067811865476, -0.7071067811865476} -- 270°
    }
    local rot = rotations[directionRand + 1]

    local transform = transformSystem.add(x, y, 0, rot[1], rot[2], rot[3], rot[4], structureSystem.scale, structureSystem.scale, structureSystem.scale, transformSystem.rootTransform, nil)
    local config = structureSystem.structureConfig[id]
    local structure = {
        id = id,
        transform = transform,
        temperature = config.temperature,
        humidity = config.humidity,
        integrity = config.integrity,
        direction = directionRand,
    }

    if not structureMap.typeToStructures[id] then
        structureMap.typeToStructures[id] = {}
        local meshPath = structureSystem.assetPath .. "/models/" .. config.name .. ".tvox"
        structureMap.typeToPTknMesh[id] = tknVoxel.readTvox(meshPath, pTknGfxContext, {0.5, 0.5, 0})
        structureMap.typeToPInstance[id] = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {})
        structureMap.typeToPDrawCall[id] = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, structureMap.typeToPTknMesh[id], structureMap.typeToPInstance[id])
    end

    table.insert(structureMap.typeToStructures[id], structure)
    return structure
end

-- Rebuild all instance GPU buffers from transform.model (call after transformSystem.update)
-- transform.model is row-major; instance buffer expects column-major, so transpose each matrix.
local function transposeToColumnMajor(m, out, offset)
    out[offset + 1] = m[1];
    out[offset + 2] = m[5];
    out[offset + 3] = m[9];
    out[offset + 4] = m[13]
    out[offset + 5] = m[2];
    out[offset + 6] = m[6];
    out[offset + 7] = m[10];
    out[offset + 8] = m[14]
    out[offset + 9] = m[3];
    out[offset + 10] = m[7];
    out[offset + 11] = m[11];
    out[offset + 12] = m[15]
    out[offset + 13] = m[4];
    out[offset + 14] = m[8];
    out[offset + 15] = m[12];
    out[offset + 16] = m[16]
end

function structureSystem.updateInstances(pTknGfxContext, structureMap)
    for type, list in pairs(structureMap.typeToStructures) do
        local model = {}
        for i, s in ipairs(list) do
            local m = s.transform.model
            if m then
                transposeToColumnMajor(m, model, (i - 1) * 16)
            else
                local base = (i - 1) * 16
                for j = 1, 16 do
                    model[base + j] = 0
                end
            end
        end
        tkn.tknUpdateInstancePtr(pTknGfxContext, structureMap.typeToPInstance[type], deferredRenderPass.instanceFormat, {
            model = model,
        })
    end
end

function structureSystem.remove(structureMap, structure)
    local id = structure.id
    local list = structureMap.typeToStructures[id]

    if not list then
        return
    end

    for i, v in ipairs(list) do
        if v == structure then
            table.remove(list, i)
            break
        end
    end

    transformSystem.remove(structure.transform)
    structure.transform = nil
end

return structureSystem
