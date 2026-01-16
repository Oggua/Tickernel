local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local sliderWidget = {
    direction = {
        horizontal = "horizontal",
        vertical = "vertical",
    },
}

function sliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, backgroundColor, uiDefaultCornerRadiusPreset, handleColor, handleLength, direction, callback)
    local widget = {}
    widget.direction = direction
    local processInputFunction = function(node, xNDC, yNDC, inputState)
        if inputState == input.inputState.down then
            node.transform.color = colorPreset.light
            -- Convert world point to slider's local space
            local m = widget.handleParent.rect.model
            local m00, m01, m10, m11, tx, ty = m[1], m[2], m[4], m[5], m[7], m[8]
            local det = m00 * m11 - m01 * m10
            local inv00 = m11 / det
            local inv01 = -m01 / det
            local inv10 = -m10 / det
            local inv11 = m00 / det

            if widget.direction == sliderWidget.direction.horizontal then
                local lx = inv00 * (xNDC - tx) + inv01 * (yNDC - ty)
                local rx = widget.handleParent.rect.horizontal
                local length = (rx.max - rx.min)
                local pivot = widget.handleParent.horizontal.pivot or 0.5
                local anchor = lx / length + pivot
                if anchor < 0 then
                    anchor = 0
                elseif anchor > 1 then
                    anchor = 1
                end
                widget.handleNode.horizontal.anchor = anchor
                widget.handleNode.vertical.anchor = 0.5
            else
                assert(widget.direction == sliderWidget.direction.vertical, "Invalid slider direction: " .. tostring(widget.direction))
                local ly = inv10 * (xNDC - tx) + inv11 * (yNDC - ty)
                local ry = widget.handleParent.rect.vertical
                local length = (ry.max - ry.min)
                local pivot = widget.handleParent.vertical.pivot or 0.5
                local anchor = ly / length + pivot
                if anchor < 0 then
                    anchor = 0
                elseif anchor > 1 then
                    anchor = 1
                end
                widget.handleNode.vertical.anchor = anchor
                print("ly: " .. tostring(ly) .. ", length: " .. tostring(length) .. ", anchor: " .. tostring(anchor))
            end

            if callback then
                local value = widget.direction == sliderWidget.direction.vertical and widget.handleNode.vertical.anchor or widget.handleNode.horizontal.anchor
                callback(value)
            end
            return true
        elseif inputState == input.inputState.up then
            node.transform.color = colorPreset.white
            return false
        else
            node.transform.color = colorPreset.white
            return false
        end

    end
    local sliderTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = colorPreset.white,
        active = true,
    }
    widget.sliderNode = ui.addInteractableNode(pTknGfxContext, processInputFunction, parent, index, name, horizontal, vertical, sliderTransform)

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

    local image, imageFitMode, imageUV = uiDefault.getSprite(uiDefaultCornerRadiusPreset)

    local backgroundTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = colorPreset.white,
        active = true,
    }
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.sliderNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, backgroundColor, imageFitMode, image, imageUV)

    local handleParentHorizontal, handleParentVertical
    -- Directly use horizontal/vertical for background node, no need for extra layout object
    local radius = uiDefault.cornerRadiusPresetToRadius[uiDefaultCornerRadiusPreset];
    if widget.direction == sliderWidget.direction.horizontal then
        handleParentHorizontal = {
            type = ui.layoutType.relative,
            pivot = 0,
            minOffset = radius,
            maxOffset = -radius,
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
            minOffset = radius,
            maxOffset = -radius,
            offset = 0,
        }
    end
    local handleParentTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = colorPreset.white,
        active = true,
    }
    widget.handleParent = ui.addNode(pTknGfxContext, widget.backgroundNode, 1, "handleParent", handleParentHorizontal, handleParentVertical, handleParentTransform)

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

    local handleTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = colorPreset.white,
        active = true,
    }
    widget.handleNode = ui.addImageNode(pTknGfxContext, widget.handleParent, 1, "sliderHandle", handleHorizontal, handleVertical, handleTransform, handleColor, imageFitMode, image, imageUV)
    return widget
end

function sliderWidget.removeWidget(pTknGfxContext, sliderWidget)
    ui.removeNode(pTknGfxContext, sliderWidget.sliderNode)
    sliderWidget.sliderNode = nil
    sliderWidget.backgroundNode = nil
    sliderWidget.handleNode = nil
end

return sliderWidget
