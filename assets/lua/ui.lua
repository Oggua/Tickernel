-- UI
-- For Node's Layout, if we choose to update on real-time add/delete/modify operations, there might be cases where children are updated before parents, leading to redundant calculations. Therefore, we adopt a unified update approach during the update phase.
-- The creation, deletion, and modification of drawcalls and meshes depend on the add/delete/modify operations of nodes and components.
-- Updating mesh requires layout update first, so it always happens after the update layout phase.
local tkn = require("tkn")
local image = require("image")
local text = require("text")
local uiRenderPass = require("uiRenderPass")
local ui = {}

local fullScreenRect = {
    left = -1,
    right = 1,
    top = -1, -- Vulkan NDC: Y=-1 is top
    bottom = 1, -- Vulkan NDC: Y=1 is bottom
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
local function updateRect(pGfxContext, screenWidth, screenHeight, node, parentDirty)
    if node.layout.dirty or parentDirty then
        local parentRect = node == ui.rootNode and fullScreenRect or node.parent.layout.rect
        local layout = node.layout
        -- Handle horizontal layout
        if layout.horizontal.type == "anchored" then
            local anchor = layout.horizontal.anchor
            local pivot = layout.horizontal.pivot
            local width = layout.horizontal.width
            local widthNDC = width / screenWidth * 2
            local x = parentRect.left + (parentRect.right - parentRect.left) * anchor - widthNDC * pivot
            node.layout.rect.left = x
            node.layout.rect.right = x + widthNDC
        elseif layout.horizontal.type == "relative" then
            local left, right
            if math.type(layout.horizontal.left) == "integer" then
                left = parentRect.left + layout.horizontal.left / screenWidth * 2
            else
                left = parentRect.left + (parentRect.right - parentRect.left) * layout.horizontal.left
            end
            if math.type(layout.horizontal.right) == "integer" then
                right = parentRect.right - layout.horizontal.right / screenWidth * 2
            else
                right = parentRect.right - (parentRect.right - parentRect.left) * layout.horizontal.right
            end
            -- Ensure left doesn't exceed right
            if left > right then
                local center = (left + right) * 0.5
                left = center
                right = center
            end
            node.layout.rect.left = left
            node.layout.rect.right = right
        else
            error("ui.calculateRect: unknown horizontal layout type " .. tostring(layout.horizontal.type))
        end
        -- Handle vertical layout (assuming similar structure)
        if layout.vertical.type == "anchored" then
            local anchor = layout.vertical.anchor
            local pivot = layout.vertical.pivot
            local height = layout.vertical.height
            local heightNDC = height / screenHeight * 2
            local y = parentRect.top + (parentRect.bottom - parentRect.top) * anchor - heightNDC * pivot
            node.layout.rect.top = y
            node.layout.rect.bottom = y + heightNDC
        elseif layout.vertical.type == "relative" then
            local bottom, top
            if math.type(layout.vertical.top) == "integer" then
                top = parentRect.top + layout.vertical.top / screenHeight * 2
            else
                top = parentRect.top + (parentRect.bottom - parentRect.top) * layout.vertical.top
            end
            if math.type(layout.vertical.bottom) == "integer" then
                bottom = parentRect.bottom - layout.vertical.bottom / screenHeight * 2
            else
                bottom = parentRect.bottom - (parentRect.bottom - parentRect.top) * layout.vertical.bottom
            end
            if top > bottom then
                local center = (top + bottom) * 0.5
                top = center
                bottom = center
            end
            node.layout.rect.top = top
            node.layout.rect.bottom = bottom
        else
            error("ui.calculateRect: unknown vertical layout type " .. tostring(layout.vertical.type))
        end

        -- Update mesh
        if node.component and node.component.pMesh then
            if node.component.type == "image" then
                image.updateMeshPtr(pGfxContext, node.component, node.layout.rect, ui.vertexFormat)
            elseif node.component.type == "text" then
                text.updateMeshPtr(pGfxContext, node.component, node.layout.rect, ui.vertexFormat, screenWidth, screenHeight)
            else
                error("ui.updateRect: unsupported component type " .. tostring(node.component.type))
            end
        end

        node.layout.dirty = false
        for i, child in ipairs(node.children) do
            updateRect(pGfxContext, screenWidth, screenHeight, child, true)
        end
    else
        for i, child in ipairs(node.children) do
            updateRect(pGfxContext, screenWidth, screenHeight, child, false)
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
    ui.vertexFormat = {{
        name = "position",
        type = tkn.type.float,
        count = 2,
    }, {
        name = "uv",
        type = tkn.type.float,
        count = 2,
    }, {
        name = "color",
        type = tkn.type.uint32,
        count = 1,
    }}
    ui.vertexFormat.pVertexInputLayout = tkn.createVertexInputLayoutPtr(pGfxContext, ui.vertexFormat)
    uiRenderPass.setup(pGfxContext, pSwapchainAttachment, assetsPath, ui.vertexFormat.pVertexInputLayout, renderPassIndex)
    ui.rootNode = {
        name = "root",
        children = {},
        layout = {
            dirty = true,
            horizontal = {
                type = "relative",
                left = 0,
                right = 0,
            },
            vertical = {
                type = "relative",
                bottom = 0,
                top = 0,
            },
            rect = {},
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
    updateRect(pGfxContext, screenWidth, screenHeight, ui.rootNode, false)
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
    local component = image.createComponent(pGfxContext, color, slice, pMaterial, ui.vertexFormat, ui.renderPass.pImagePipeline, node)
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
    -- alignH: 0-1 (0=left, 0.5=center, 1=right)
    -- alignV: 0-1 (0=top, 0.5=center, 1=bottom)
    -- bold: true/false
    local component = text.createComponent(pGfxContext, textString, font, size, color, alignH or 0, alignV or 0, bold, font.pMaterial, ui.vertexFormat, ui.renderPass.pTextPipeline, node)
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
