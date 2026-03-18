local tkn = require("tkn")
local tknVoxel = require("game.tknVoxel")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local structure = {}

function structure.setup(assetsPath, voxelPerMeter)
    structure.assetPath = assetsPath
    structure.scale = 1.0 / voxelPerMeter
    structure.typeToStructures = {}
    structure.typeToPTknMesh = {}
    structure.typeToPInstance = {}
    structure.typeToPDrawCall = {}
    structure.typeToInstances = {}
end

function structure.teardown()
    structure.typeToStructures = nil
    structure.typeToPTknMesh = nil
    structure.typeToPInstance = nil
    structure.typeToPDrawCall = nil
    structure.typeToInstances = nil
    structure.assetPath = nil
    structure.scale = nil
end

function structure.create(pTknGfxContext, type, x, y)
    local structureObj = {
        type = type,
        position = {x, y},
    }

    if not structure.typeToStructures[type] then
        structure.typeToStructures[type] = {}
        structure.typeToPTknMesh[type] = tknVoxel.readTvox(structure.assetPath .. "/models/" .. type .. ".tvox", pTknGfxContext, {0.5, 0.5, 0})
        structure.typeToPInstance[type] = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {})
        structure.typeToPDrawCall[type] = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, structure.typeToPTknMesh[type], structure.typeToPInstance[type])
        structure.typeToInstances[type] = {
            model = {},
        }
    end

    local instances = structure.typeToInstances[type]
    -- Column-major mat4: each group of 4 = one column; translation in last column [12..15]
    table.insert(instances.model, structure.scale) -- col0
    table.insert(instances.model, 0)
    table.insert(instances.model, 0)
    table.insert(instances.model, 0)
    table.insert(instances.model, 0) -- col1
    table.insert(instances.model, structure.scale)
    table.insert(instances.model, 0)
    table.insert(instances.model, 0)
    table.insert(instances.model, 0) -- col2
    table.insert(instances.model, 0)
    table.insert(instances.model, structure.scale)
    table.insert(instances.model, 0)
    table.insert(instances.model, x) -- col3 (translation)
    table.insert(instances.model, y)
    table.insert(instances.model, 0)
    table.insert(instances.model, 1)

    tkn.tknUpdateInstancePtr(pTknGfxContext, structure.typeToPInstance[type], deferredRenderPass.instanceFormat, instances)
    table.insert(structure.typeToStructures[type], structureObj)
    return structureObj
end

function structure.destroy(pTknGfxContext, structureObj)
    local type = structureObj.type
    local list = structure.typeToStructures[type]
    local instances = structure.typeToInstances[type]

    if not list or not instances then
        return
    end

    local index = nil
    for i, v in ipairs(list) do
        if v == structureObj then
            table.remove(list, i)
            index = i
            break
        end
    end
    if not index then
        return
    end

    for i = 1, 16 do
        table.remove(instances.model, index * 16 - 16 + 1)
    end

    tkn.tknUpdateInstancePtr(pTknGfxContext, structure.typeToPInstance[type], deferredRenderPass.instanceFormat, instances)
end

return structure
