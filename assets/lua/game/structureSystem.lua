local tkn = require("tkn")
local tknVoxel = require("game.tknVoxel")
local deferredRenderPass = require("game.deferredRenderer.deferredRenderPass")
local transformSystem = require("game.transformSystem")
local structureConfig = require("game.structureConfig")
local structureSystem = {}

function structureSystem.setup(assetsPath, voxelPerMeter)
    structureSystem.assetPath = assetsPath
    structureSystem.scale = 1.0 / voxelPerMeter
    structureSystem.typeToStructures = {}
    structureSystem.typeToPTknMesh = {}
    structureSystem.typeToPInstance = {}
    structureSystem.typeToPDrawCall = {}
end

function structureSystem.teardown()
    structureSystem.typeToStructures = nil
    structureSystem.typeToPTknMesh = nil
    structureSystem.typeToPInstance = nil
    structureSystem.typeToPDrawCall = nil
    structureSystem.assetPath = nil
    structureSystem.scale = nil
end

function structureSystem.createMap(length, width)
    local structureMap = {}
    for x = 1, length do
        structureMap[x] = {}
        for y = 1, width do
            structureMap[x][y] = nil
        end
    end
    return structureMap
end

function structureSystem.destroyMap(structureMap)
    for x, column in pairs(structureMap) do
        for y, structureObj in pairs(column) do
            if structureObj then
                structureSystem.remove(structureObj)
            end
        end
    end
    structureMap = nil
end

function structureSystem.add(pTknGfxContext, type, x, y)
    local transform = transformSystem.add(x, y, 0, 0, 0, 0, 1, structureSystem.scale, structureSystem.scale, structureSystem.scale, transformSystem.rootTransform, nil)
    local config = structureConfig.types[type]
    local structure = {
        type = type,
        transform = transform,
        temperature = config.temperature,
        humidity = config.humidity,
        integrity = config.integrity,
    }

    if not structureSystem.typeToStructures[type] then
        structureSystem.typeToStructures[type] = {}
        structureSystem.typeToPTknMesh[type] = tknVoxel.readTvox(structureSystem.assetPath .. "/models/" .. type .. ".tvox", pTknGfxContext, {0.5, 0.5, 0})
        structureSystem.typeToPInstance[type] = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {})
        structureSystem.typeToPDrawCall[type] = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, structureSystem.typeToPTknMesh[type], structureSystem.typeToPInstance[type])
    end

    table.insert(structureSystem.typeToStructures[type], structure)
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

function structureSystem.updateInstances(pTknGfxContext)
    for type, list in pairs(structureSystem.typeToStructures) do
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
        tkn.tknUpdateInstancePtr(pTknGfxContext, structureSystem.typeToPInstance[type], deferredRenderPass.instanceFormat, {
            model = model,
        })
    end
end

function structureSystem.remove(pTknGfxContext, structure)
    local type = structure.type
    local list = structureSystem.typeToStructures[type]

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
