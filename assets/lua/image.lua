local tkn = require("tkn")
local image = {
    pool = {},
}

function image.createComponent(pGfxContext, color, slice, pMaterial, vertexFormat, pPipeline, node)
    local component = nil
    local pMesh = tkn.createDefaultMeshPtr(pGfxContext, vertexFormat, vertexFormat.pVertexInputLayout, 16, VK_INDEX_TYPE_UINT16, 54)
    -- Get pipeline from the UI render pass

    local pDrawCall = tkn.createDrawCallPtr(pGfxContext, pPipeline, pMaterial, pMesh, nil)

    if #image.pool > 0 then
        component = table.remove(image.pool)
        component.color = color
        component.slice = slice
        component.pMaterial = pMaterial
        component.pMesh = pMesh
        component.pDrawCall = pDrawCall
    else
        component = {
            type = "image",
            color = color,
            slice = slice,
            pMaterial = pMaterial,
            pMesh = pMesh,
            pDrawCall = pDrawCall,
        }
    end
    return component
end
function image.destroyComponent(pGfxContext, component)
    tkn.destroyDrawCallPtr(pGfxContext, component.pDrawCall)
    tkn.destroyMeshPtr(pGfxContext, component.pMesh)

    component.pMaterial = nil
    component.pMesh = nil
    component.pDrawCall = nil
    component.slice = nil
    component.color = 0xFFFFFFFF
    table.insert(image.pool, component)
end

function image.updateMeshPtr(pGfxContext, component, rect, vertexFormat)
    if component.slice then
        -- Nine-slice: generate 4x4 grid with 16 vertices
        local vertices = {
            position = {},
            uv = {},
            color = {},
        }
        -- Simplified implementation: fill 16 vertices with default data
        for i = 1, 16 do
            table.insert(vertices.position, rect.left)
            table.insert(vertices.position, rect.bottom)
            table.insert(vertices.uv, 0.0)
            table.insert(vertices.uv, 0.0)
            table.insert(vertices.color, component.color)
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
        -- Regular quad: 4 vertices
        local vertices = {
            position = {rect.left, rect.bottom, rect.right, rect.bottom, rect.right, rect.top, rect.left, rect.top},
            uv = {0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0},
            color = {component.color, component.color, component.color, component.color},
        }
        local indices = {0, 1, 2, 2, 3, 0}
        tkn.updateMeshPtr(pGfxContext, component.pMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    end
end

return image
