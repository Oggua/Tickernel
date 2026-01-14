local ui = require("ui.ui")
local input = require("input")
local buttonWidget = {}
buttonWidget.radiusType = {
    none = 4,
    xsmall = 8,
    small = 16,
    medium = 32,
    large = 64,
}
function buttonWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onClick, radiusType, imageColor, font, text, fontSize, fontColor)
    local widget = {}
    local processInputFunction = function(node, xNDC, yNDC, inputState)
        if ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                node.transform.color = 0x9E9E9EFF
                return true
            elseif inputState == input.inputState.up then
                node.transform.color = 0xFFFFFFFF
                if onClick then
                    onClick()
                end
                return false
            else
                return false
            end
        else
            node.transform.color = 0xFFFFFFFF
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                return false
            else
                return false
            end
        end
    end
    local buttonTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = 0xFFFFFFFF,
        active = true,
    }
    widget.buttonNode = ui.addInteractableNode(pTknGfxContext, processInputFunction, parent, index, name, horizontal, vertical, buttonTransform)
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
    if radiusType == buttonWidget.radiusType.none then
        imageUV = require("atlas.uiDefault").square8x8
    elseif radiusType == buttonWidget.radiusType.xsmall then
        imageUV = require("atlas.uiDefault").circle16x16
    elseif radiusType == buttonWidget.radiusType.small then
        imageUV = require("atlas.uiDefault").circle32x32
    elseif radiusType == buttonWidget.radiusType.medium then
        imageUV = require("atlas.uiDefault").circle64x64
    elseif radiusType == buttonWidget.radiusType.large then
        imageUV = require("atlas.uiDefault").circle128x128
    else
        error("Unsupported radius type: " .. tostring(radiusType))
    end
    local backgroundTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = 0xFFFFFFFF,
        active = true,
    }
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.buttonNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, imageColor, imageFitMode, image, imageUV)

    -- Directly use horizontal/vertical for text node, no need for extra layout object
    local textHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local textVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local textTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = 0xFFFFFFFF,
        active = true,
    }
    widget.textNode = ui.addTextNode(pTknGfxContext, widget.backgroundNode, 1, "buttonText", textHorizontal, textVertical, textTransform, text, font, fontSize, fontColor, 0.5, 0.5, true)
    return widget
end

function buttonWidget.removeWidget(pTknGfxContext, buttonWidget)
    ui.removeNode(pTknGfxContext, buttonWidget.buttonNode)
    buttonWidget.buttonNode = nil
    buttonWidget.backgroundNode = nil
    buttonWidget.textNode = nil
end

return buttonWidget
