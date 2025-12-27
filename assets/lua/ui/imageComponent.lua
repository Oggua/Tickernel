local tkn = require("tkn")
local imageComponent = {}
imageComponent.fitModeType = {
    normal = 1,
    sliced = 2,
    cover = 3,
    contain = 4,
}

function imageComponent.setup(assetsPath)
    imageComponent.assetsPath = assetsPath
    imageComponent.pool = {}
    imageComponent.pathToImage = {}
end

function imageComponent.teardown(pTknGfxContext)
    for path, image in pairs(imageComponent.pathToImage) do
        tkn.tknDestroyImagePtr(pTknGfxContext, image.pTknImage)
        image.pTknImage = nil
        image.width = 0
        image.height = 0
        image.path = nil
        image.pTknMaterial = nil
    end
    imageComponent.assetsPath = nil
    imageComponent.pool = nil
    imageComponent.pathToImage = nil
end

function imageComponent.loadImage(pTknGfxContext, path, pTknSampler, pTknPipeline)
    if imageComponent.pathToImage[path] then
        return imageComponent.pathToImage[path]
    else
        local pTknImage, width, height = tkn.tknCreateImagePtrWithPath(pTknGfxContext, imageComponent.assetsPath .. path)
        if pTknImage == nil then
            return nil
        else
            local pTknMaterial = tkn.tknCreatePipelineMaterialPtr(pTknGfxContext, pTknPipeline)
            local inputBindings = {{
                vkDescriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                pTknImage = pTknImage,
                pTknSampler = pTknSampler,
                binding = 0,
            }}
            tkn.tknUpdateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindings)
            local image = {
                pTknImage = pTknImage,
                width = width,
                height = height,
                path = path,
                pTknMaterial = pTknMaterial,
            }
            imageComponent.pathToImage[path] = image
            return image
        end
    end
end

function imageComponent.unloadImage(pTknGfxContext, image)
    imageComponent.pathToImage[image.path] = nil
    tkn.tknDestroyImagePtr(pTknGfxContext, image.pTknImage)
    image.pTknImage = nil
    image.width = 0
    image.height = 0
    image.path = nil
end

function imageComponent.createComponent(pTknGfxContext, color, fitMode, image, uv, vertexFormat, instanceFormat, pTknPipeline, node)
    local component = nil
    local pTknMesh = tkn.tknCreateDefaultMeshPtr(pTknGfxContext, vertexFormat, vertexFormat.pTknVertexInputLayout, 16, VK_INDEX_TYPE_UINT16, 54)

    -- Create instance buffer (mat3 + color)
    local instances = {
        model = {1, 0, 0, 0, 1, 0, 0, 0, 1}, -- identity matrix
        color = {color},
    }
    local pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, instanceFormat.pTknVertexInputLayout, instanceFormat, instances)
    local pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, pTknPipeline, image.pTknMaterial, pTknMesh, pTknInstance)
    if #imageComponent.pool > 0 then
        component = table.remove(imageComponent.pool)
        component.color = color
        component.fitMode = fitMode
        component.image = image
        component.uv = uv
        component.pTknMesh = pTknMesh
        component.pTknInstance = pTknInstance
        component.pTknDrawCall = pTknDrawCall
        component.node = node
    else
        component = {
            type = "Image",
            color = color,
            fitMode = fitMode,
            image = image,
            uv = uv,
            pTknMesh = pTknMesh,
            pTknInstance = pTknInstance,
            pTknDrawCall = pTknDrawCall,
            node = node,
        }
    end
    return component
end

function imageComponent.destroyComponent(pTknGfxContext, component)
    tkn.tknDestroyDrawCallPtr(pTknGfxContext, component.pTknDrawCall)
    tkn.tknDestroyInstancePtr(pTknGfxContext, component.pTknInstance)
    tkn.tknDestroyMeshPtr(pTknGfxContext, component.pTknMesh)

    component.image = nil
    component.uv = nil
    component.pTknMesh = nil
    component.pTknInstance = nil
    component.pTknDrawCall = nil
    component.fitMode = nil
    component.color = 0xFFFFFFFF
    component.node = nil
    table.insert(imageComponent.pool, component)
end

function imageComponent.updateMeshPtr(pTknGfxContext, component, rect, vertexFormat, screenWidth, screenHeight, boundsChanged, screenSizeChanged)
    if boundsChanged or (screenSizeChanged and component.fitMode.type ~= imageComponent.fitModeType.sliced) then
        -- rect.horizontal/vertical.min/max are already relative to pivot (0, 0)
        local left = rect.horizontal.min
        local top = rect.vertical.min
        local right = rect.horizontal.max
        local bottom = rect.vertical.max
        if component.fitMode.type == imageComponent.fitModeType.normal then
            -- Regular quad: 4 vertices with pivot at (0, 0)
            local vertices = {
                position = {left, top, right, top, right, bottom, left, bottom},
                uv = {component.uv.u0, component.uv.v0, component.uv.u1, component.uv.v0, component.uv.u1, component.uv.v1, component.uv.u0, component.uv.v1},
            }
            local indices = {0, 1, 2, 2, 3, 0}
            tkn.tknUpdateMeshPtr(pTknGfxContext, component.pTknMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
        elseif component.fitMode.type == imageComponent.fitModeType.sliced then
            -- 9-slice: calculate 16 UVs and positions based on padding and uv
            local h = component.fitMode.horizontal
            local v = component.fitMode.vertical
            local u0, v0, u1, v1 = component.uv.u0, component.uv.v0, component.uv.u1, component.uv.v1
            -- Calculate split points (4 for each axis)

            local uL = u0
            local uR = u1
            local uML = u0 + h.minPadding / component.image.width
            local uMR = u1 - h.maxPadding / component.image.width
            local vT = v0
            local vB = v1
            local vMT = v0 + v.minPadding / component.image.height
            local vMB = v1 - v.maxPadding / component.image.height

            -- 4x4 grid of UVs
            local uvGrid = {{uL, vT}, {uML, vT}, {uMR, vT}, {uR, vT}, {uL, vMT}, {uML, vMT}, {uMR, vMT}, {uR, vMT}, {uL, vMB}, {uML, vMB}, {uMR, vMB}, {uR, vMB}, {uL, vB}, {uML, vB}, {uMR, vB}, {uR, vB}}

            -- 4x4 grid of positions (for demonstration, should be calculated with rect/padding)
            local xL = left
            local xR = right
            local xML = left + (right - left) * h.minPadding / screenWidth * 2
            local xMR = right - (right - left) * h.maxPadding / screenWidth * 2
            local yT = top
            local yB = bottom
            local yMT = top + (bottom - top) * v.minPadding / screenHeight * 2
            local yMB = bottom - (bottom - top) * v.maxPadding / screenHeight * 2
            local posGrid = {{xL, yT}, {xML, yT}, {xMR, yT}, {xR, yT}, {xL, yMT}, {xML, yMT}, {xMR, yMT}, {xR, yMT}, {xL, yMB}, {xML, yMB}, {xMR, yMB}, {xR, yMB}, {xL, yB}, {xML, yB}, {xMR, yB}, {xR, yB}}
            local vertices = {
                position = {},
                uv = {},
            }
            for i = 1, 16 do
                table.insert(vertices.position, posGrid[i][1])
                table.insert(vertices.position, posGrid[i][2])
                table.insert(vertices.uv, uvGrid[i][1])
                table.insert(vertices.uv, uvGrid[i][2])
            end
            -- Generate indices (9 quads, 2 triangles each)
            local indices = {}
            for row = 0, 2 do
                for col = 0, 2 do
                    local idx = row * 4 + col
                    local v0 = idx
                    local v1 = idx + 1
                    local v2 = idx + 5
                    local v3 = idx + 4
                    table.insert(indices, v0)
                    table.insert(indices, v1)
                    table.insert(indices, v2)
                    table.insert(indices, v2)
                    table.insert(indices, v3)
                    table.insert(indices, v0)
                end
            end
            tkn.tknUpdateMeshPtr(pTknGfxContext, component.pTknMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
        else
            -- Calculate UV based on fitMode (cover/contain)
            local u0, v0, u1, v1 = 0.0, 0.0, 1.0, 1.0
            local containerWidth = right - left
            local containerHeight = bottom - top
            local containerAspect = containerWidth * screenWidth / (containerHeight * screenHeight)
            local imageAspect = component.image.width / component.image.height
            print("Container Aspect: " .. tostring(containerAspect) .. ", Image Aspect: " .. tostring(imageAspect))
            if component.fitMode.type == imageComponent.fitModeType.cover then
                -- Cover: image fills container, may crop
                if imageAspect > containerAspect then
                    -- Image is wider, crop left/right
                    local scale = containerAspect / imageAspect
                    local offset = (1.0 - scale) / 2.0
                    u0, u1 = offset, 1.0 - offset
                else
                    -- Image is taller, crop top/bottom
                    local scale = imageAspect / containerAspect
                    local offset = (1.0 - scale) / 2.0
                    v0, v1 = offset, 1.0 - offset
                end

                -- Regular quad: 4 vertices with pivot at (0, 0)
                local vertices = {
                    position = {left, top, right, top, right, bottom, left, bottom},
                    uv = {u0, v0, u1, v0, u1, v1, u0, v1},
                }
                local indices = {0, 1, 2, 2, 3, 0}
                tkn.tknUpdateMeshPtr(pTknGfxContext, component.pTknMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
            elseif component.fitMode.type == imageComponent.fitModeType.contain then
                -- Adjust vertex positions instead of UV for true contain
                if imageAspect > containerAspect then
                    -- Image is wider, add letterbox top/bottom
                    local newHeight = ((containerWidth * screenWidth / 2.0) / imageAspect) / screenHeight * 2.0
                    local offset = (newHeight - containerHeight) / 2.0
                    print(offset)
                    v0, v1 = offset, 1.0 - offset
                else
                    -- Image is taller, add letterbox left/right
                    local newWidth = (containerHeight * screenHeight / 2.0) * imageAspect / screenWidth * 2.0
                    local offset = (newWidth - containerWidth) / 2.0
                    print(offset)
                    u0, u1 = offset, 1.0 - offset
                end
                -- Regular quad: 4 vertices with pivot at (0, 0)
                local vertices = {
                    position = {left, top, right, top, right, bottom, left, bottom},
                    uv = {u0, v0, u1, v0, u1, v1, u0, v1},
                }
                local indices = {0, 1, 2, 2, 3, 0}
                tkn.tknUpdateMeshPtr(pTknGfxContext, component.pTknMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
            else
                error("Unknown fitMode type: " .. tostring(component.fitMode.type))
            end
        end
    end
end

function imageComponent.updateInstancePtr(pTknGfxContext, component, rect, instanceFormat)
    -- Update instance buffer with model matrix and color
    local instances = {
        model = rect.model,
        color = {rect.color},
    }
    tkn.tknUpdateInstancePtr(pTknGfxContext, component.pTknInstance, instanceFormat, instances)
end

return imageComponent
