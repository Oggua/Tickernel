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
    -- Get orientation properties based on key (horizontal or vertical)
    local orientation = node[key]
    local orientationType = orientation.type
    local orientationPivot = orientation.pivot
    local orientationDirty = orientation.dirty
    local orientationMinOffset = orientation.minOffset
    local orientationMaxOffset = orientation.maxOffset
    local orientationOffset = orientation.offset
    local orientationLength = orientation.length
    local orientationAnchor = orientation.anchor

    local initialized = node.rect
    if not initialized then
        node.rect = {
            horizontal = {
                min = 0,
                max = 0,
            },
            vertical = {
                min = 0,
                max = 0,
            },
            offsetToEffectiveParentNDC = {
                horizontal = 0,
                vertical = 0,
            },
            model = {1, 0, 0, 0, 1, 0, 0, 0, 1},
            color = nil,
            verticesDirty = true,
            modelDirty = true,
            colorDirty = true,
        }
    end
    if orientationType ~= ui.layoutType.fit then
        if orientationDirty or screenLengthChanged or parentOrientationChanged or not initialized then
            local effectiveParentLengthNDC
            if effectiveParent then
                effectiveParentLengthNDC = effectiveParent.rect[key].max - effectiveParent.rect[key].min
            else
                effectiveParentLengthNDC = 2
            end
            local lengthNDC, offsetToEffectiveParentNDC
            local effectiveParentPivot = effectiveParent and effectiveParent[key].pivot or 0.5
            -- Calculate length and offset based on layout type
            if orientationType == ui.layoutType.anchored then
                if math.type(orientationLength) == "integer" then
                    lengthNDC = orientationLength / screenLength * 2
                else
                    lengthNDC = orientationLength
                end
                offsetToEffectiveParentNDC = (orientationAnchor - effectiveParentPivot) * effectiveParentLengthNDC
            elseif orientationType == ui.layoutType.relative then
                local minOffsetToEffectiveParentNDC, maxOffsetToEffectiveParentNDC
                if math.type(orientationMinOffset) == "integer" then
                    minOffsetToEffectiveParentNDC = orientationMinOffset / screenLength * 2
                else
                    minOffsetToEffectiveParentNDC = effectiveParentLengthNDC * orientationMinOffset
                end
                if math.type(orientationMaxOffset) == "integer" then
                    maxOffsetToEffectiveParentNDC = orientationMaxOffset / screenLength * 2
                else
                    maxOffsetToEffectiveParentNDC = effectiveParentLengthNDC * orientationMaxOffset
                end
                lengthNDC = effectiveParentLengthNDC - minOffsetToEffectiveParentNDC + maxOffsetToEffectiveParentNDC
                lengthNDC = lengthNDC < 0 and 0 or lengthNDC
                local anchorToEffectiveParent = (minOffsetToEffectiveParentNDC + lengthNDC * orientationPivot) / effectiveParentLengthNDC
                offsetToEffectiveParentNDC = (anchorToEffectiveParent - effectiveParentPivot) * effectiveParentLengthNDC
            else
                error("Unknown orientation type " .. tostring(orientationType))
            end

            -- Apply additional offset
            if math.type(orientationOffset) == "integer" then
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientationOffset / screenLength * 2
            else
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientationOffset
            end

            local rectMin = -lengthNDC * orientationPivot
            local rectMax = lengthNDC * (1 - orientationPivot)
            if node.rect[key].min ~= rectMin or node.rect[key].max ~= rectMax then
                node.rect.verticesDirty = true
                node.rect[key].min = rectMin
                node.rect[key].max = rectMax
            end

            if node.rect.offsetToEffectiveParentNDC[key] ~= offsetToEffectiveParentNDC then
                node.rect.offsetToEffectiveParentNDC[key] = offsetToEffectiveParentNDC
                node.rect.modelDirty = true
            end
        end
        effectiveParent = node
    else
        -- Keep effectiveParent as is
    end

    -- Update children
    parentOrientationChanged = parentOrientationChanged or orientationDirty or screenLengthChanged
    for i, child in ipairs(node.children) do
        updateOrientationRecursive(pTknGfxContext, ui, child, key, effectiveParent, screenLength, screenLengthChanged, parentOrientationChanged)
    end
    if orientationType ~= ui.layoutType.fit then
        -- Do nothing
    else
        -- Recursively check if any non-fit descendant's orientation is dirty
        local function hasNonFitChildOrientationDirty(checkNode)
            for _, child in ipairs(checkNode.children) do
                local childOrientationType = child[key].type
                if childOrientationType == ui.layoutType.fit and #child.children > 0 then
                    -- Fit node, recursively check its children
                    if hasNonFitChildOrientationDirty(child) then
                        return true
                    end
                else
                    -- Non-fit node, check dirty status
                    if child[key].dirty then
                        return true
                    end
                end
            end
            return false
        end

        if orientationDirty or screenLengthChanged or parentOrientationChanged or not initialized or hasNonFitChildOrientationDirty(node) then
            -- Calculate fit node's bounds based on children's bounds
            local minInEffectiveParentNDC = math.huge
            local maxInEffectiveParentNDC = -math.huge
            for _, child in ipairs(node.children) do
                if child.rect and child.rect[key] then
                    local childMin = child.rect[key].min + child.rect[key].offsetToEffectiveParentNDC
                    local childMax = child.rect[key].max + child.rect[key].offsetToEffectiveParentNDC
                    if childMin < minInEffectiveParentNDC then
                        minInEffectiveParentNDC = childMin
                    end
                    if childMax > maxInEffectiveParentNDC then
                        maxInEffectiveParentNDC = childMax
                    end
                end
            end
            if math.type(orientationMinOffset) == "integer" then
                minInEffectiveParentNDC = minInEffectiveParentNDC + orientationMinOffset / screenLength * 2
                maxInEffectiveParentNDC = maxInEffectiveParentNDC + orientationMaxOffset / screenLength * 2
            else
                minInEffectiveParentNDC = minInEffectiveParentNDC + orientationMinOffset
                maxInEffectiveParentNDC = maxInEffectiveParentNDC + orientationMaxOffset
            end

            -- Handle case with no children
            if minInEffectiveParentNDC == math.huge or maxInEffectiveParentNDC == -math.huge then
                minInEffectiveParentNDC = 0
                maxInEffectiveParentNDC = 0
            end

            -- Calculate length and offset relative to effective parent
            local lengthNDC = maxInEffectiveParentNDC - minInEffectiveParentNDC
            local effectiveParentPivot = effectiveParent and effectiveParent[key].pivot or 0.5
            local effectiveParentLengthNDC
            if effectiveParent then
                effectiveParentLengthNDC = effectiveParent.rect[key].max - effectiveParent.rect[key].min
            else
                effectiveParentLengthNDC = 2
            end

            -- Apply node's pivot
            local pivot = orientationPivot
            local rectMin = -lengthNDC * pivot
            local rectMax = lengthNDC * (1 - pivot)
            if node.rect[key].min ~= rectMin or node.rect[key].max ~= rectMax then
                node.rect[key].min = rectMin
                node.rect[key].max = rectMax
                node.rect.verticesDirty = true
            end
            -- Offset is the center of children bounds adjusted for pivot difference
            local offsetToEffectiveParentNDC = tknMath.lerp(minInEffectiveParentNDC, maxInEffectiveParentNDC, pivot)
            if math.type(orientationOffset) == "integer" then
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientationOffset / screenLength * 2
            else
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientationOffset
            end
            if node.rect.offsetToEffectiveParentNDC[key] ~= offsetToEffectiveParentNDC then
                node.rect.offsetToEffectiveParentNDC[key] = offsetToEffectiveParentNDC
                node.rect.modelDirty = true
            end
        end
    end
    node[key].dirty = false

    -- Handle dirty flags
    if node.transform.colorDirty then
        node.rect.colorDirty = true
        node.transform.colorDirty = false
    end
    if node.transform.modelDirty then
        node.rect.modelDirty = true
        node.transform.modelDirty = false
    end
end

-- Helper function to find effective parent for a given direction (skip fit nodes)
local function findEffectiveParent(node, key)
    local effectiveParent = node.parent
    while effectiveParent and effectiveParent[key].type == ui.layoutType.fit do
        effectiveParent = effectiveParent.parent
    end
    return effectiveParent
end

-- Calculate offset from effectiveParent to direct parent in a given direction
local function calculateOffsetToParent(node, key)
    -- Find effective parent for this direction (skip fit nodes)
    local effectiveParent = findEffectiveParent(node, key)

    if effectiveParent == node.parent then
        -- Parent is effective parent, use offset directly
        return node.rect.offsetToEffectiveParentNDC[key]
    else
        -- Calculate offset relative to direct parent
        -- offsetToParent = offsetToEffectiveParent(node) - offsetToEffectiveParent(parent)
        local nodeOffset = node.rect.offsetToEffectiveParentNDC[key]
        local parentOffset = node.parent.rect.offsetToEffectiveParentNDC[key]
        return nodeOffset - parentOffset
    end
end

-- Transform a 2D offset (already in effectiveParent space) by the parent's full 2x2 + translation.
local function transformOffsetToWorld(localOffsetX, localOffsetY, effectiveParent)
    if effectiveParent and effectiveParent.rect and effectiveParent.rect.model then
        local m = effectiveParent.rect.model
        local worldX = m[1] * localOffsetX + m[2] * localOffsetY + m[7]
        local worldY = m[4] * localOffsetX + m[5] * localOffsetY + m[8]
        return worldX, worldY
    end
    return localOffsetX, localOffsetY
end

local function updateGraphicsRecursive(pTknGfxContext, ui, node, screenWidth, screenHeight, parentModelChanged, parentColorChanged, parentColor)
    local rect = node.rect
    local modelChanged = false
    if rect.modelDirty or parentModelChanged then
        -- Calculate offset relative to direct parent
        local offsetToParentX = calculateOffsetToParent(node, "horizontal")
        local offsetToParentY = calculateOffsetToParent(node, "vertical")
        -- Get scale values from node
        local scaleX = node.transform.horizontalScale
        local scaleY = node.transform.verticalScale
        local rotation = node.transform.rotation
        local cosR = math.cos(rotation)
        local sinR = math.sin(rotation)

        -- Local rotation/scale components: [scaleX*cosR, scaleX*sinR; -scaleY*sinR, scaleY*cosR]
        local local00 = scaleX * cosR
        local local01 = scaleX * sinR
        local local10 = -scaleY * sinR
        local local11 = scaleY * cosR

        if node.parent then
            local pm = node.parent.rect.model
            -- Inherit rotation/scale from parent and combine with local transform
            local rotScaleMatrix00 = pm[1] * local00 + pm[4] * local01
            local rotScaleMatrix01 = pm[2] * local00 + pm[5] * local01
            local rotScaleMatrix10 = pm[1] * local10 + pm[4] * local11
            local rotScaleMatrix11 = pm[2] * local10 + pm[5] * local11
            -- Transform offset by parent's full transform
            local worldOffsetX = pm[1] * offsetToParentX + pm[4] * offsetToParentY + pm[7]
            local worldOffsetY = pm[2] * offsetToParentX + pm[5] * offsetToParentY + pm[8]
            if rect.model[1] ~= rotScaleMatrix00 or rect.model[2] ~= rotScaleMatrix01 or rect.model[3] ~= 0 or rect.model[4] ~= rotScaleMatrix10 or rect.model[5] ~= rotScaleMatrix11 or rect.model[6] ~= 0 or rect.model[7] ~= worldOffsetX or rect.model[8] ~= worldOffsetY or rect.model[9] ~= 1 then
                modelChanged = true
            end
            rect.model[1] = rotScaleMatrix00
            rect.model[2] = rotScaleMatrix01
            rect.model[3] = 0
            rect.model[4] = rotScaleMatrix10
            rect.model[5] = rotScaleMatrix11
            rect.model[6] = 0
            rect.model[7] = worldOffsetX
            rect.model[8] = worldOffsetY
            rect.model[9] = 1
        else
            if rect.model[1] ~= local00 or rect.model[2] ~= local01 or rect.model[3] ~= 0 or rect.model[4] ~= local10 or rect.model[5] ~= local11 or rect.model[6] ~= 0 or rect.model[7] ~= offsetToParentX or rect.model[8] ~= offsetToParentY or rect.model[9] ~= 1 then
                modelChanged = true
            end
            -- No parent, use local transform directly
            rect.model[1] = local00
            rect.model[2] = local01
            rect.model[3] = 0
            rect.model[4] = local10
            rect.model[5] = local11
            rect.model[6] = 0
            rect.model[7] = offsetToParentX
            rect.model[8] = offsetToParentY
            rect.model[9] = 1
        end
        rect.modelDirty = false
    end

    local colorChanged = false
    if rect.colorDirty or parentColorChanged then
        local newColor = tknMath.multiplyColors(parentColor, node.transform.color or 0xFFFFFFFF)
        if rect.color ~= newColor then
            colorChanged = true
            rect.color = newColor
        end
        rect.colorDirty = false
    end

    if rect.verticesDirty then
        -- Update mesh if bounds changed
        if node.pTknMesh then
            local screenSizeChanged = screenWidth ~= ui.screenWidth or screenHeight ~= ui.screenHeight
            if node.type == "imageNode" then
                imageNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, rect.verticesDirty, screenSizeChanged)
            elseif node.type == "textNode" then
                textNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, rect.verticesDirty, screenSizeChanged)
            end
        end
        rect.verticesDirty = false
    end

    -- Update instance if model or color changed
    if node.pTknInstance and (modelChanged or colorChanged) then
        local instances = {
            model = rect.model,
            color = {tkn.rgbaToAbgr(tknMath.multiplyColors(rect.color, node.color))},
        }
        tkn.tknUpdateInstancePtr(pTknGfxContext, node.pTknInstance, ui.instanceFormat, instances)
    end

    -- Recursively update children
    for _, child in ipairs(node.children) do
        updateGraphicsRecursive(pTknGfxContext, ui, child, screenWidth, screenHeight, modelChanged or parentModelChanged, colorChanged or colorChanged, rect.color)
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
        if parent.horizontal.type == ui.layoutType.fit then
            parent.horizontal.dirty = true
        end
        if parent.vertical.type == ui.layoutType.fit then
            parent.vertical.dirty = true
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
    node.rect = nil
end

local function markParentFitNodeDirty(node, orientation)
    local currentParent = node.parent
    if currentParent then
        while currentParent[orientation].type == ui.layoutType.fit do
            currentParent[orientation].dirty = true
            currentParent = currentParent.parent
        end
    end
end

local orientationMetatable = {
    __index = function(t, k)
        if k == "data" or k == "node" then
            error("ui.orientation: cannot access data table or node directly")
        end
        return rawget(t, "data")[k]
    end,
    __newindex = function(t, k, v)
        if k == "data" or k == "node" then
            error("ui.transform: cannot overwrite data table or node")
        else
            rawget(t, "data")[k] = v
            rawget(t, "data").dirty = true
            local node = rawget(t, "data").node
            local orientation = rawget(t, "data").orientation
            markParentFitNodeDirty(node, orientation)
        end
    end,
}

local transformMetatable = {
    __index = function(t, k)
        if k == "data" or k == "node" then
            error("ui.transform: cannot access data table or node directly")
        end
        return rawget(t, "data")[k]
    end,
    __newindex = function(t, k, v)
        if k == "data" or k == "node" then
            error("ui.transform: cannot overwrite data table or node")
        else
            rawget(t, "data")[k] = v
            if k == "color" then
                rawget(t, "data").colorDirty = true
            else
                rawget(t, "data").modelDirty = true
            end
        end
    end,
}

local function addNodeInternal(pTknGfxContext, parent, index, name, horizontal, vertical, transform)
    local node = {
        name = name,
        children = {},
        parent = parent,
        horizontal = {
            data = horizontal,
        },
        vertical = {
            data = vertical,
        },
        transform = {
            data = transform,
        },
    }

    node.horizontal.data.orientation = "horizontal"
    node.vertical.data.orientation = "vertical"
    node.horizontal.data.node = node
    node.vertical.data.node = node
    node.transform.data.node = node
    setmetatable(node.transform, transformMetatable)
    setmetatable(node.horizontal, orientationMetatable)
    setmetatable(node.vertical, orientationMetatable)

    if parent == nil then
        assert(ui.rootNode == nil, "ui.addNode: rootNode is not nil")
        ui.rootNode = node
        ui.topNode = node
    else
        assert(index >= 1 and index <= #parent.children + 1, "ui.addNode: index out of bounds")
        table.insert(parent.children, index, node)
        -- Mark fit ancestors as dirty since their bounds depend on children
        if parent.horizontal.type == ui.layoutType.fit then
            parent.horizontal.dirty = true
        end
        if parent.vertical.type == ui.layoutType.fit then
            parent.vertical.dirty = true
        end
        if isTopNode(node) then
            ui.topNode = node
        end
    end

    return node
end

local function removeNodeInternal(pTknGfxContext, node)
    print("Removing node: " .. node.name)
    local needUpdateTopNode = isTopNode(node)
    local parent = node.parent
    if parent and parent.horizontal.type == ui.layoutType.fit then
        parent.horizontal.dirty = true
    end
    if parent and parent.vertical.type == ui.layoutType.fit then
        parent.vertical.dirty = true
    end

    markParentFitNodeDirty(node, "horizontal")
    markParentFitNodeDirty(node, "vertical")
    removeNodeRecursive(pTknGfxContext, node)
    if needUpdateTopNode then
        if parent == nil then
            ui.topNode = nil
        else
            ui.topNode = getTopNode(parent)
        end
    end
    setmetatable(node.transform, nil)
    setmetatable(node.horizontal, nil)
    setmetatable(node.vertical, nil)
    node.horizontal.data.node = nil
    node.vertical.data.node = nil
    node.transform.data.node = nil
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

    ui.addNode(pTknGfxContext, nil, 1, "root", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
        dirty = false,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
        dirty = false,
    }, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
    })
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
    imageNode.teardown(pTknGfxContext)
end

function ui.update(pTknGfxContext, screenWidth, screenHeight)
    updateOrientationRecursive(pTknGfxContext, ui, ui.rootNode, "horizontal", nil, screenWidth, ui.screenWidth ~= screenWidth, false)
    updateOrientationRecursive(pTknGfxContext, ui, ui.rootNode, "vertical", nil, screenHeight, ui.screenHeight ~= screenHeight, false)
    updateGraphicsRecursive(pTknGfxContext, ui, ui.rootNode, screenWidth, screenHeight, false, false, 0xFFFFFFFF)
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
    markParentFitNodeDirty(node, "horizontal")
    markParentFitNodeDirty(node, "vertical")
    if #drawCalls == 0 then
        local originalIndex = ui.getNodeIndex(node)
        table.remove(node.parent.children, originalIndex)
        table.insert(parent.children, index, node)
        node.parent = parent
        node.horizontal.dirty = true
        node.vertical.dirty = true
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
        if node.type ~= ui.layoutType.fit then
            node.horizontal.dirty = true
            node.vertical.dirty = true
            node.transform.modelDirty = true
            node.transform.colorDirty = true
        end
        markParentFitNodeDirty(node, "horizontal")
        markParentFitNodeDirty(node, "vertical")

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

function ui.addNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, horizontal, vertical, transform);
    node.type = "node"
    return node
end

function ui.addInteractableNode(pTknGfxContext, processInputFunction, parent, index, name, horizontal, vertical, transform)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, horizontal, vertical, transform);
    interactableNode.setupNode(pTknGfxContext, processInputFunction, node)
    return node
end

function ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, color, fitMode, image, uv)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, horizontal, vertical, transform);
    local drawCallIndex = getDrawCallIndex(pTknGfxContext, node)
    imageNode.setupNode(pTknGfxContext, color, fitMode, image, uv, ui.vertexFormat, ui.instanceFormat, ui.renderPass.pImagePipeline, drawCallIndex, node)
    return node
end

function ui.addTextNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, textString, font, size, color, alignH, alignV, bold)
    local node = ui.addNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform);
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
