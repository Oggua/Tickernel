-- UI
-- For Node's Layout, if we choose to update on real-time add/delete/modify operations, there might be cases where children are updated before parents, leading to redundant calculations. Therefore, we adopt a unified update approach during the update phase.
-- The creation, deletion, and modification of drawcalls and meshes depend on the add/delete/modify operations of nodes and components.
-- Updating mesh requires layout update first, so it always happens after the update layout phase.
local ui = {}
local tknMath = require("tknMath")
local tkn = require("tkn")
local image = require("image")
local text = require("text")
local uiRenderPass = require("uiRenderPass")

local function traverseNode(node, callback)
    local result = callback(node)
    if result then
        return result
    end
    for _, child in ipairs(node.children) do
        if traverseNode(child, callback) then
            return true
        end
    end
    return false
end
local function updateRect(pGfxContext, ui, node, screenSizeDirty, parentLayoutDirty)
    if node.layout.dirty or parentLayoutDirty or screenSizeDirty then
        -- Get parent dimensions from parent node, or use fullscreen as default (NDC: -1 to 1 = size 2)
        local pWidth, pHeight
        if node.parent then
            pWidth = node.parent.rect.max[1] - node.parent.rect.min[1]
            pHeight = node.parent.rect.max[2] - node.parent.rect.min[2]
        else
            pWidth = 2
            pHeight = 2
        end

        local layout = node.layout
        local width, height

        -- Handle horizontal layout
        if layout.horizontal.type == "anchored" then
            width = layout.horizontal.width / ui.screenWidth * 2
        elseif layout.horizontal.type == "relative" then
            local leftOffset, rightOffset
            if math.type(layout.horizontal.left) == "integer" then
                leftOffset = layout.horizontal.left / ui.screenWidth * 2
            else
                leftOffset = pWidth * layout.horizontal.left
            end
            if math.type(layout.horizontal.right) == "integer" then
                rightOffset = layout.horizontal.right / ui.screenWidth * 2
            else
                rightOffset = pWidth * layout.horizontal.right
            end
            width = pWidth - leftOffset - rightOffset
            if width < 0 then
                width = 0
            end
        else
            error("ui.calculateRect: unknown horizontal layout type " .. tostring(layout.horizontal.type))
        end

        -- Handle vertical layout
        if layout.vertical.type == "anchored" then
            height = layout.vertical.height / ui.screenHeight * 2
        elseif layout.vertical.type == "relative" then
            local topOffset, bottomOffset
            if math.type(layout.vertical.top) == "integer" then
                topOffset = layout.vertical.top / ui.screenHeight * 2
            else
                topOffset = pHeight * layout.vertical.top
            end
            if math.type(layout.vertical.bottom) == "integer" then
                bottomOffset = layout.vertical.bottom / ui.screenHeight * 2
            else
                bottomOffset = pHeight * layout.vertical.bottom
            end
            height = pHeight - topOffset - bottomOffset
            if height < 0 then
                height = 0
            end
        else
            error("ui.calculateRect: unknown vertical layout type " .. tostring(layout.vertical.type))
        end

        -- Build local transform matrix (pivot-centered)
        -- Calculate offset from parent's pivot (0,0) to child's pivot
        local offsetX, offsetY

        -- Horizontal offset calculation
        if layout.horizontal.type == "anchored" then
            -- anchored: position of anchor point within parent space
            offsetX = pWidth * (layout.horizontal.anchor - 0.5)
        else -- relative
            local leftOffset
            if math.type(layout.horizontal.left) == "integer" then
                leftOffset = layout.horizontal.left / ui.screenWidth * 2
            else
                leftOffset = pWidth * layout.horizontal.left
            end
            -- From parent's pivot to child's pivot position
            -- Parent's left edge (relative to parent pivot) + left margin + distance to child pivot
            local parentMinX = node.parent and node.parent.rect.min[1] or -1
            offsetX = parentMinX + leftOffset + width * layout.horizontal.pivot
        end

        -- Add horizontal offset
        if math.type(layout.horizontal.offset) == "integer" then
            offsetX = offsetX + layout.horizontal.offset / ui.screenWidth * 2
        else
            offsetX = offsetX + layout.horizontal.offset
        end

        -- Vertical offset calculation
        if layout.vertical.type == "anchored" then
            -- anchored: position of anchor point within parent space
            offsetY = pHeight * (layout.vertical.anchor - 0.5)
        else -- relative
            local topOffset
            if math.type(layout.vertical.top) == "integer" then
                topOffset = layout.vertical.top / ui.screenHeight * 2
            else
                topOffset = pHeight * layout.vertical.top
            end
            -- From parent's pivot to child's pivot position
            -- Parent's top edge (relative to parent pivot) + top margin + distance to child pivot
            local parentMinY = node.parent and node.parent.rect.min[2] or -1
            offsetY = parentMinY + topOffset + height * layout.vertical.pivot
        end

        -- Add vertical offset
        if math.type(layout.vertical.offset) == "integer" then
            offsetY = offsetY + layout.vertical.offset / ui.screenHeight * 2
        else
            offsetY = offsetY + layout.vertical.offset
        end

        -- Save old bounds and model for change detection
        local oldMin1, oldMin2 = node.rect.min[1], node.rect.min[2]
        local oldMax1, oldMax2 = node.rect.max[1], node.rect.max[2]
        local oldModel = {}
        for i = 1, 9 do
            oldModel[i] = node.rect.model[i]
        end

        -- Get scale values
        local scaleX = layout.horizontal.scale
        local scaleY = layout.vertical.scale

        -- Get rotation angle
        local rotation = layout.rotation
        local cosR = math.cos(rotation)
        local sinR = math.sin(rotation)

        -- Build local transform matrix: T * R * S
        -- GLSL mat3 is column-major: columns are stored sequentially
        -- Apply scale, then rotation, then translation
        local localModel = {scaleX * cosR, scaleX * sinR, 0, -- column 0
        -scaleY * sinR, scaleY * cosR, 0, -- column 1
        offsetX, offsetY, 1 -- column 2 (translation)
        }

        -- Calculate final model by multiplying with parent model
        local parentModel = node.parent and node.parent.rect.model
        if parentModel then
            tknMath.multiplyMat3(parentModel, localModel, node.rect.model)
        else
            -- No parent, final model is same as local model
            for i = 1, 9 do
                node.rect.model[i] = localModel[i]
            end
        end

        -- Update rect bounds (relative to pivot)
        local pivotX = layout.horizontal.pivot
        local pivotY = layout.vertical.pivot
        node.rect.min[1] = -width * pivotX
        node.rect.min[2] = -height * pivotY
        node.rect.max[1] = width * (1 - pivotX)
        node.rect.max[2] = height * (1 - pivotY)

        -- Update color from component
        if node.component then
            node.rect.color = node.component.color
        end

        -- Update mesh only if bounds changed
        local boundsChanged = (oldMin1 ~= node.rect.min[1] or oldMin2 ~= node.rect.min[2] or oldMax1 ~= node.rect.max[1] or oldMax2 ~= node.rect.max[2])
        if boundsChanged and node.component and node.component.pMesh then
            if node.component.type == "image" then
                image.updateMeshPtr(pGfxContext, node.component, node.rect, ui.vertexFormat)
            elseif node.component.type == "text" or screenSizeDirty then
                text.updateMeshPtr(pGfxContext, node.component, node.rect, ui.vertexFormat, ui.screenWidth, ui.screenHeight)
            else
                error("ui.updateRect: unsupported component type " .. tostring(node.component.type))
            end
        end

        -- Update instance only if model matrix or color changed
        local modelChanged = false
        for i = 1, 9 do
            if oldModel[i] ~= node.rect.model[i] then
                modelChanged = true
                break
            end
        end
        local oldColor = node.rect.color
        local colorChanged = node.component and oldColor ~= node.component.color

        if node.component and node.component.pInstance and (modelChanged or colorChanged) then
            local model = node.rect.model
            -- Update instance buffer with model matrix and color
            local instances = {
                model = model,
                color = {node.component.color},
            }
            tkn.updateInstancePtr(pGfxContext, node.component.pInstance, ui.instanceFormat, instances)
        end

        node.layout.dirty = false
        for i, child in ipairs(node.children) do
            updateRect(pGfxContext, ui, child, screenSizeDirty, true)
        end
    else
        for i, child in ipairs(node.children) do
            updateRect(pGfxContext, ui, child, screenSizeDirty, false)
        end
    end
end
local function addComponent(pGfxContext, node, component)
    if node.component then
        print("WARNING: ui.addComponent: node already has a component")
    else
        node.component = component
        if component.pDrawCall then
            local drawCallIndex = 0
            traverseNode(ui.rootNode, function(child)
                if child == node then
                    return true
                else
                    if child.component and child.component.pDrawCall then
                        drawCallIndex = drawCallIndex + 1
                    end
                    return false
                end
            end)
            tkn.insertDrawCallPtr(node.component.pDrawCall, drawCallIndex)
        end
    end
end
local function removeComponent(pGfxContext, node)
    local component = node.component
    if component then
        if component.pDrawCall then
            local drawCallIndex = 0
            traverseNode(ui.rootNode, function(child)
                if child == node then
                    return true
                else
                    if child.component and child.component.pDrawCall then
                        drawCallIndex = drawCallIndex + 1
                    end
                    return false
                end
            end)
            tkn.removeDrawCallAt(drawCallIndex)
        end
    else
        print("ui.removeComponent: node has no component")
        return
    end
end
local function destroyMaterials()
    for _, material in ipairs(ui.materials) do
        tkn.destroyPipelineMaterialPtr(pGfxContext, material)
    end
    ui.materials = {}
end

function ui.setup(pGfxContext, pSwapchainAttachment, assetsPath, renderPassIndex)
    text.setup()
    -- Vertex format: position + uv (no color)
    ui.vertexFormat = {{
        name = "position",
        type = tkn.type.float,
        count = 2,
    }, {
        name = "uv",
        type = tkn.type.float,
        count = 2,
    }}
    ui.vertexFormat.pVertexInputLayout = tkn.createVertexInputLayoutPtr(pGfxContext, ui.vertexFormat)

    -- Instance format: mat3 (9 floats) + color (uint32)
    ui.instanceFormat = {{
        name = "model",
        type = tkn.type.float,
        count = 9, -- 3x3 matrix
    }, {
        name = "color",
        type = tkn.type.uint32,
        count = 1,
    }}
    ui.instanceFormat.pVertexInputLayout = tkn.createVertexInputLayoutPtr(pGfxContext, ui.instanceFormat)

    uiRenderPass.setup(pGfxContext, pSwapchainAttachment, assetsPath, ui.vertexFormat.pVertexInputLayout, ui.instanceFormat.pVertexInputLayout, renderPassIndex)
    ui.rootNode = {
        name = "root",
        children = {},
        layout = {
            dirty = true,
            horizontal = {
                type = "relative",
                pivot = 0.5,
                left = 0,
                right = 0,
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = "relative",
                pivot = 0.5,
                bottom = 0,
                top = 0,
                offset = 0,
                scale = 1.0,
            },
            rotation = 0,
        },
        rect = {
            min = {-1, -1},
            max = {1, 1},
            model = {1, 0, 0, -- column 0
            0, 1, 0, -- column 1
            0, 0, 1}, -- column 2
            color = nil,
        },
    }
    ui.nodePool = {}
    ui.pSampler = tkn.createSamplerPtr(pGfxContext, VK_FILTER_LINEAR, VK_FILTER_LINEAR, VK_SAMPLER_MIPMAP_MODE_LINEAR, VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE, VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE, VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE, 0.0, false, 0.0, 0.0, 0.0, VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK)
    ui.renderPass = uiRenderPass
    ui.materials = {}
end
function ui.teardown(pGfxContext)
    ui.removeNode(pGfxContext, ui.rootNode)
    ui.renderPass = nil
    tkn.destroySamplerPtr(pGfxContext, ui.pSampler)
    ui.pSampler = nil
    ui.nodePool = nil
    ui.rootNode = nil
    uiRenderPass.teardown(pGfxContext)
    tkn.destroyVertexInputLayoutPtr(pGfxContext, ui.instanceFormat.pVertexInputLayout)
    ui.instanceFormat.pVertexInputLayout = nil
    ui.instanceFormat = nil
    tkn.destroyVertexInputLayoutPtr(pGfxContext, ui.vertexFormat.pVertexInputLayout)
    ui.vertexFormat.pVertexInputLayout = nil
    ui.vertexFormat = nil
    text.teardown(pGfxContext)
end
function ui.update(pGfxContext, screenWidth, screenHeight)
    if ui.screenWidth ~= screenWidth or ui.screenHeight ~= screenHeight then
        ui.screenWidth = screenWidth
        ui.screenHeight = screenHeight
        ui.rootNode.layout.dirty = true
    end
    updateRect(pGfxContext, ui, ui.rootNode, false)
    text.update(pGfxContext)
end

function ui.getNodeIndex(node)
    for i, child in ipairs(node.parent.children) do
        if child == node then
            return i
        end
    end
end

function ui.addNode(pGfxContext, parent, index, name, layout)
    assert(parent ~= nil, "ui.addNode: parent is nil")
    assert(index >= 1 and index <= #parent.children + 1, "ui.addNode: index out of bounds")
    local node = nil
    if #ui.nodePool > 0 then
        node = table.remove(ui.nodePool)
        node.name = name
        assert(#node.children == 0, "ui.addNode: node from pool has children")
        node.parent = parent
        node.component = nil
        node.layout = layout
        -- Ensure rect is initialized if not provided
        if not node.rect then
            node.rect = {
                min = {0, 0},
                max = {0, 0},
                model = {1, 0, 0, 0, 1, 0, 0, 0, 1},
                color = nil,
            }
        end
        if node.layout.rotation == nil then
            node.layout.rotation = 0
        end
    else
        node = {
            name = name,
            children = {},
            parent = parent,
            component = nil,
            layout = layout,
        }
        -- Ensure rect is initialized if not provided
        if not node.rect then
            node.rect = {
                min = {0, 0},
                max = {0, 0},
                model = {1, 0, 0, 0, 1, 0, 0, 0, 1},
                color = nil,
            }
        end
    end
    table.insert(parent.children, index, node)
    return node
end
function ui.removeNode(pGfxContext, node)
    print("Removing node: " .. node.name)
    for i = #node.children, 1, -1 do
        ui.removeNode(pGfxContext, node.children[i])
    end

    if node.component then
        if node.component.type == "image" then
            ui.removeImageComponent(pGfxContext, node)
        elseif node.component.type == "text" then
            ui.removeTextComponent(pGfxContext, node)
        else
            error("ui.removeNode: unsupported component type " .. tostring(node.component.type))
        end
    end

    -- Remove node from parent's children list
    if node.parent then
        local nodeIndex = ui.getNodeIndex(node)
        if nodeIndex then
            table.remove(node.parent.children, nodeIndex)
        end
    end

    node.name = nil
    node.parent = nil
    node.children = {}
    node.component = nil
    node.layout = nil
    table.insert(ui.nodePool, node)
end
function ui.moveNode(pGfxContext, node, parent, index)
    assert(node, "ui.moveNode: node is nil")
    assert(node ~= ui.rootNode, "ui.moveNode: cannot move root node")
    assert(parent, "ui.moveNode: parent is nil")

    if node.parent == parent and index == ui.getNodeIndex(node) then
        return true
    else
        assert(parent ~= node, "ui.moveNode: parent cannot be node itself")
        local current = parent
        while current do
            assert(current ~= node, "ui.moveNode: parent cannot be a descendant of node")
            current = current.parent
        end
    end

    local drawCalls = {}
    traverseNode(node, function(child)
        if child.component and child.component.pDrawCall then
            table.insert(drawCalls, child.component.pDrawCall)
        end
    end)

    if #drawCalls == 0 then
        local originalIndex = ui.getNodeIndex(node)
        table.remove(node.parent.children, originalIndex)
        table.insert(parent.children, index, node)
        node.parent = parent
        node.layout.dirty = true
        return true
    else
        local drawCallStartIndex = 0
        traverseNode(ui.rootNode, function(child)
            if child == node then
                return true
            else
                if child.component and child.component.pDrawCall then
                    drawCallStartIndex = drawCallStartIndex + 1
                end
                return false
            end
        end)

        for i = #drawCalls, 1, -1 do
            local removeIndex = drawCallStartIndex + i - 1
            tkn.removeDrawCallAt(removeIndex)
        end

        local originalIndex = ui.getNodeIndex(node)
        table.remove(node.parent.children, originalIndex)
        table.insert(parent.children, index, node)
        node.parent = parent

        drawCallStartIndex = 0
        traverseNode(ui.rootNode, function(child)
            if child == node then
                return true
            else
                if child.component and child.component.pDrawCall then
                    drawCallStartIndex = drawCallStartIndex + 1
                end
                return false
            end
        end)

        for i, dc in ipairs(drawCalls) do
            local insertIndex = drawCallStartIndex + i - 1
            tkn.insertDrawCallPtr(dc, insertIndex)
        end
        node.layout.dirty = true
        return true
    end
end

function ui.addImageComponent(pGfxContext, color, slice, pMaterial, node)
    local component = image.createComponent(pGfxContext, color, slice, pMaterial, ui.vertexFormat, ui.instanceFormat, ui.renderPass.pImagePipeline, node)
    addComponent(pGfxContext, node, component)
    return component
end
function ui.removeImageComponent(pGfxContext, node)
    assert(node.component and node.component.type == "image", "ui.removeImageComponent: node has no image component")
    print("Removing image component")
    image.destroyComponent(pGfxContext, node.component)
    removeComponent(pGfxContext, node)
end

function ui.createMaterialPtr(pGfxContext, pImage, pPipeline)
    local pMaterial = tkn.createPipelineMaterialPtr(pGfxContext, pPipeline)
    if pImage then
        local inputBindings = {{
            vkDescriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            pImage = pImage,
            pSampler = ui.pSampler,
            binding = 0,
        }}
        tkn.updateMaterialPtr(pGfxContext, pMaterial, inputBindings)
    end
    table.insert(ui.materials, pMaterial)
    return pMaterial
end
function ui.destroyMaterialPtr(pGfxContext, pMaterial)
    tkn.destroyPipelineMaterialPtr(pGfxContext, pMaterial)
    table.remove(ui.materials, table.indexOf(ui.materials, pMaterial))
end

function ui.createFont(pGfxContext, path, fontSize, atlasLength)
    local font = text.createFont(pGfxContext, path, fontSize, atlasLength)
    font.pMaterial = ui.createMaterialPtr(pGfxContext, font.pImage, ui.renderPass.pTextPipeline)
    return font
end
function ui.destroyFont(pGfxContext, font)
    ui.destroyMaterialPtr(pGfxContext, font.pMaterial)
    font.pMaterial = nil
    text.destroyFont(pGfxContext, font)
end

function ui.addTextComponent(pGfxContext, textString, font, size, color, alignH, alignV, bold, node)
    local component = text.createComponent(pGfxContext, textString, font, size, color, alignH or 0, alignV or 0, bold, font.pMaterial, ui.vertexFormat, ui.instanceFormat, ui.renderPass.pTextPipeline, node)
    addComponent(pGfxContext, node, component)
    return component
end
function ui.removeTextComponent(pGfxContext, node)
    assert(node.component and node.component.type == "text", "ui.removeTextComponent: node has no text component")
    print("Removing text component")
    text.destroyComponent(pGfxContext, node.component)
    removeComponent(pGfxContext, node)
end
return ui
