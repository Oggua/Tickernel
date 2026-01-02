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
function sliderWidget.addWidget(pTknGfxContext, name, parent, index, layout, imageColor, radiusType)
    local widget = {}
    local processInputFunction = function(node, xNDC, yNDC, inputState)
        if ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                widget.handleNode.transform.color = 0xAAAAAAFF
                widget.handleNode.transformDirty = true
                local parentCenter = (parent.rect.horizontal.min + parent.rect.horizontal.max) * 0.5
                widget.handleNode.layout.horizontal.offset = parentCenter - xNDC
                widget.handleNode.layout.horizontal.dirty = true
                return true
            elseif inputState == input.inputState.up then
                widget.handleNode.transform.color = nil
                return false
            else
                return false
            end
        else
            widget.handleNode.transform.color = nil
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                return false
            else
                return false
            end
        end
    end
    local sliderTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
    }
    widget.sliderNode = ui.addInteractableNode(pTknGfxContext, processInputFunction, parent, index, name, layout, sliderTransform)

    local backgroundNodeLayout = {
        horizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
        },
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
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.sliderNode, 1, "buttonBackground", backgroundNodeLayout, backgroundTransform, imageColor, imageFitMode, image, imageUV)

    local handleNodeLayout = {
        horizontal = {
            type = "anchored",
            anchor = 0.5,
            pivot = 0.5,
            length = layout.vertical.length,
            offset = 0,
        },
        vertical = {
            type = "anchored",
            anchor = 0.5,
            pivot = 0.5,
            length = layout.vertical.length,
            offset = 0,
        },
    }
    local handleTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
    }
    widget.handleNode = ui.addImageNode(pTknGfxContext, widget.sliderNode, 2, "sliderHandle", handleNodeLayout, handleTransform, 0xFFFFFFFF, imageFitMode, image, imageUV)
    return widget
end

function sliderWidget.removeWidget(pTknGfxContext, sliderWidget)
    ui.removeNode(pTknGfxContext, sliderWidget.sliderNode)
    sliderWidget.sliderNode = nil
    sliderWidget.backgroundNode = nil
    sliderWidget.handleNode = nil
end

return sliderWidget
