local tkn = require("tkn")
local tknVoxel = require("game.tknVoxel")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local transformSystem = require("game.transformSystem")
local structure = {}

function structure.setup(assetsPath, voxelPerMeter)
    structure.assetPath = assetsPath
    structure.scale = 1.0 / voxelPerMeter
    structure.typeToStructures = {}
    structure.typeToPTknMesh = {}
    structure.typeToPInstance = {}
    structure.typeToPDrawCall = {}
end

function structure.teardown()
    structure.typeToStructures = nil
    structure.typeToPTknMesh = nil
    structure.typeToPInstance = nil
    structure.typeToPDrawCall = nil
    structure.assetPath = nil
    structure.scale = nil
end

function structure.create(pTknGfxContext, type, x, y, parentTransform)
    local transform = transformSystem.add(x, y, 0, 0, 0, 0, 1, structure.scale, structure.scale, structure.scale, parentTransform or transformSystem.rootTransform, nil)
    local result = {
        type = type,
        transform = transform,
    }

    if not structure.typeToStructures[type] then
        structure.typeToStructures[type] = {}
        structure.typeToPTknMesh[type] = tknVoxel.readTvox(structure.assetPath .. "/models/" .. type .. ".tvox", pTknGfxContext, {0.5, 0.5, 0})
        structure.typeToPInstance[type] = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {})
        structure.typeToPDrawCall[type] = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, structure.typeToPTknMesh[type], structure.typeToPInstance[type])
    end

    table.insert(structure.typeToStructures[type], result)
    return result
end

-- Rebuild all instance GPU buffers from transform.model (call after transformSystem.update)
-- transform.model is row-major; instance buffer expects column-major, so transpose each matrix.
local function transposeToColumnMajor(m, out, offset)
    out[offset + 1]  = m[1];  out[offset + 2]  = m[5];  out[offset + 3]  = m[9];  out[offset + 4]  = m[13]
    out[offset + 5]  = m[2];  out[offset + 6]  = m[6];  out[offset + 7]  = m[10]; out[offset + 8]  = m[14]
    out[offset + 9]  = m[3];  out[offset + 10] = m[7];  out[offset + 11] = m[11]; out[offset + 12] = m[15]
    out[offset + 13] = m[4];  out[offset + 14] = m[8];  out[offset + 15] = m[12]; out[offset + 16] = m[16]
end

function structure.updateInstances(pTknGfxContext)
    for type, list in pairs(structure.typeToStructures) do
        local model = {}
        for i, s in ipairs(list) do
            local m = s.transform.model
            if m then
                transposeToColumnMajor(m, model, (i - 1) * 16)
            else
                local base = (i - 1) * 16
                for j = 1, 16 do model[base + j] = 0 end
            end
        end
        tkn.tknUpdateInstancePtr(pTknGfxContext, structure.typeToPInstance[type], deferredRenderPass.instanceFormat, {model = model})
    end
end

function structure.destroy(pTknGfxContext, structureObj)
    local type = structureObj.type
    local list = structure.typeToStructures[type]

    if not list then
        return
    end

    for i, v in ipairs(list) do
        if v == structureObj then
            table.remove(list, i)
            break
        end
    end

    transformSystem.remove(structureObj.transform)
    structureObj.transform = nil
end

return structure
