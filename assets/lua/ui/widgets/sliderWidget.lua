local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local sliderWidget = {}
sliderWidget.radiusType = {
    none = 4,
    xsmall = 8,
    small = 16,
    medium = 32,
    large = 64,
}
function sliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, imageColor, radiusType)
    local widget = {}

    local processInputFunction = function(node, xNDC, yNDC, inputState)
        if inputState == input.inputState.down then
            widget.handleNode.transform.color = 0xAAAAAAFF
            -- Convert world point to slider's local space
            local m = node.rect.model
            local m00, m01, m10, m11, tx, ty = m[1], m[2], m[4], m[5], m[7], m[8]
            local det = m00 * m11 - m01 * m10
            local inv00 = m11 / det
            local inv01 = -m01 / det
            local inv10 = -m10 / det
            local inv11 = m00 / det
            local lx = inv00 * (xNDC - tx) + inv01 * (yNDC - ty)
            local rx = node.rect.horizontal
            local length = (rx.max - rx.min)
            local pivot = node.horizontal.pivot or 0.5
            local anchor = lx / length + pivot
            if anchor < 0 then
                anchor = 0
            elseif anchor > 1 then
                anchor = 1
            end
            widget.handleNode.horizontal.anchor = anchor
            return true
        elseif inputState == input.inputState.up then
            widget.handleNode.transform.color = 0xFFFFFFFF
            return false
        else
            return false
        end

    end
    local sliderTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
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
    local imageFitMode, imageUV
    local image = ui.loadImage(pTknGfxContext, "/textures/uiDefault.astc")
    imageFitMode = {
        type = ui.fitModeType.sliced,
        horizontal = {
            minPadding = radiusType,
            maxPadding = radiusType,
        },
        vertical = {
            minPadding = radiusType,
            maxPadding = radiusType,
        },
    }
    if radiusType == sliderWidget.radiusType.none then
        imageUV = require("atlas.uiDefault").square8x8
    elseif radiusType == sliderWidget.radiusType.xsmall then
        imageUV = require("atlas.uiDefault").circle16x16
    elseif radiusType == sliderWidget.radiusType.small then
        imageUV = require("atlas.uiDefault").circle32x32
    elseif radiusType == sliderWidget.radiusType.medium then
        imageUV = require("atlas.uiDefault").circle64x64
    elseif radiusType == sliderWidget.radiusType.large then
        imageUV = require("atlas.uiDefault").circle128x128
    else
        error("Unsupported radius type: " .. tostring(radiusType))
    end
    local backgroundTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
    }
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.sliderNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, imageColor, imageFitMode, image, imageUV)

    -- Directly use horizontal/vertical for handle node, no need for extra layout object
    local handleHorizontal = {
        type = "anchored",
        anchor = 0.5,
        pivot = 0.5,
        length = vertical.length,
        offset = 0,
    }
    local handleVertical = {
        type = "anchored",
        anchor = 0.5,
        pivot = 0.5,
        length = vertical.length,
        offset = 0,
    }
    local handleTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
    }
    widget.handleNode = ui.addImageNode(pTknGfxContext, widget.sliderNode, 2, "sliderHandle", handleHorizontal, handleVertical, handleTransform, 0xFFFFFFFF, imageFitMode, image, imageUV)
    return widget
end

function sliderWidget.removeWidget(pTknGfxContext, sliderWidget)
    ui.removeNode(pTknGfxContext, sliderWidget.sliderNode)
    sliderWidget.sliderNode = nil
    sliderWidget.backgroundNode = nil
    sliderWidget.handleNode = nil
end

return sliderWidget
