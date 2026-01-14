local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local toggleWidget = {}
toggleWidget.radiusType = {
    none = 4,
    xsmall = 8,
    small = 16,
    medium = 32,
    large = 64,
}
function toggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, backgroundColor, radiusType, handleScale, handleColor, callback)
    local widget = {}
    widget.isToggled = true
    local processInputFunction = function(node, xNDC, yNDC, inputState)
        if ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                node.transform.color = 0x9E9E9EFF
                return true
            elseif inputState == input.inputState.up then
                node.transform.color = 0xFFFFFFFF
                widget.isToggled = not widget.isToggled
                widget.handleNode.transform.active = widget.isToggled
                if callback then
                    callback(widget.isToggled)
                end
                return false
            else
                node.transform.color = 0xFFFFFFFF
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
    local toggleTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = 0xFFFFFFFF,
        active = true,
    }
    widget.toggleNode = ui.addInteractableNode(pTknGfxContext, processInputFunction, parent, index, name, horizontal, vertical, toggleTransform)

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
    local image = ui.loadImage(pTknGfxContext, "/textures/uiDefault.astc")
    local imageFitMode = {
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
    local imageUV
    if radiusType == toggleWidget.radiusType.none then
        imageUV = require("atlas.uiDefault").square8x8
    elseif radiusType == toggleWidget.radiusType.xsmall then
        imageUV = require("atlas.uiDefault").circle16x16
    elseif radiusType == toggleWidget.radiusType.small then
        imageUV = require("atlas.uiDefault").circle32x32
    elseif radiusType == toggleWidget.radiusType.medium then
        imageUV = require("atlas.uiDefault").circle64x64
    elseif radiusType == toggleWidget.radiusType.large then
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
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.toggleNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, backgroundColor, imageFitMode, image, imageUV)

    -- Directly use horizontal/vertical for handle node, no need for extra layout object
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
    local handleTransform = {
        rotation = 0,
        horizontalScale = handleScale,
        verticalScale = handleScale,
        color = 0xFFFFFFFF,
        active = true,
    }
    widget.handleNode = ui.addImageNode(pTknGfxContext, widget.toggleNode, 2, "toggleHandle", handleHorizontal, handleVertical, handleTransform, handleColor, imageFitMode, image, imageUV)
    return widget
end

function toggleWidget.removeWidget(pTknGfxContext, toggleWidget)
    ui.removeNode(pTknGfxContext, toggleWidget.toggleNode)
    toggleWidget.toggleNode = nil
    toggleWidget.backgroundNode = nil
    toggleWidget.handleNode = nil
end

return toggleWidget
