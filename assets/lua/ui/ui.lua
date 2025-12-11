-- UI
-- For Node's Layout, if we choose to update on real-time add/delete/modify operations, there might be cases where children are updated before parents, leading to redundant calculations. Therefore, we adopt a unified update approach during the update phase.
-- The creation, deletion, and modification of drawcalls and meshes depend on the add/delete/modify operations of nodes and components.
-- Updating mesh requires layout update first, so it always happens after the update layout phase.
local ui = {}
local tknMath = require("tknMath")
local tkn = require("tkn")
local image = require("ui.image")
local text = require("ui.text")
local uiRenderPass = require("ui.uiRenderPass")

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

local function updateOrientationRecursive(pGfxContext, ui, node, key, effectiveParent, screenLength, screenLengthChanged, parentOrientationChanged)
    local layout = node.layout
    local orientation = layout[key]
    if (orientation.dirty or screenLengthChanged or parentOrientationChanged) and orientation.type ~= "fit" then
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
        if orientation.type == "anchored" then
            lengthNDC = orientation.length / screenLength * 2
            offsetNDC = (orientation.anchor - effectiveParentPivot) * parentLengthNDC
        elseif orientation.type == "relative" then
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
        updateOrientationRecursive(pGfxContext, ui, child, key, effectiveParent, screenLength, screenLengthChanged, parentOrientationChanged)
    end

    if (orientation.dirty or screenLengthChanged or parentOrientationChanged) and orientation.type == "fit" then
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
    while effectiveParent and effectiveParent.layout[key].type == "fit" do
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

-- Recursively updates the graphics (model matrix, mesh, instance) based on rect and parent transform
local function updateGraphicsRecursive(pGfxContext, ui, node, screenSizeChanged)
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
    while scaleRotParent and (scaleRotParent.layout.horizontal.type == "fit" and scaleRotParent.layout.vertical.type == "fit") do
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

    -- Update color from component
    local oldColor = rect.color
    if node.component then
        rect.color = node.component.color
    end
    local colorChanged = oldColor ~= rect.color

    -- Update mesh if bounds changed
    if node.component and node.component.pMesh then
        if node.component.type == "image" and boundsChanged then
            image.updateMeshPtr(pGfxContext, node.component, rect, ui.vertexFormat)
        elseif node.component.type == "text" and (boundsChanged or screenSizeChanged) then
            text.updateMeshPtr(pGfxContext, node.component, rect, ui.vertexFormat, ui.screenWidth, ui.screenHeight)
        end
    end

    -- Update instance if model or color changed
    if node.component and node.component.pInstance and (modelChanged or colorChanged) then
        local instances = {
            model = rect.model,
            color = {node.component.color},
        }
        tkn.updateInstancePtr(pGfxContext, node.component.pInstance, ui.instanceFormat, instances)
    end

    -- Recursively update children
    for _, child in ipairs(node.children) do
        updateGraphicsRecursive(pGfxContext, ui, child, screenSizeChanged)
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
                minOffset = 0,
                maxOffset = 0,
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = "relative",
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
    updateOrientationRecursive(pGfxContext, ui, ui.rootNode, "horizontal", nil, screenWidth, ui.screenWidth ~= screenWidth, false)
    updateOrientationRecursive(pGfxContext, ui, ui.rootNode, "vertical", nil, screenHeight, ui.screenHeight ~= screenHeight, false)
    updateGraphicsRecursive(pGfxContext, ui, ui.rootNode, ui.screenWidth ~= screenWidth or ui.screenHeight ~= screenHeight)
    ui.screenWidth = screenWidth
    ui.screenHeight = screenHeight
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
            }
        end
    end
    table.insert(parent.children, index, node)

    -- Mark fit ancestors as dirty since their bounds depend on children
    local ancestor = parent
    while ancestor do
        if ancestor.layout.horizontal.type == "fit" then
            ancestor.layout.horizontal.dirty = true
        end
        if ancestor.layout.vertical.type == "fit" then
            ancestor.layout.vertical.dirty = true
        end
        ancestor = ancestor.parent
    end

    return node
end
function ui.removeNode(pGfxContext, node)
    print("Removing node: " .. node.name)

    -- Mark fit ancestors as dirty before removing (their bounds will change)
    local ancestor = node.parent
    while ancestor do
        if ancestor.layout.horizontal.type == "fit" then
            ancestor.layout.horizontal.dirty = true
        end
        if ancestor.layout.vertical.type == "fit" then
            ancestor.layout.vertical.dirty = true
        end
        ancestor = ancestor.parent
    end

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
    for i, material in ipairs(ui.materials) do
        if material == pMaterial then
            table.remove(ui.materials, i)
            break
        end
    end
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
