local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknDragWidget = {}

function tknDragWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical)
    local widget = {}
    local dragState = {
        active = false,
        offsetX = 0,
        offsetY = 0,
    }
    local processInput = function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then
            local parentRect = node.parent.rect
            local parentHorizontal = parentRect.horizontal
            local parentVertical = parentRect.vertical
            local parentWidthNdc = parentHorizontal.max - parentHorizontal.min
            local parentHeightNdc = parentVertical.max - parentVertical.min

            -- On first press record cursor-to-pivot offset so drag keeps that gap.
            if not dragState.active then
                dragState.active = true
                dragState.offsetX = xNdc - node.rect.model[7]
                dragState.offsetY = yNdc - node.rect.model[8]
            end

            -- Desired pivot position in world space keeps the initial gap to the cursor.
            local targetPivotX = xNdc - dragState.offsetX
            local targetPivotY = yNdc - dragState.offsetY

            -- Transform target from world to parent-local to compute layout offsets.
            local pm = node.parent.rect.model
            local m00, m01, m10, m11 = pm[1], pm[2], pm[4], pm[5]
            local det = m00 * m11 - m01 * m10
            if det == 0 then
                return true
            end
            local invDet = 1 / det
            local worldDX = targetPivotX - pm[7]
            local worldDY = targetPivotY - pm[8]
            local offsetToParentX = (worldDX * m11 - worldDY * m01) * invDet
            local offsetToParentY = (-worldDX * m10 + worldDY * m00) * invDet

            -- Horizontal: solve for layout offset without snapping pivot to cursor.
            if node.horizontal.type == ui.layoutType.anchored then
                node.horizontal.offset = offsetToParentX - (node.horizontal.anchor - node.parent.horizontal.pivot) * parentWidthNdc
            else
                local anchorToParentNorm = node.parent.horizontal.pivot + (node.rect.horizontal.offset - node.horizontal.offset) / parentWidthNdc
                node.horizontal.offset = offsetToParentX - (anchorToParentNorm - node.parent.horizontal.pivot) * parentWidthNdc
            end

            -- Vertical: same idea as horizontal.
            if node.vertical.type == ui.layoutType.anchored then
                node.vertical.offset = offsetToParentY - (node.vertical.anchor - node.parent.vertical.pivot) * parentHeightNdc
            else
                local anchorToParentNorm = node.parent.vertical.pivot + (node.rect.vertical.offset - node.vertical.offset) / parentHeightNdc
                node.vertical.offset = offsetToParentY - (anchorToParentNorm - node.parent.vertical.pivot) * parentHeightNdc
            end

            ui.setNodeOrientation(node, ui.orientationType.horizontal, node.horizontal)
            ui.setNodeOrientation(node, ui.orientationType.vertical, node.vertical)
            return true
        elseif inputState == input.inputState.up then
            dragState.active = false
            return false
        else
            return dragState.active
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

    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "dragBackground", widget.dragNode, 1, backgroundHorizontal, backgroundVertical, defaultTransform, tknWidgetConfig.color.semiDark, false, true)
    return widget
end

function tknDragWidget.removeWidget(pTknGfxContext, widget)
    ui.removeNode(pTknGfxContext, widget.dragNode)
    widget.dragNode = nil
    widget.backgroundNode = nil
end

return tknDragWidget
