local tkn = require("tkn")
local imageComponent = {}

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

function imageComponent.createComponent(pTknGfxContext, color, fitMode, image, vertexFormat, instanceFormat, pTknPipeline, node)
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
    component.pTknMesh = nil
    component.pTknInstance = nil
    component.pTknDrawCall = nil
    component.fitMode = nil
    component.color = 0xFFFFFFFF
    component.node = nil
    table.insert(imageComponent.pool, component)
end

function imageComponent.updateMeshPtr(pTknGfxContext, component, rect, vertexFormat, screenWidth, screenHeight)
    -- rect.horizontal/vertical.min/max are already relative to pivot (0, 0)
    local left = rect.horizontal.min
    local top = rect.vertical.min
    local right = rect.horizontal.max
    local bottom = rect.vertical.max
    if component.fitMode.type == "Sliced" then
        -- Nine-fitMode: generate 4x4 grid with 16 vertices (pivot-centered)
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
        tkn.tknUpdateMeshPtr(pTknGfxContext, component.pTknMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    else
        -- Calculate UV based on fitMode (cover/contain)
        local u0, v0, u1, v1 = 0.0, 0.0, 1.0, 1.0
        local containerWidth = right - left
        local containerHeight = bottom - top
        local containerAspect = containerWidth * screenWidth / (containerHeight * screenHeight)
        local imageAspect = component.image.width / component.image.height
        print("Container Aspect: " .. tostring(containerAspect) .. ", Image Aspect: " .. tostring(imageAspect))
        if component.fitMode.type == "Cover" then
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
        elseif component.fitMode.type == "Contain" then
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

function imageComponent.updateInstancePtr(pTknGfxContext, component, rect, instanceFormat)
    -- Update instance buffer with model matrix and color
    local instances = {
        model = rect.model,
        color = {rect.color},
    }
    tkn.tknUpdateInstancePtr(pTknGfxContext, component.pTknInstance, instanceFormat, instances)
end

return imageComponent
