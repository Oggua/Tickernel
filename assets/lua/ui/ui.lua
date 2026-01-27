local ui = {}
local tknMath = require("tknMath")
local tkn = require("tkn")
local imageNode = require("ui.imageNode")
local textNode = require("ui.textNode")
local interactableNode = require("ui.interactableNode")
local uiRenderPass = require("ui.uiRenderPass")
local input = require("input")
local colorPreset = require("ui.colorPreset")

local function updateOrientationRecursive(pTknGfxContext, ui, node, key, effectiveParent, screenLength, screenLengthDirty, parentOrientationDirty)
    -- Get orientation properties based on key (horizontal or vertical)
    local orientation = node[key]

    local initialized = node.rect
    if not initialized then
        node.rect = {
            horizontal = {
                min = nil,
                max = nil,
            },
            vertical = {
                min = nil,
                max = nil,
            },
            offsetToEffectiveParentNDC = {
                horizontal = nil,
                vertical = nil,
            },
            model = {nil, nil, nil, nil, nil, nil, nil, nil, nil},
            color = nil,
            boundsDirty = true,
            modelDirty = true,
            colorDirty = true,
            active = false,
        }
    end

    if orientation.type ~= ui.layoutType.fit then
        if orientation.dirty or screenLengthDirty or parentOrientationDirty or not initialized then
            node.rect.modelDirty = true
            local effectiveParentLengthNDC
            if effectiveParent then
                effectiveParentLengthNDC = effectiveParent.rect[key].max - effectiveParent.rect[key].min
            else
                effectiveParentLengthNDC = 2
            end
            local lengthNDC, offsetToEffectiveParentNDC
            local effectiveParentPivot = effectiveParent and effectiveParent[key].pivot or 0.5
            -- Calculate length and offset based on layout type
            if orientation.type == ui.layoutType.anchored then
                if math.type(orientation.length) == "integer" then
                    lengthNDC = orientation.length / screenLength * 2
                else
                    lengthNDC = orientation.length
                end
                offsetToEffectiveParentNDC = (orientation.anchor - effectiveParentPivot) * effectiveParentLengthNDC
            elseif orientation.type == ui.layoutType.relative then
                local minOffsetToEffectiveParentNDC, maxOffsetToEffectiveParentNDC
                if math.type(orientation.minOffset) == "integer" then
                    minOffsetToEffectiveParentNDC = orientation.minOffset / screenLength * 2
                else
                    minOffsetToEffectiveParentNDC = effectiveParentLengthNDC * orientation.minOffset
                end
                if math.type(orientation.maxOffset) == "integer" then
                    maxOffsetToEffectiveParentNDC = orientation.maxOffset / screenLength * 2
                else
                    maxOffsetToEffectiveParentNDC = effectiveParentLengthNDC * orientation.maxOffset
                end
                lengthNDC = effectiveParentLengthNDC - minOffsetToEffectiveParentNDC + maxOffsetToEffectiveParentNDC
                lengthNDC = lengthNDC < 0 and 0 or lengthNDC
                local anchorToEffectiveParent = (minOffsetToEffectiveParentNDC + lengthNDC * orientation.pivot) / effectiveParentLengthNDC
                offsetToEffectiveParentNDC = (anchorToEffectiveParent - effectiveParentPivot) * effectiveParentLengthNDC
            else
                error("Unknown orientation type " .. tostring(orientation.type))
            end

            -- Apply additional offset
            if math.type(orientation.offset) == "integer" then
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientation.offset / screenLength * 2
            else
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientation.offset
            end

            local rectMin = -lengthNDC * orientation.pivot
            local rectMax = lengthNDC * (1 - orientation.pivot)
            if node.rect[key].min ~= rectMin or node.rect[key].max ~= rectMax then
                node.rect.boundsDirty = true
                node.rect[key].min = rectMin
                node.rect[key].max = rectMax
            end

            node.rect.offsetToEffectiveParentNDC[key] = offsetToEffectiveParentNDC
        end
        effectiveParent = node
    else
        -- Keep effectiveParent as is
    end

    -- Update children
    parentOrientationDirty = parentOrientationDirty or orientation.dirty or screenLengthDirty
    for i, child in ipairs(node.children) do
        updateOrientationRecursive(pTknGfxContext, ui, child, key, effectiveParent, screenLength, screenLengthDirty, parentOrientationDirty)
    end

    if orientation.type ~= ui.layoutType.fit then
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

        if orientation.dirty or screenLengthDirty or parentOrientationDirty or hasNonFitChildOrientationDirty(node) then
            node.rect.modelDirty = true
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
            if math.type(orientation.minOffset) == "integer" then
                minInEffectiveParentNDC = minInEffectiveParentNDC + orientation.minOffset / screenLength * 2
                maxInEffectiveParentNDC = maxInEffectiveParentNDC + orientation.maxOffset / screenLength * 2
            else
                minInEffectiveParentNDC = minInEffectiveParentNDC + orientation.minOffset
                maxInEffectiveParentNDC = maxInEffectiveParentNDC + orientation.maxOffset
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
            local pivot = orientation.pivot
            local rectMin = -lengthNDC * pivot
            local rectMax = lengthNDC * (1 - pivot)

            if node.rect[key].min ~= rectMin or node.rect[key].max ~= rectMax then
                node.rect[key].min = rectMin
                node.rect[key].max = rectMax
                node.rect.boundsDirty = true
            end
            -- Offset is the center of children bounds adjusted for pivot difference
            local offsetToEffectiveParentNDC = tknMath.lerp(minInEffectiveParentNDC, maxInEffectiveParentNDC, pivot)
            if math.type(orientation.offset) == "integer" then
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientation.offset / screenLength * 2
            else
                offsetToEffectiveParentNDC = offsetToEffectiveParentNDC + orientation.offset
            end

            node.rect.offsetToEffectiveParentNDC[key] = offsetToEffectiveParentNDC
        end
    end
    node[key].dirty = false
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

local function updateGraphicsRecursive(pTknGfxContext, ui, node, screenWidth, screenHeight, parentModelDirty, parentColorDirty, parentColor, parentActiveDirty, parentActive, parentMaskDirty, parentMaskBit)
    local rect = node.rect
    local instanceDirty = false
    print("Updating model for node " .. tostring(node.name) .. tostring(node.transform.modelDirty or node.rect.modelDirty or parentModelDirty))
    if node.transform.modelDirty or node.rect.modelDirty or parentModelDirty then
        parentModelDirty = node.rect.modelDirty or parentModelDirty
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
                instanceDirty = true
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
                instanceDirty = true
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
        node.rect.modelDirty = false
        node.transform.modelDirty = false
    end

    if node.transform.colorDirty or node.colorDirty or parentColorDirty then
        parentColorDirty = node.transform.colorDirty or parentColorDirty

        local newColor = tknMath.multiplyColors(parentColor, node.transform.color or colorPreset.white)
        if rect.color ~= newColor then
            instanceDirty = true
            rect.color = newColor
        end
        node.transform.colorDirty = false
        node.colorDirty = false
    end

    local screenSizeDirty = screenWidth ~= ui.screenWidth or screenHeight ~= ui.screenHeight
    if rect.boundsDirty or screenSizeDirty then
        -- Update mesh if bounds changed
        if node.type == "imageNode" then
            imageNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, rect.boundsDirty, screenSizeDirty)
        elseif node.type == "textNode" then
            textNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, rect.boundsDirty, screenSizeDirty)
        end
    end
    rect.boundsDirty = false

    -- Update instance if model or color changed
    if node.pTknInstance and instanceDirty then
        local instances = {
            model = rect.model,
            color = {tkn.rgbaToAbgr(tknMath.multiplyColors(rect.color, node.color))},
            alphaThreshold = node.alphaThreshold,
        }
        tkn.tknUpdateInstancePtr(pTknGfxContext, node.pTknInstance, ui.instanceFormat, instances)
    end

    if node.transform.activeDirty or parentActiveDirty then
        parentActiveDirty = node.transform.activeDirty or parentActiveDirty
        local finalActive = parentActive and node.transform.active
        node.rect.active = finalActive
        node.transform.activeDirty = false
    end

    -- Recursively update children
    for _, child in ipairs(node.children) do
        updateGraphicsRecursive(pTknGfxContext, ui, child, screenWidth, screenHeight, parentModelDirty, parentColorDirty, rect.color, parentActiveDirty, node.rect.active, parentMaskDirty, parentMaskBit)
    end

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

local function getActiveInteractableInputNode(node, xNDC, yNDC, inputState)
    if node.rect.active then
        for i = #node.children, 1, -1 do
            local child = node.children[i]
            local foundNode = getActiveInteractableInputNode(child, xNDC, yNDC, inputState)
            if foundNode then
                return foundNode
            end
        end
        if node and node.type == "interactableNode" and ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            return node
        else
            return nil
        end
    else
        -- Skip inactive nodes
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
    local parent = node.parent
    while parent do
        if parent[orientation].type == ui.layoutType.fit then
            parent[orientation].dirty = true
            parent = parent.parent
        else
            break
        end
    end
end

function ui.setNodeOrienation(node, orientationKey, orientation)
    if orientation.type == ui.layoutType.anchored then
        node[orientationKey].type = ui.layoutType.anchored
        node[orientationKey].anchor = orientation.anchor
        node[orientationKey].pivot = orientation.pivot
        node[orientationKey].length = orientation.length
        node[orientationKey].offset = orientation.offset
    elseif orientation.type == ui.layoutType.fit then
        node[orientationKey].type = ui.layoutType.fit
        node[orientationKey].pivot = orientation.pivot
        node[orientationKey].minOffset = orientation.minOffset
        node[orientationKey].maxOffset = orientation.maxOffset
        node[orientationKey].offset = orientation.offset
    elseif orientation.type == ui.layoutType.relative then
        node[orientationKey].type = ui.layoutType.relative
        node[orientationKey].pivot = orientation.pivot
        node[orientationKey].minOffset = orientation.minOffset
        node[orientationKey].maxOffset = orientation.maxOffset
        node[orientationKey].offset = orientation.offset
    else
        error("ui.copyOrientation: unknown layout type " .. tostring(orientation.type))
    end
    node[orientationKey].dirty = true
end

function ui.setNodeTransformModel(node, rotation, horizontalScale, verticalScale)
    node.transform.modelDirty = node.transform.rotation ~= rotation or node.transform.horizontalScale ~= horizontalScale or node.transform.verticalScale ~= verticalScale
    node.transform.rotation = rotation
    node.transform.horizontalScale = horizontalScale
    node.transform.verticalScale = verticalScale
end

function ui.setNodeTransformColor(node, color)
    node.transform.colorDirty = node.transform.color ~= color
    node.transform.color = color
end

function ui.setNodeTransformActive(node, active)
    node.transform.activeDirty = node.transform.active ~= active
    node.transform.active = active
end

local function addNodeInternal(pTknGfxContext, parent, index, name, horizontal, vertical, transform)
    local node = {
        name = name,
        children = {},
        parent = parent,
        horizontal = {},
        vertical = {},
        transform = {},
    }
    ui.setNodeOrienation(node, "horizontal", horizontal)
    ui.setNodeOrienation(node, "vertical", vertical)
    ui.setNodeTransformModel(node, transform.rotation, transform.horizontalScale, transform.verticalScale)
    ui.setNodeTransformColor(node, transform.color)
    ui.setNodeTransformActive(node, transform.active)

    if parent == nil then
        assert(ui.rootNode == nil, "ui.addNode: rootNode is not nil")
        ui.rootNode = node
        ui.topNode = node
    else
        assert(index >= 1 and index <= #parent.children + 1, "ui.addNode: index out of bounds")
        table.insert(parent.children, index, node)
        markParentFitNodeDirty(node, "horizontal")
        markParentFitNodeDirty(node, "vertical")
        if isTopNode(node) then
            ui.topNode = node
        end
    end

    return node
end

local function removeNodeInternal(pTknGfxContext, node)
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

    node.name = nil
    node.children = nil
    node.parent = nil
    node.horizontal = nil
    node.vertical = nil
    node.transform = nil
end

function ui.setup(pTknGfxContext, pSwapchainAttachment, assetsPath, renderPassIndex)
    ui.layoutType = {
        anchored = "anchored",
        relative = "relative",
        fit = "fit",
    }
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
    }, {
        name = "alphaThreshold",
        type = tkn.type.float,
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
        color = colorPreset.white,
        active = true,
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
    ui.layoutType = nil
end

function ui.update(pTknGfxContext, screenWidth, screenHeight)
    updateOrientationRecursive(pTknGfxContext, ui, ui.rootNode, "horizontal", nil, screenWidth, ui.screenWidth ~= screenWidth, false)
    updateOrientationRecursive(pTknGfxContext, ui, ui.rootNode, "vertical", nil, screenHeight, ui.screenHeight ~= screenHeight, false)
    updateGraphicsRecursive(pTknGfxContext, ui, ui.rootNode, screenWidth, screenHeight, false, false, colorPreset.white, false, true, false, 0x0, 0)
    ui.screenWidth = screenWidth
    ui.screenHeight = screenHeight
    textNode.update(pTknGfxContext)

    if ui.currentInteractableNode then
        local canInteract = ui.currentInteractableNode.processInputFunction(ui.currentInteractableNode, input.mousePositionNDC.x, input.mousePositionNDC.y, input.getMouseState(input.mouseCode.left))
        if canInteract then
            -- Keep current interactable node
        else
            ui.currentInteractableNode = nil
        end
    else
        if input.getMouseState(input.mouseCode.left) == input.inputState.down then
            ui.currentInteractableNode = getActiveInteractableInputNode(ui.rootNode, input.mousePositionNDC.x, input.mousePositionNDC.y, input.getMouseState(input.mouseCode.left))
        end
    end
end

function ui.recordDrawCalls(node, pTknGfxContext, pTknFrame)
    if node.pTknDrawCall and node.rect.active then
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, node.pTknDrawCall)
    end

    for _, child in ipairs(node.children) do
        ui.recordDrawCalls(child, pTknGfxContext, pTknFrame)
    end
end

function ui.recordFrame(pTknGfxContext, pTknFrame)
    tkn.tknBeginRenderPassPtr(pTknGfxContext, pTknFrame, ui.renderPass.pTknRenderPass)
    ui.recordDrawCalls(ui.rootNode, pTknGfxContext, pTknFrame)
    tkn.tknEndRenderPassPtr(pTknGfxContext, pTknFrame)
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

    markParentFitNodeDirty(node, "horizontal")
    markParentFitNodeDirty(node, "vertical")

    local originalIndex = ui.getNodeIndex(node)
    table.remove(node.parent.children, originalIndex)
    table.insert(parent.children, index, node)
    node.parent = parent

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

function ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, color, alphaThreshold, fitMode, image, uv, mask)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, horizontal, vertical, transform);
    imageNode.setupNode(pTknGfxContext, color, alphaThreshold, fitMode, image, uv, ui.vertexFormat, ui.instanceFormat, ui.renderPass.pImagePipeline, mask, node)
    return node
end

function ui.setImageOrTextNodeColor(node, color)
    assert(node.type == "imageNode" or node.type == "textNode", "ui.setImageOrTextNodeColor: node is not an imageNode or textNode")
    node.color = color
    node.colorDirty = true
end

function ui.addTextNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, textString, font, size, color, alphaThreshold, alignH, alignV, bold)
    local node = ui.addNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform);
    textNode.setupNode(pTknGfxContext, textString, font, size, color, alphaThreshold, alignH or 0, alignV or 0, bold, font.pTknMaterial, ui.vertexFormat, ui.instanceFormat, ui.renderPass.pTextPipeline, node)
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
