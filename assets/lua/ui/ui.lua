local ui = {}
local tknMath = require("tknMath")
local tkn = require("tkn")
local imageNode = require("ui.imageNode")
local textNode = require("ui.textNode")
local interactableNode = require("ui.interactableNode")
local uiRenderPass = require("ui.uiRenderPass")
local input = require("input")
local colorPreset = require("ui.colorPreset")

local function calculateOrientation(node, key, screenLength)
    local orientation = node[key]
    local parentLengthNdc = node.parent and (node.parent.rect[key].max - node.parent.rect[key].min) or 2
    local lengthNdc, offsetToParentNdc
    local parentPivot = node.parent and node.parent[key].pivot or 0.5
    -- Calculate length and offset based on layout type
    if orientation.type == ui.layoutType.anchored then
        if math.type(orientation.length) == "integer" then
            lengthNdc = orientation.length / screenLength * 2
        else
            lengthNdc = orientation.length
        end
        offsetToParentNdc = (orientation.anchor - parentPivot) * parentLengthNdc
    elseif orientation.type == ui.layoutType.relative then
        local minOffsetToParentNdc, maxOffsetToParentNdc
        if math.type(orientation.minOffset) == "integer" then
            minOffsetToParentNdc = orientation.minOffset / screenLength * 2
        else
            minOffsetToParentNdc = parentLengthNdc * orientation.minOffset
        end
        if math.type(orientation.maxOffset) == "integer" then
            maxOffsetToParentNdc = orientation.maxOffset / screenLength * 2
        else
            maxOffsetToParentNdc = parentLengthNdc * orientation.maxOffset
        end
        lengthNdc = parentLengthNdc - minOffsetToParentNdc + maxOffsetToParentNdc
        lengthNdc = lengthNdc < 0 and 0 or lengthNdc
        local anchorToParent = (minOffsetToParentNdc + lengthNdc * orientation.pivot) / parentLengthNdc
        offsetToParentNdc = (anchorToParent - parentPivot) * parentLengthNdc
    else
        error("Unknown orientation type " .. tostring(orientation.type))
    end

    -- Apply additional offset
    if math.type(orientation.offset) == "integer" then
        offsetToParentNdc = offsetToParentNdc + orientation.offset / screenLength * 2
    else
        offsetToParentNdc = offsetToParentNdc + orientation.offset
    end

    local rectMin = -lengthNdc * orientation.pivot
    local rectMax = lengthNdc * (1 - orientation.pivot)
    orientation.dirty = false
    return rectMin, rectMax, offsetToParentNdc
end

local function updateNodeGfxRecursive(pTknGfxContext, ui, node, screenWidth, screenHeight, screenWidthDirty, screenHeightDirty, parentHorizontalDirty, parentVerticalDirty, parentModelDirty, parentColorDirty, parentActiveDirty)
    if node.rect == nil then
        node.rect = {
            horizontal = {
                min = nil,
                max = nil,
                offset = nil,
            },
            vertical = {
                min = nil,
                max = nil,
                offset = nil,
            },
            model = {nil, nil, nil, nil, nil, nil, nil, nil, nil},
            color = nil,
            active = false,
        }
    end
    local rect = node.rect

    local modelDirty = false
    local meshDirty = false

    if node.horizontal.dirty or screenWidthDirty or parentHorizontalDirty then
        local rectHorizontalMin, rectHorizontalMax, offsetToParentX = calculateOrientation(node, "horizontal", screenWidth)
        if rect.horizontal.min ~= rectHorizontalMin or rect.horizontal.max ~= rectHorizontalMax then
            rect.horizontal.min = rectHorizontalMin
            rect.horizontal.max = rectHorizontalMax
            meshDirty = true
            parentHorizontalDirty = true
        else
            -- parentHorizontalDirty = false
        end
        if rect.horizontal.offset ~= offsetToParentX then
            rect.horizontal.offset = offsetToParentX
            modelDirty = true
            parentHorizontalDirty = true
        end
    else
        -- parentHorizontalDirty = false
    end

    if node.vertical.dirty or screenHeightDirty or parentVerticalDirty then
        local rectVerticalMin, rectVerticalMax, offsetToParentY = calculateOrientation(node, "vertical", screenHeight)
        if rect.vertical.min ~= rectVerticalMin or rect.vertical.max ~= rectVerticalMax then
            rect.vertical.min = rectVerticalMin
            rect.vertical.max = rectVerticalMax
            meshDirty = true
            parentVerticalDirty = true
        else
            -- parentVerticalDirty = false
        end
        if rect.vertical.offset ~= offsetToParentY then
            rect.vertical.offset = offsetToParentY
            modelDirty = true
            parentVerticalDirty = true
        end
    else
        -- parentVerticalDirty = false
    end

    local instanceDirty = false
    modelDirty = modelDirty or node.transform.modelDirty
    if parentModelDirty or modelDirty then
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
        local offsetToParentX = rect.horizontal.offset
        local offsetToParentY = rect.vertical.offset
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
        node.transform.modelDirty = false
        parentModelDirty = true
    else
        parentModelDirty = false
    end

    if node.transform.colorDirty or parentColorDirty or rect.color == nil then
        local parentRectColor = node.parent and node.parent.rect.color or colorPreset.white
        local rectColor = tknMath.multiplyColors(parentRectColor, node.transform.color or colorPreset.white)
        if rect.color ~= rectColor then
            instanceDirty = true
            rect.color = rectColor
        end
        node.transform.colorDirty = false
        parentColorDirty = true
    end

    if node.colorDirty then
        instanceDirty = true
        node.colorDirty = false
    end

    local screenSizeDirty = screenWidth ~= ui.screenWidth or screenHeight ~= ui.screenHeight
    if meshDirty or screenSizeDirty then
        -- Update mesh if bounds changed
        if node.type == "imageNode" then
            imageNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, meshDirty, screenSizeDirty)
        elseif node.type == "textNode" then
            textNode.updateMeshPtr(pTknGfxContext, node, ui.vertexFormat, screenWidth, screenHeight, meshDirty, screenSizeDirty)
        end
    end

    -- TODO Mark dirty for alphaThreshold and node's color
    if node.alphaThresholdDirty then
        instanceDirty = true
        node.alphaThresholdDirty = false
    end

    if node.pTknInstance and instanceDirty then
        local instances = {
            model = rect.model,
            color = {tkn.rgbaToAbgr(tknMath.multiplyColors(rect.color, node.color))},
            alphaThreshold = node.alphaThreshold,
        }
        tkn.tknUpdateInstancePtr(pTknGfxContext, node.pTknInstance, ui.instanceFormat, instances)
    end

    if node.transform.activeDirty or parentActiveDirty then
        local parentRectActive = node.parent and node.parent.rect.active or true
        node.rect.active = parentRectActive and node.transform.active
        node.transform.activeDirty = false
        parentActiveDirty = true
    end

    for i = 1, #node.children do
        local child = node.children[i]
        updateNodeGfxRecursive(pTknGfxContext, ui, child, screenWidth, screenHeight, screenWidthDirty, screenHeightDirty, parentHorizontalDirty, parentVerticalDirty, parentModelDirty, parentColorDirty, parentActiveDirty)
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

local function getActiveInteractableInputNode(node, xNdc, yNdc, inputState)
    if node.rect.active then
        for i = #node.children, 1, -1 do
            local child = node.children[i]
            local foundNode = getActiveInteractableInputNode(child, xNdc, yNdc, inputState)
            if foundNode then
                return foundNode
            end
        end
        if node and node.type == "interactableNode" and ui.rectContainsPoint(node.rect, xNdc, yNdc) then
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

function ui.setNodeOrienation(node, orientationKey, orientation)
    if orientation.type == ui.layoutType.anchored then
        node[orientationKey].type = ui.layoutType.anchored
        node[orientationKey].anchor = orientation.anchor
        node[orientationKey].pivot = orientation.pivot
        node[orientationKey].length = orientation.length
        node[orientationKey].offset = orientation.offset
    elseif orientation.type == ui.layoutType.relative then
        node[orientationKey].type = ui.layoutType.relative
        node[orientationKey].pivot = orientation.pivot
        node[orientationKey].minOffset = orientation.minOffset
        node[orientationKey].maxOffset = orientation.maxOffset
        node[orientationKey].offset = orientation.offset
    else
        error("ui.setNodeOrienation: unknown layout type " .. tostring(orientation.type))
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
        if isTopNode(node) then
            ui.topNode = node
        end
    end

    return node
end

local function removeNodeInternal(pTknGfxContext, node)
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

    node.name = nil
    node.children = nil
    node.parent = nil
    node.horizontal = nil
    node.vertical = nil
    node.transform = nil
end

function ui.setup(pTknGfxContext, pSwapchainAttachment, pDepthStencilAttachment, assetsPath, renderPassIndex)
    ui.layoutType = {
        anchored = "anchored",
        relative = "relative",
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

    uiRenderPass.setup(pTknGfxContext, pSwapchainAttachment, pDepthStencilAttachment, assetsPath, ui.vertexFormat.pTknVertexInputLayout, ui.instanceFormat.pTknVertexInputLayout, renderPassIndex)

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
    updateNodeGfxRecursive(pTknGfxContext, ui, ui.rootNode, screenWidth, screenHeight, ui.screenWidth ~= screenWidth, ui.screenHeight ~= screenHeight, false, false, false, false, false)
    ui.screenWidth = screenWidth
    ui.screenHeight = screenHeight
    textNode.update(pTknGfxContext)

    if ui.currentInteractableNode then
        local canInteract = ui.currentInteractableNode.processInput(ui.currentInteractableNode, input.mousePositionNDC.x, input.mousePositionNDC.y, input.getMouseState(input.mouseCode.left))
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

function ui.recordDrawCalls(node, pTknGfxContext, pTknFrame, maskIndex)
    if node.pTknDrawCall then
        if node.rect.active then
            if node.mask then
                -- Mask-creating node: enable stencil write, create new mask layer
                tkn.tknSetStencilWriteMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0xFF)
                maskIndex = maskIndex + 1
                assert(maskIndex <= 7, "ui.recordDrawCalls: exceeded maximum mask count of 7")
                local maskBit = (1 << maskIndex) - 1
                local compareMask = maskBit - 1
                if compareMask < 0 then
                    compareMask = 0
                end
                tkn.tknSetStencilCompareMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, compareMask)
                tkn.tknSetStencilReference(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, maskBit)
                tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, node.pTknDrawCall)
                -- Disable stencil write for children (they read, not write)
                tkn.tknSetStencilWriteMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0x00)
            elseif maskIndex > 0 then
                -- Masked node: read from current mask, don't write
                local maskBit = (1 << maskIndex) - 1
                tkn.tknSetStencilCompareMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0xFF)
                tkn.tknSetStencilReference(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, maskBit)
                tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, node.pTknDrawCall)
            else
                -- Unmasked root node: render normally, can write if needed
                tkn.tknSetStencilWriteMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0x00)
                tkn.tknSetStencilCompareMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0xFF)
                tkn.tknSetStencilReference(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0x00)
                tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, node.pTknDrawCall)
            end
        end
    end

    for _, child in ipairs(node.children) do
        ui.recordDrawCalls(child, pTknGfxContext, pTknFrame, maskIndex)
    end

    -- Cleanup: restore stencil state after processing children
    if node.pTknDrawCall and node.rect.active and node.mask then
        -- Exiting a mask-creating node: restore write mask state
        -- If parent exists and is masked, keep write disabled; otherwise enable
        if maskIndex > 1 then
            -- Still inside a parent mask, keep write disabled
            tkn.tknSetStencilWriteMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0x00)
        else
            -- Exiting root mask layer, restore to write-enabled
            tkn.tknSetStencilWriteMask(pTknGfxContext, pTknFrame, VK_STENCIL_FACE_FRONT_AND_BACK, 0xFF)
        end
    end
end

function ui.recordFrame(pTknGfxContext, pTknFrame)
    tkn.tknBeginRenderPassPtr(pTknGfxContext, pTknFrame, ui.renderPass.pTknRenderPass)
    ui.recordDrawCalls(ui.rootNode, pTknGfxContext, pTknFrame, 0)
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

    local originalIndex = ui.getNodeIndex(node)
    table.remove(node.parent.children, originalIndex)
    table.insert(parent.children, index, node)
    node.parent = parent

    node.horizontal.dirty = true
    node.vertical.dirty = true
    node.transform.modelDirty = true
    node.transform.colorDirty = true

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

function ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, transform)
    local node = addNodeInternal(pTknGfxContext, parent, index, name, horizontal, vertical, transform);
    interactableNode.setupNode(pTknGfxContext, processInput, node)
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

function ui.rectContainsPoint(rect, xNdc, yNdc)
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
    return xNdc >= minX and xNdc <= maxX and yNdc >= minY and yNdc <= maxY
end

return ui
