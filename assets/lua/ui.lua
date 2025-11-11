-- UI
-- For Node's Layout, if we choose to update on real-time add/delete/modify operations, there might be cases where children are updated before parents, leading to redundant calculations. Therefore, we adopt a unified update approach during the update phase.
-- The creation, deletion, and modification of drawcalls and meshes depend on the add/delete/modify operations of nodes and components.
-- Updating mesh requires layout update first, so it always happens after the update layout phase.
local tkn = require("tkn")
local image = require("image")
local text = require("text")
local uiRenderPass = require("uiRenderPass")
local ui = {}

-- 3x3 matrix multiplication (a * b) - COLUMN-MAJOR format for GLSL
-- Matrices are stored as: [col0_x, col0_y, col0_z, col1_x, col1_y, col1_z, col2_x, col2_y, col2_z]
-- If result is provided, writes to it and returns it; otherwise creates new table
local function multiplyMat3(a, b, result)
    local r = result or {}
    -- Column 0 of result
    r[1] = a[1] * b[1] + a[4] * b[2] + a[7] * b[3]
    r[2] = a[2] * b[1] + a[5] * b[2] + a[8] * b[3]
    r[3] = a[3] * b[1] + a[6] * b[2] + a[9] * b[3]
    -- Column 1 of result
    r[4] = a[1] * b[4] + a[4] * b[5] + a[7] * b[6]
    r[5] = a[2] * b[4] + a[5] * b[5] + a[8] * b[6]
    r[6] = a[3] * b[4] + a[6] * b[5] + a[9] * b[6]
    -- Column 2 of result
    r[7] = a[1] * b[7] + a[4] * b[8] + a[7] * b[9]
    r[8] = a[2] * b[7] + a[5] * b[8] + a[8] * b[9]
    r[9] = a[3] * b[7] + a[6] * b[8] + a[9] * b[9]
    return r
end

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
local function updateRect(pGfxContext, screenWidth, screenHeight, node, parentDirty, parentModel, parentWidth, parentHeight)
    if node.layout.dirty or parentDirty then
        -- Use parent dimensions or fullscreen as default (NDC: -1 to 1 = size 2)
        local pWidth = parentWidth or 2
        local pHeight = parentHeight or 2

        local layout = node.layout
        local width, height

        -- Handle horizontal layout
        if layout.horizontal.type == "anchored" then
            local anchor = layout.horizontal.anchor
            local pivot = layout.horizontal.pivot
            local w = layout.horizontal.width
            local widthNDC = w / screenWidth * 2
            -- Calculate position relative to parent's origin
            local x = pWidth * (anchor - pivot)
            width = widthNDC
        elseif layout.horizontal.type == "relative" then
            local leftOffset, rightOffset
            if math.type(layout.horizontal.left) == "integer" then
                leftOffset = layout.horizontal.left / screenWidth * 2
            else
                leftOffset = pWidth * layout.horizontal.left
            end
            if math.type(layout.horizontal.right) == "integer" then
                rightOffset = layout.horizontal.right / screenWidth * 2
            else
                rightOffset = pWidth * layout.horizontal.right
            end
            local w = pWidth - leftOffset - rightOffset
            if w < 0 then
                w = 0
            end
            width = w
        else
            error("ui.calculateRect: unknown horizontal layout type " .. tostring(layout.horizontal.type))
        end

        -- Handle vertical layout
        if layout.vertical.type == "anchored" then
            local anchor = layout.vertical.anchor
            local pivot = layout.vertical.pivot
            local h = layout.vertical.height
            local heightNDC = h / screenHeight * 2
            -- Calculate position relative to parent's origin
            local y = pHeight * (anchor - pivot)
            height = heightNDC
        elseif layout.vertical.type == "relative" then
            local topOffset, bottomOffset
            if math.type(layout.vertical.top) == "integer" then
                topOffset = layout.vertical.top / screenHeight * 2
            else
                topOffset = pHeight * layout.vertical.top
            end
            if math.type(layout.vertical.bottom) == "integer" then
                bottomOffset = layout.vertical.bottom / screenHeight * 2
            else
                bottomOffset = pHeight * layout.vertical.bottom
            end
            local h = pHeight - topOffset - bottomOffset
            if h < 0 then
                h = 0
            end
            height = h
        else
            error("ui.calculateRect: unknown vertical layout type " .. tostring(layout.vertical.type))
        end

        -- Build local transform matrix (pivot-centered)
        -- Calculate offset from parent's pivot to child's pivot
        local offsetX, offsetY
        if layout.horizontal.type == "anchored" then
            -- anchored: position based on anchor point within parent
            -- offset = (parent.width * anchor) - (parent.width * parent.pivot) + (child.width * (child.pivot - 0.5))
            offsetX = pWidth * (layout.horizontal.anchor - 0.5) + width * (0.5 - layout.horizontal.pivot)
        else -- relative
            local leftOffset
            if math.type(layout.horizontal.left) == "integer" then
                leftOffset = layout.horizontal.left / screenWidth * 2
            else
                leftOffset = pWidth * layout.horizontal.left
            end
            offsetX = -pWidth * 0.5 + leftOffset + width * layout.horizontal.pivot
        end

        if layout.vertical.type == "anchored" then
            offsetY = pHeight * (layout.vertical.anchor - 0.5) + height * (0.5 - layout.vertical.pivot)
        else -- relative
            local topOffset
            if math.type(layout.vertical.top) == "integer" then
                topOffset = layout.vertical.top / screenHeight * 2
            else
                topOffset = pHeight * layout.vertical.top
            end
            offsetY = -pHeight * 0.5 + topOffset + height * layout.vertical.pivot
        end

        -- Local transform matrix: translates pivot(0,0) relative to parent's pivot
        -- GLSL mat3 is column-major: columns are stored sequentially
        -- Translation is in the 3rd column (indices 7, 8)
        local localModel = {1, 0, 0, -- column 0: x-axis
        0, 1, 0, -- column 1: y-axis
        offsetX, offsetY, 1 -- column 2: translation
        }

        -- Calculate final model by multiplying with parent model
        -- Reuse existing model table if available
        local finalModel = node.layout.model or {}
        if parentModel then
            multiplyMat3(parentModel, localModel, finalModel)
        else
            -- Copy localModel to finalModel
            for i = 1, 9 do
                finalModel[i] = localModel[i]
            end
        end

        -- Store model
        node.layout.model = finalModel
        node.layout.width = width
        node.layout.height = height

        -- Update mesh (which will also update instance buffer internally)
        if node.component and node.component.pMesh then
            if node.component.type == "image" then
                image.updateMeshPtr(pGfxContext, node.component, node.layout, ui.vertexFormat, ui.instanceFormat)
            elseif node.component.type == "text" then
                text.updateMeshPtr(pGfxContext, node.component, node.layout, ui.vertexFormat, ui.instanceFormat, screenWidth, screenHeight)
            else
                error("ui.updateRect: unsupported component type " .. tostring(node.component.type))
            end
        end

        node.layout.dirty = false
        for i, child in ipairs(node.children) do
            updateRect(pGfxContext, screenWidth, screenHeight, child, true, finalModel, width, height)
        end
    else
        for i, child in ipairs(node.children) do
            updateRect(pGfxContext, screenWidth, screenHeight, child, false, node.layout.model, node.layout.width, node.layout.height)
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
            },
            vertical = {
                type = "relative",
                pivot = 0.5,
                bottom = 0,
                top = 0,
            },
            width = 0,
            height = 0,
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
    if ui.width ~= screenWidth or ui.height ~= screenHeight then
        ui.width = screenWidth
        ui.height = screenHeight
        ui.rootNode.layout.dirty = true
    end
    updateRect(pGfxContext, screenWidth, screenHeight, ui.rootNode, false, nil, 2, 2)
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
    else
        node = {
            name = name,
            children = {},
            parent = parent,
            component = nil,
            layout = layout,
        }
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
