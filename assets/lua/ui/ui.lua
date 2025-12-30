local ui = {}
local tknMath = require("tknMath")
local tkn = require("tkn")
local imageNode = require("ui.imageNode")
local textNode = require("ui.textNode")
local interactableNode = require("ui.interactableNode")
local uiRenderPass = require("ui.uiRenderPass")
local input = require("input")

ui.layoutType = {
    anchored = "anchored",
    relative = "relative",
    fit = "fit",
}
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

local function traverseNodeReverse(node, callback)
    local result = callback(node)
    if result then
        return result
    end
    for i = #node.children, 1, -1 do
        if traverseNodeReverse(node.children[i], callback) then
            return true
        end
    end
    return false
end

local function updateOrientationRecursive(pTknGfxContext, ui, node, key, effectiveParent, screenLength, screenLengthChanged, parentOrientationChanged)
    local layout = node.layout
    local orientation = layout[key]
    if (orientation.dirty or screenLengthChanged or parentOrientationChanged) and orientation.type ~= ui.layoutType.fit then
        local parentLengthNDC
        if effectiveParent then
            parentLengthNDC = effectiveParent.rect[key].max - effectiveParent.rect[key].min
        else
            parentLengthNDC = 2
        end
        local lengthNDC, offsetNDC
        -- Calculate offset
        local effectiveParentPivot = effectiveParent and effectiveParent.layout[key].pivot or 0.5
        -- Calculate length
        if orientation.type == ui.layoutType.anchored then
            lengthNDC = orientation.length / screenLength * 2
            offsetNDC = (orientation.anchor - effectiveParentPivot) * parentLengthNDC
        elseif orientation.type == ui.layoutType.relative then
            local minOffsetNDC, maxOffsetNDC
            if math.type(orientation.minOffset) == "integer" then
                minOffsetNDC = orientation.minOffset / screenLength * 2
            else
                minOffsetNDC = parentLengthNDC * orientation.minOffset
            end
            if math.type(orientation.maxOffset) == "integer" then
                maxOffsetNDC = orientation.maxOffset / screenLength * 2
            else
                maxOffsetNDC = parentLengthNDC * orientation.maxOffset
            end
            lengthNDC = parentLengthNDC - minOffsetNDC + maxOffsetNDC
            if lengthNDC < 0 then
                lengthNDC = 0
            end
            local anchor = (minOffsetNDC + lengthNDC * orientation.pivot) / parentLengthNDC
            offsetNDC = (anchor - effectiveParentPivot) * parentLengthNDC
        else
            error("Unknown orientation type " .. tostring(orientation.type))
        end

        -- Apply additional offset
        if math.type(orientation.offset) == "integer" then
            offsetNDC = offsetNDC + orientation.offset / screenLength * 2
        else
            offsetNDC = offsetNDC + orientation.offset
        end

        node.rect[key].min = -lengthNDC * orientation.pivot
        node.rect[key].max = lengthNDC * (1 - orientation.pivot)
        node.rect[key].offset = offsetNDC
        effectiveParent = node
    end

    parentOrientationChanged = parentOrientationChanged or orientation.dirty or screenLengthChanged
    for i, child in ipairs(node.children) do
        updateOrientationRecursive(pTknGfxContext, ui, child, key, effectiveParent, screenLength, screenLengthChanged, parentOrientationChanged)
    end

    if (orientation.dirty or screenLengthChanged or parentOrientationChanged) and orientation.type == ui.layoutType.fit then
        -- Calculate fit node's bounds based on children's bounds
        local minBound = math.huge
        local maxBound = -math.huge

        -- Traverse all children to find min and max bounds
        for _, child in ipairs(node.children) do
            if child.rect and child.rect[key] then
                local childMin = child.rect[key].min + child.rect[key].offset
                local childMax = child.rect[key].max + child.rect[key].offset
                if childMin < minBound then
                    minBound = childMin
                end
                if childMax > maxBound then
                    maxBound = childMax
                end
            end
        end
        if math.type(orientation.minOffset) == "integer" then
            minBound = minBound + node.layout[key].minOffset / screenLength * 2
            maxBound = maxBound + node.layout[key].maxOffset / screenLength * 2
        else
            minBound = minBound + node.layout[key].minOffset
            maxBound = maxBound + node.layout[key].maxOffset
        end

        -- Handle case with no children
        if minBound == math.huge or maxBound == -math.huge then
            minBound = 0
            maxBound = 0
        end

        -- Calculate length and offset relative to effective parent
        local lengthNDC = maxBound - minBound
        local centerOffset = (minBound + maxBound) / 2

        -- Calculate offset relative to effective parent's pivot
        local parentPivot = effectiveParent and effectiveParent.layout[key].pivot or 0.5
        local parentLengthNDC
        if effectiveParent then
            parentLengthNDC = effectiveParent.rect[key].max - effectiveParent.rect[key].min
        else
            parentLengthNDC = 2
        end

        -- Apply node's pivot
        local pivot = orientation.pivot
        node.rect[key].min = -lengthNDC * pivot
        node.rect[key].max = lengthNDC * (1 - pivot)

        -- Offset is the center of children bounds adjusted for pivot difference
        local offsetNDC = centerOffset + lengthNDC * (0.5 - pivot)

        -- Apply additional offset
        if math.type(orientation.offset) == "integer" then
            offsetNDC = offsetNDC + orientation.offset / screenLength * 2
        else
            offsetNDC = offsetNDC + orientation.offset
        end

        node.rect[key].offset = offsetNDC
    end
    orientation.dirty = false
end

-- Helper function to find effective parent for a given direction (skip fit nodes)
local function findEffectiveParent(node, key)
    local effectiveParent = node.parent
    while effectiveParent and effectiveParent.layout[key].type == ui.layoutType.fit do
        effectiveParent = effectiveParent.parent
    end
    return effectiveParent
end

-- Helper function to transform local offset to world offset for a given direction
-- key: "horizontal" or "vertical"
-- matrixIndex: 1 for X (uses pm[1]), 5 for Y (uses pm[5])
-- translationIndex: 7 for X, 8 for Y
local function transformOffsetToWorld(localOffset, effectiveParent, matrixIndex, translationIndex)
    if effectiveParent and effectiveParent.rect and effectiveParent.rect.model then
        local pm = effectiveParent.rect.model
        return pm[matrixIndex] * localOffset + pm[translationIndex]
    end
    return localOffset
end

local function updateGraphicsRecursive(pTknGfxContext, ui, node, screenWidth, screenHeight, overrideColor)
    local layout = node.layout
    local rect = node.rect

    -- Save old model for change detection
    local oldModel = {}
    for i = 1, 9 do
        oldModel[i] = rect.model[i]
    end

    -- Find effective parent for each direction (skip fit nodes)
    local effectiveParentH = findEffectiveParent(node, "horizontal")
    local effectiveParentV = findEffectiveParent(node, "vertical")

    -- Transform local offsets to world offsets
    local worldOffsetX = transformOffsetToWorld(rect.horizontal.offset, effectiveParentH, 1, 7)
    local worldOffsetY = transformOffsetToWorld(rect.vertical.offset, effectiveParentV, 5, 8)

    -- Get scale values from layout
    local scaleX = layout.horizontal.scale or 1.0
    local scaleY = layout.vertical.scale or 1.0

    -- Get rotation angle from layout
    local rotation = layout.rotation or 0
    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)

    -- Build local rotation/scale matrix (without translation)
    -- GLSL mat3 is column-major: columns are stored sequentially
    local localRotScale = {scaleX * cosR, scaleX * sinR, 0, -- column 0
    -scaleY * sinR, scaleY * cosR, 0, -- column 1
    0, 0, 1 -- column 2
    }

    -- Find common effective parent for scale/rotation inheritance
    -- Skip nodes that are fit in BOTH directions
    local scaleRotParent = node.parent
    while scaleRotParent and (scaleRotParent.layout.horizontal.type == ui.layoutType.fit and scaleRotParent.layout.vertical.type == ui.layoutType.fit) do
        scaleRotParent = scaleRotParent.parent
    end

    if scaleRotParent and scaleRotParent.rect and scaleRotParent.rect.model then
        local pm = scaleRotParent.rect.model
        -- Multiply rotation/scale part only (2x2 upper-left)
        local newMatrix00 = pm[1] * localRotScale[1] + pm[4] * localRotScale[2]
        local newMatrix01 = pm[2] * localRotScale[1] + pm[5] * localRotScale[2]
        local newMatrix10 = pm[1] * localRotScale[4] + pm[4] * localRotScale[5]
        local newMatrix11 = pm[2] * localRotScale[4] + pm[5] * localRotScale[5]

        rect.model[1] = newMatrix00
        rect.model[2] = newMatrix01
        rect.model[3] = 0
        rect.model[4] = newMatrix10
        rect.model[5] = newMatrix11
        rect.model[6] = 0
        rect.model[7] = worldOffsetX
        rect.model[8] = worldOffsetY
        rect.model[9] = 1
    else
        -- No parent, use local model with world offsets
        rect.model[1] = localRotScale[1]
        rect.model[2] = localRotScale[2]
        rect.model[3] = 0
        rect.model[4] = localRotScale[4]
        rect.model[5] = localRotScale[5]
        rect.model[6] = 0
        rect.model[7] = worldOffsetX
        rect.model[8] = worldOffsetY
        rect.model[9] = 1
    end

    -- Check if model changed
    local modelChanged = false
    for i = 1, 9 do
        if oldModel[i] ~= rect.model[i] then
            modelChanged = true
            break
        end
    end

    -- Check if bounds changed (for mesh update)
    local boundsChanged = (rect.horizontal.oldMin ~= rect.horizontal.min or rect.horizontal.oldMax ~= rect.horizontal.max or rect.vertical.oldMin ~= rect.vertical.min or rect.vertical.oldMax ~= rect.vertical.max)
    rect.horizontal.oldMin = rect.horizontal.min
    rect.horizontal.oldMax = rect.horizontal.max
    rect.vertical.oldMin = rect.vertical.min
    rect.vertical.oldMax = rect.vertical.max

    -- Update color with override
    local oldColor = rect.color
    if node.overrideColor then
        overrideColor = tknMath.multiplyColors(node.overrideColor, overrideColor)
    end
    if node.color then
        rect.color = tknMath.multiplyColors(node.color, overrideColor)
    else
        rect.color = overrideColor
    end

    local colorChanged = oldColor ~= rect.color
    local screenSizeChanged = screenWidth ~= ui.screenWidth or screenHeight ~= ui.screenHeight
    -- Update mesh if bounds changed
    if node.pTknMesh then
        if node.type == "imageNode" then
            imageNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, boundsChanged, screenSizeChanged)
        elseif node.type == "textNode" then
            textNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, boundsChanged, screenSizeChanged)
        end
    end

    -- Update instance if model or color changed
    if node.pTknInstance and (modelChanged or colorChanged) then
        local instances = {
            model = rect.model,
            color = {tkn.rgbaToAbgr(rect.color)},
        }
        tkn.tknUpdateInstancePtr(pTknGfxContext, node.pTknInstance, ui.instanceFormat, instances)
    end

    -- Recursively update children
    for _, child in ipairs(node.children) do
        updateGraphicsRecursive(pTknGfxContext, ui, child, screenWidth, screenHeight, overrideColor)
    end
end

local function getDrawCallIndex(pTknGfxContext, node)
    local drawCallIndex = 0
    traverseNode(ui.rootNode, function(child)
        if child == node then
            return true
        else
            if child and child.pTknDrawCall then
                drawCallIndex = drawCallIndex + 1
            end
            return false
        end
    end)
    return drawCallIndex
end

local function isTopNode(node)
    if not node.parent then
        return true
    else
        if node.parent.children[#node.parent.children] ~= node then
            return false
        else
            return isTopNode(node.parent)
        end
    end
end

local function getTopNode(node)
    if #node.children > 0 then
        return getTopNode(node.children[#node.children])
    else
        return node
    end
end

local function getActiveInputNode(node, xNDC, yNDC, inputState)
    for i = #node.children, 1, -1 do
        local child = node.children[i]
        local node = getActiveInputNode(child, xNDC, yNDC, inputState)
        if node then
            return node
        end
    end

    if node and node.type == "interactableNode" and ui.rectContainsPoint(node.rect, xNDC, yNDC) then
        return node
    else
        return nil
    end
end

local function removeNodeRecursive(pTknGfxContext, node)
    if node.parent then
        local parent = node.parent
        if parent.layout.horizontal.type == ui.layoutType.fit then
            parent.layout.horizontal.dirty = true
        end
        if parent.layout.vertical.type == ui.layoutType.fit then
            parent.layout.vertical.dirty = true
        end
    end
    for i = #node.children, 1, -1 do
        removeNodeRecursive(pTknGfxContext, node.children[i])
    end

    if node.type == "imageNode" then
        imageNode.teardownNode(pTknGfxContext, node)
    elseif node.type == "textNode" then
        textNode.teardownNode(pTknGfxContext, node)
    elseif node.type == "interactableNode" then
        interactableNode.teardownNode(pTknGfxContext, node)
    elseif node.type == "node" then
        node.type = nil
    else
        error("ui.removeNode: unsupported component type " .. tostring(node.type))
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
    node.layout = nil
    node.rect = nil
end

function ui.setup(pTknGfxContext, pSwapchainAttachment, assetsPath, renderPassIndex)
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
    ui.vertexFormat.pTknVertexInputLayout = tkn.tknCreateVertexInputLayoutPtr(pTknGfxContext, ui.vertexFormat)

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
    ui.instanceFormat.pTknVertexInputLayout = tkn.tknCreateVertexInputLayoutPtr(pTknGfxContext, ui.instanceFormat)

    uiRenderPass.setup(pTknGfxContext, pSwapchainAttachment, assetsPath, ui.vertexFormat.pTknVertexInputLayout, ui.instanceFormat.pTknVertexInputLayout, renderPassIndex)

    ui.pTknSampler = tkn.tknCreateSamplerPtr(pTknGfxContext, VK_FILTER_LINEAR, VK_FILTER_LINEAR, VK_SAMPLER_MIPMAP_MODE_LINEAR, VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER, VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER, VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER, 0.0, false, 0.0, 0.0, 0.0, VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK)
    ui.renderPass = uiRenderPass

    imageNode.setup(assetsPath)
    ui.fitModeType = imageNode.fitModeType
    textNode.setup(assetsPath)

    ui.rootNode = {
        name = "root",
        children = {},
        layout = {
            dirty = true,
            horizontal = {
                type = ui.layoutType.relative,
                pivot = 0.5,
                minOffset = 0,
                maxOffset = 0,
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = ui.layoutType.relative,
                pivot = 0.5,
                maxOffset = 0,
                minOffset = 0,
                offset = 0,
                scale = 1.0,
            },
            rotation = 0,
        },
        rect = {
            horizontal = {
                min = -1,
                max = 1,
                offset = 0,
            },
            vertical = {
                min = -1,
                max = 1,
                offset = 0,
            },
            model = {1, 0, 0, 0, 1, 0, 0, 0, 1},
            color = nil,
        },
        type = "node",
    }
    ui.topNode = ui.rootNode
end

function ui.teardown(pTknGfxContext)
    ui.removeNode(pTknGfxContext, ui.rootNode)
    ui.renderPass = nil
    tkn.tknDestroySamplerPtr(pTknGfxContext, ui.pTknSampler)
    ui.pTknSampler = nil
    ui.rootNode = nil
    uiRenderPass.teardown(pTknGfxContext)
    tkn.tknDestroyVertexInputLayoutPtr(pTknGfxContext, ui.instanceFormat.pTknVertexInputLayout)
    ui.instanceFormat.pTknVertexInputLayout = nil
    ui.instanceFormat = nil
    tkn.tknDestroyVertexInputLayoutPtr(pTknGfxContext, ui.vertexFormat.pTknVertexInputLayout)
    ui.vertexFormat.pTknVertexInputLayout = nil
    ui.vertexFormat = nil
    textNode.teardown()
    imageNode.teardown()
end

function ui.update(pTknGfxContext, screenWidth, screenHeight)
    updateOrientationRecursive(pTknGfxContext, ui, ui.rootNode, "horizontal", nil, screenWidth, ui.screenWidth ~= screenWidth, false)
    updateOrientationRecursive(pTknGfxContext, ui, ui.rootNode, "vertical", nil, screenHeight, ui.screenHeight ~= screenHeight, false)
    updateGraphicsRecursive(pTknGfxContext, ui, ui.rootNode, screenWidth, screenHeight, 0xFFFFFFFF)
    ui.screenWidth = screenWidth
    ui.screenHeight = screenHeight
    textNode.update(pTknGfxContext)

    if ui.activeInteractableNode then
        local isActive = ui.activeInteractableNode.processInputFunction(ui.activeInteractableNode, input.mousePositionNDC.x, input.mousePositionNDC.y, input.getMouseState(input.mouseCode.left))
        if isActive then
            -- Still active
        else
            ui.activeInteractableNode = nil
        end
    else
        if input.getMouseState(input.mouseCode.left) == input.inputState.down then
            ui.activeInteractableNode = getActiveInputNode(ui.rootNode, input.mousePositionNDC.x, input.mousePositionNDC.y, input.getMouseState(input.mouseCode.left))
        else
            -- No active input node
        end
    end
end

function ui.getNodeIndex(node)
    for i, child in ipairs(node.parent.children) do
        if child == node then
            return i
        end
    end
end

local function addNodeInternal(pTknGfxContext, parent, index, name, layout)
    assert(parent ~= nil, "ui.addNode: parent is nil")
    assert(index >= 1 and index <= #parent.children + 1, "ui.addNode: index out of bounds")
    local node = {
        name = name,
        children = {},
        parent = parent,
        layout = layout,
        rect = {
            horizontal = {
                min = 0,
                max = 0,
                offset = 0,
            },
            vertical = {
                min = 0,
                max = 0,
                offset = 0,
            },
            model = {1, 0, 0, 0, 1, 0, 0, 0, 1},
            color = nil,
        },
    }
    table.insert(parent.children, index, node)

    -- Mark fit ancestors as dirty since their bounds depend on children
    local ancestor = parent
    while ancestor do
        if ancestor.layout.horizontal.type == ui.layoutType.fit then
            ancestor.layout.horizontal.dirty = true
        end
        if ancestor.layout.vertical.type == ui.layoutType.fit then
            ancestor.layout.vertical.dirty = true
        end
        ancestor = ancestor.parent
    end

    if isTopNode(node) then
        ui.topNode = node
    end
    return node
end

local function removeNodeInternal(pTknGfxContext, node)
    print("Removing node: " .. node.name)
    local needUpdateTopNode = isTopNode(node)
    local parent = node.parent
    removeNodeRecursive(pTknGfxContext, node)
    if needUpdateTopNode then
        if parent == nil then
            ui.topNode = nil
        else
            ui.topNode = getTopNode(parent)
        end
    end
end

function ui.moveNode(pTknGfxContext, node, parent, index)
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
        if child.component and child.component.pTknDrawCall then
            table.insert(drawCalls, child.component.pTknDrawCall)
        end
    end)

    if #drawCalls == 0 then
        local originalIndex = ui.getNodeIndex(node)
        table.remove(node.parent.children, originalIndex)
        table.insert(parent.children, index, node)
        node.parent = parent
        node.layout.dirty = true
        if isTopNode(node) then
            ui.topNode = getTopNode(ui.rootNode)
        end
        return true
    else
        local drawCallStartIndex = 0
        traverseNode(ui.rootNode, function(child)
            if child == node then
                return true
            else
                if child.component and child.component.pTknDrawCall then
                    drawCallStartIndex = drawCallStartIndex + 1
                end
                return false
            end
        end)

        for i = #drawCalls, 1, -1 do
            local removeIndex = drawCallStartIndex + i - 1
            tkn.tknRemoveDrawCallAt(removeIndex)
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
                if child.component and child.component.pTknDrawCall then
                    drawCallStartIndex = drawCallStartIndex + 1
                end
                return false
            end
        end)

        for i, dc in ipairs(drawCalls) do
            local insertIndex = drawCallStartIndex + i - 1
            tkn.tknInsertDrawCallPtr(dc, insertIndex)
        end
        node.layout.dirty = true
        if isTopNode(node) then
            ui.topNode = getTopNode(ui.rootNode)
        end
        return true
    end
end

function ui.loadImage(pTknGfxContext, path)
    return imageNode.loadImage(pTknGfxContext, path, ui.pTknSampler, ui.renderPass.pImagePipeline)
end
function ui.unloadImage(pTknGfxContext, image)
    imageNode.unloadImage(pTknGfxContext, image)
end

function ui.loadFont(pTknGfxContext, path, fontSize, atlasLength)
    return textNode.loadFont(pTknGfxContext, path, fontSize, atlasLength, ui.pTknSampler, ui.renderPass.pTextPipeline)
end
function ui.unloadFont(pTknGfxContext, font)
    textNode.unloadFont(pTknGfxContext, font)
end

function ui.addNode(pTknGfxContext, parent, index, name, layout)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, layout);
    node.type = "node"
    return node
end

function ui.addInteractableNode(pTknGfxContext, processInputFunction, parent, index, name, layout)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, layout);
    interactableNode.setupNode(pTknGfxContext, processInputFunction, node)
    return node
end

function ui.addImageNode(pTknGfxContext, parent, index, name, layout, color, fitMode, image, uv)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, layout);
    local drawCallIndex = getDrawCallIndex(pTknGfxContext, node)
    imageNode.setupNode(pTknGfxContext, color, fitMode, image, uv, ui.vertexFormat, ui.instanceFormat, ui.renderPass.pImagePipeline, drawCallIndex, node)
    return node
end

function ui.addTextNode(pTknGfxContext, parent, index, name, layout, textString, font, size, color, alignH, alignV, bold)
    local node = ui.addNode(pTknGfxContext, parent, index, name, layout);
    local drawCallIndex = getDrawCallIndex(pTknGfxContext, node)
    textNode.setupNode(pTknGfxContext, textString, font, size, color, alignH or 0, alignV or 0, bold, font.pTknMaterial, ui.vertexFormat, ui.instanceFormat, ui.renderPass.pTextPipeline, drawCallIndex, node)
    return node
end

function ui.removeNode(pTknGfxContext, node)
    removeNodeInternal(pTknGfxContext, node)
end

function ui.rectContainsPoint(rect, xNDC, yNDC)
    local rx = rect.horizontal or {
        min = 0,
        max = 0,
    }
    local ry = rect.vertical or {
        min = 0,
        max = 0,
    }
    local model = rect.model
    local worldX = model[7]
    local worldY = model[8]
    local minX = worldX + rx.min
    local maxX = worldX + rx.max
    local minY = worldY + ry.min
    local maxY = worldY + ry.max
    return xNDC >= minX and xNDC <= maxX and yNDC >= minY and yNDC <= maxY
end

return ui
