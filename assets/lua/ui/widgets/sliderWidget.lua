local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local sliderWidget = {
    direction = {
        horizontal = "horizontal",
        vertical = "vertical",
    },
}

function sliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, backgroundColor, image, imageFitMode, imageUv, handleOffset, handleColor, handleLength, direction, animate, onValueChange)
    local widget = {}
    widget.direction = direction
    local handleHorizontal = {
        type = "anchored",
        anchor = 0.5,
        pivot = 0.5,
        length = handleLength,
        offset = 0,
    }
    local handleVertical = {
        type = "anchored",
        anchor = 0.5,
        pivot = 0.5,
        length = handleLength,
        offset = 0,
    }

    local sliderTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }

    local processInput = function(node, xNdc, yNdc, inputState)
        if animate then
            animate(node, xNdc, yNdc, inputState)
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

                if widget.direction == sliderWidget.direction.horizontal then
                    local lx = inv00 * (xNdc - tx) + inv01 * (yNdc - ty)
                    local rx = widget.handleParent.rect.horizontal
                    local length = (rx.max - rx.min)
                    local pivot = widget.handleParent.horizontal.pivot or 0.5
                    local anchor = lx / length + pivot
                    if anchor < 0 then
                        anchor = 0
                    elseif anchor > 1 then
                        anchor = 1
                    end
                    handleHorizontal.anchor = anchor
                    ui.setNodeOrienation(widget.handleNode, "horizontal", handleHorizontal)
                else
                    assert(widget.direction == sliderWidget.direction.vertical, "Invalid slider direction: " .. tostring(widget.direction))
                    local ly = inv10 * (xNdc - tx) + inv11 * (yNdc - ty)
                    local ry = widget.handleParent.rect.vertical
                    local length = (ry.max - ry.min)
                    local pivot = widget.handleParent.vertical.pivot or 0.5
                    local anchor = ly / length + pivot
                    if anchor < 0 then
                        anchor = 0
                    elseif anchor > 1 then
                        anchor = 1
                    end
                    handleVertical.anchor = anchor
                    ui.setNodeOrienation(widget.handleNode, "vertical", handleVertical)
                end

                if onValueChange then
                    local value = widget.direction == sliderWidget.direction.vertical and widget.handleNode.vertical.anchor or widget.handleNode.horizontal.anchor
                    onValueChange(value)
                end
            end
            return true
        else
            return false
        end
    end

    widget.sliderNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, sliderTransform)

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

    local backgroundTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.sliderNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, backgroundColor, 0, imageFitMode, image, imageUv, nil)

    local handleParentHorizontal, handleParentVertical
    if widget.direction == sliderWidget.direction.horizontal then
        handleParentHorizontal = {
            type = ui.layoutType.relative,
            pivot = 0,
            minOffset = handleOffset,
            maxOffset = -handleOffset,
            offset = 0,
        }
        handleParentVertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
        }
    else
        assert(widget.direction == sliderWidget.direction.vertical, "Invalid slider direction: " .. tostring(widget.direction))
        handleParentHorizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
        }
        handleParentVertical = {
            type = ui.layoutType.relative,
            pivot = 0,
            minOffset = handleOffset,
            maxOffset = -handleOffset,
            offset = 0,
        }
    end
    local handleParentTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    widget.handleParent = ui.addNode(pTknGfxContext, widget.backgroundNode, 1, "handleParent", handleParentHorizontal, handleParentVertical, handleParentTransform)

    local handleTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    widget.handleNode = ui.addImageNode(pTknGfxContext, widget.handleParent, 1, "sliderHandle", handleHorizontal, handleVertical, handleTransform, handleColor, 0, imageFitMode, image, imageUv, nil)
    return widget
end

function sliderWidget.removeWidget(pTknGfxContext, sliderWidget)
    ui.removeNode(pTknGfxContext, sliderWidget.sliderNode)
    sliderWidget.sliderNode = nil
    sliderWidget.backgroundNode = nil
    sliderWidget.handleNode = nil
end

return sliderWidget
