local tkn = require("tkn")
local image = {
    pool = {},
}

function image.createComponent(pGfxContext, color, slice, pMaterial, vertexFormat, instanceFormat, pPipeline, node)
    local component = nil
    local pMesh = tkn.createDefaultMeshPtr(pGfxContext, vertexFormat, vertexFormat.pVertexInputLayout, 16, VK_INDEX_TYPE_UINT16, 54)
    
    -- Create instance buffer (mat3 + color)
    local instances = {
        model = {1, 0, 0, 0, 1, 0, 0, 0, 1},  -- identity matrix
        color = {color},
    }
    local pInstance = tkn.createInstancePtr(pGfxContext, instanceFormat.pVertexInputLayout, instanceFormat, instances)
    
    local pDrawCall = tkn.createDrawCallPtr(pGfxContext, pPipeline, pMaterial, pMesh, pInstance)

    if #image.pool > 0 then
        component = table.remove(image.pool)
        component.color = color
        component.slice = slice
        component.pMaterial = pMaterial
        component.pMesh = pMesh
        component.pInstance = pInstance
        component.pDrawCall = pDrawCall
    else
        component = {
            type = "image",
            color = color,
            slice = slice,
            pMaterial = pMaterial,
            pMesh = pMesh,
            pInstance = pInstance,
            pDrawCall = pDrawCall,
        }
    end
    return component
end
function image.destroyComponent(pGfxContext, component)
    tkn.destroyDrawCallPtr(pGfxContext, component.pDrawCall)
    tkn.destroyInstancePtr(pGfxContext, component.pInstance)
    tkn.destroyMeshPtr(pGfxContext, component.pMesh)

    component.pMaterial = nil
    component.pMesh = nil
    component.pInstance = nil
    component.pDrawCall = nil
    component.slice = nil
    component.color = 0xFFFFFFFF
    table.insert(image.pool, component)
end

function image.updateMeshPtr(pGfxContext, component, layout, vertexFormat, instanceFormat)
    -- Extract layout information
    local model = layout.model
    local pivotX = layout.horizontal.pivot
    local pivotY = layout.vertical.pivot
    local width = layout.width
    local height = layout.height
    
    -- Generate mesh with pivot at (0, 0) in local coordinates
    -- Pivot determines where (0, 0) is within the rectangle
    local left = -width * pivotX
    local right = width * (1 - pivotX)
    local top = -height * pivotY
    local bottom = height * (1 - pivotY)
    
    if component.slice then
        -- Nine-slice: generate 4x4 grid with 16 vertices (pivot-centered)
        local vertices = {
            position = {},
            uv = {},
        }
        -- Simplified implementation: fill 16 vertices with default data
        for i = 1, 16 do
            table.insert(vertices.position, left)
            table.insert(vertices.position, top)
            table.insert(vertices.uv, 0.0)
            table.insert(vertices.uv, 0.0)
        end
        -- Generate indices (9 quads)
        local indices = {}
        for quad = 1, 9 do
            local base = (quad - 1) * 4
            table.insert(indices, base)
            table.insert(indices, base + 1)
            table.insert(indices, base + 2)
            table.insert(indices, base + 2)
            table.insert(indices, base + 3)
            table.insert(indices, base)
        end
        tkn.updateMeshPtr(pGfxContext, component.pMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    else
        -- Regular quad: 4 vertices with pivot at (0, 0)
        local vertices = {
            position = {left, top, right, top, right, bottom, left, bottom},
            uv = {0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0},
        }
        local indices = {0, 1, 2, 2, 3, 0}
        tkn.updateMeshPtr(pGfxContext, component.pMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    end
    
    -- Update instance buffer with model matrix and color
    local instances = {
        model = model,
        color = {component.color},
    }
    tkn.updateInstancePtr(pGfxContext, component.pInstance, instanceFormat, instances)
end

return image
