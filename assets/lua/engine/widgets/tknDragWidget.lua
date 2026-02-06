local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknDragWidget = {}

function tknDragWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical)
    local widget = {}
    local processInput = function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then
            -- Convert NDC to anchor or offset depending on layout type
            local parentRect = node.parent.rect
            local parentHorizontal = parentRect.horizontal
            local parentVertical = parentRect.vertical

            local parentWidthNdc = parentHorizontal.max - parentHorizontal.min
            local parentHeightNdc = parentVertical.max - parentVertical.min

            -- Calculate relative position within parent (0 to 1)
            local relPosX = (xNdc - parentHorizontal.min) / parentWidthNdc
            local relPosY = (yNdc - parentVertical.min) / parentHeightNdc

            if node.horizontal.type == ui.layoutType.anchored then
                -- For anchored: set anchor directly
                node.horizontal.anchor = relPosX
            else
                -- For relative: calculate offset from parent pivot
                local offsetX = (relPosX - parentHorizontal.pivot) * parentWidthNdc
                node.horizontal.offset = offsetX
            end

            if node.vertical.type == ui.layoutType.anchored then
                -- For anchored: set anchor directly
                node.vertical.anchor = relPosY
            else
                -- For relative: calculate offset from parent pivot
                local offsetY = (relPosY - parentVertical.pivot) * parentHeightNdc
                node.vertical.offset = offsetY
            end
            ui.setNodeOrientation(node, "horizontal", node.horizontal)
            ui.setNodeOrientation(node, "vertical", node.vertical)
            return true
        elseif inputState == input.inputState.up then

            return false
        else
            return false
        end
    end
    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    widget.dragNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, defaultTransform)

    -- Background image node
    local backgroundHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local backgroundVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }

    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "dragBackground", widget.dragNode, 1, backgroundHorizontal, backgroundVertical, defaultTransform, tknWidgetConfig.color.semiDark, false)
    return widget
end

function tknDragWidget.removeWidget(pTknGfxContext, widget)
    ui.removeNode(pTknGfxContext, widget.dragNode)
    widget.dragNode = nil
    widget.backgroundNode = nil
end

return tknDragWidget
