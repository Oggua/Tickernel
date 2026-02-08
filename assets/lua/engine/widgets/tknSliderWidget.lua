local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknSliderWidget = {
    direction = {
        horizontal = "horizontal",
        vertical = "vertical",
    },
}

function tknSliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, direction, handleLength, onValueChange)
    local widget = {}
    widget.direction = direction
    widget.onValueChange = onValueChange

    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }

    local processInput = function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then
            if widget and widget.handleNode then
                local m = widget.handleParent.rect.model
                local m00, m01, m10, m11, tx, ty = m[1], m[2], m[4], m[5], m[7], m[8]
                local det = m00 * m11 - m01 * m10
                local inv00 = m11 / det
                local inv01 = -m01 / det
                local inv10 = -m10 / det
                local inv11 = m00 / det
                local value
                if widget.direction == tknSliderWidget.direction.horizontal then
                    local lx = inv00 * (xNdc - tx) + inv01 * (yNdc - ty)
                    local rx = widget.handleParent.rect.horizontal
                    local length = (rx.max - rx.min)
                    local pivot = widget.handleParent.horizontal.pivot or 0.5
                    value = lx / length + pivot
                    if value < 0 then
                        value = 0
                    elseif value > 1 then
                        value = 1
                    end

                else
                    assert(widget.direction == tknSliderWidget.direction.vertical, "Invalid slider direction: " .. tostring(widget.direction))
                    local ly = inv10 * (xNdc - tx) + inv11 * (yNdc - ty)
                    local ry = widget.handleParent.rect.vertical
                    local length = (ry.max - ry.min)
                    local pivot = widget.handleParent.vertical.pivot or 0.5
                    value = ly / length + pivot
                    if value < 0 then
                        value = 0
                    elseif value > 1 then
                        value = 1
                    end

                end
                tknSliderWidget.setValue(widget, value)
            end
            return true
        else
            return false
        end
    end
    widget.sliderNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, defaultTransform)

    -- Directly use horizontal/vertical for background node, no need for extra layout object
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
    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "sliderBackground", widget.sliderNode, 1, backgroundHorizontal, backgroundVertical, defaultTransform, tknWidgetConfig.color.semiDark, false, true)

    local handleParentHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local handleParentVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local handleHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local handleVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }

    if widget.direction == tknSliderWidget.direction.horizontal then
        local handleParentOffset
        if math.type(handleLength) == "integer" then
            handleParentOffset = handleLength // 2
        else
            handleParentOffset = handleLength / 2
        end

        handleParentHorizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = handleParentOffset,
            maxOffset = -handleParentOffset,
            offset = 0,
        }
        handleHorizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = handleLength,
            offset = 0,
        }
    else
        assert(widget.direction == tknSliderWidget.direction.vertical, "Invalid slider direction: " .. tostring(widget.direction))
        local handleParentOffset
        if math.type(handleLength) == "integer" then
            handleParentOffset = handleLength // 2
        else
            handleParentOffset = math.floor(handleLength * ui.screenHeight * 0.25)
        end
        handleParentVertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = handleParentOffset,
            maxOffset = -handleParentOffset,
            offset = 0,
        }
        handleVertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = handleLength,
            offset = 0,
        }
    end

    widget.handleParent = ui.addNode(pTknGfxContext, widget.backgroundNode, 1, "handleParent", handleParentHorizontal, handleParentVertical, defaultTransform)

    widget.handleNode = tknImageNode.addNode(pTknGfxContext, "sliderHandle", widget.handleParent, 1, handleHorizontal, handleVertical, defaultTransform, tknWidgetConfig.color.semiLighter, false, true)
    return widget
end

function tknSliderWidget.setValue(widget, value)
    value = tknMath.clamp(value, 0, 1)
    if widget.direction == tknSliderWidget.direction.horizontal then
        widget.handleNode.horizontal.anchor = value
        ui.setNodeOrientation(widget.handleNode, "horizontal", widget.handleNode.horizontal)
    elseif widget.direction == tknSliderWidget.direction.vertical then
        widget.handleNode.vertical.anchor = value
        ui.setNodeOrientation(widget.handleNode, "vertical", widget.handleNode.vertical)
    else
        error("Invalid slider direction: " .. tostring(widget.direction))
    end
    if widget.onValueChange then
        widget.onValueChange(value)
    end
end

function tknSliderWidget.removeWidget(pTknGfxContext, widget)
    ui.removeNode(pTknGfxContext, widget.sliderNode)
    widget.sliderNode = nil
    widget.backgroundNode = nil
    widget.handleParent = nil
    widget.handleNode = nil
    widget.direction = nil
    widget.onValueChange = nil
end

function tknSliderWidget.setHandleLength(widget, handleLength)
    local handleParentOffset
    if math.type(handleLength) == "integer" then
        handleParentOffset = handleLength // 2
    else
        handleParentOffset = handleLength / 2
    end
    if widget.direction == tknSliderWidget.direction.horizontal then
        widget.handleNode.horizontal.length = handleLength
        widget.handleParent.horizontal.minOffset = handleParentOffset
        widget.handleParent.horizontal.maxOffset = -handleParentOffset
        ui.setNodeOrientation(widget.handleNode, "horizontal", widget.handleNode.horizontal)
        ui.setNodeOrientation(widget.handleParent, "horizontal", widget.handleParent.horizontal)
    elseif widget.direction == tknSliderWidget.direction.vertical then
        widget.handleNode.vertical.length = handleLength
        widget.handleParent.vertical.minOffset = handleParentOffset
        widget.handleParent.vertical.maxOffset = -handleParentOffset
        ui.setNodeOrientation(widget.handleNode, "vertical", widget.handleNode.vertical)
        ui.setNodeOrientation(widget.handleParent, "vertical", widget.handleParent.vertical)
    else
        error("Invalid slider direction: " .. tostring(widget.direction))
    end
end

return tknSliderWidget
