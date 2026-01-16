local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local toggleWidget = {}

function toggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, backgroundColor, uiDefaultCornerRadiusPreset, handleScale, handleColor, callback)
    local widget = {}
    widget.isToggled = true
    local processInputFunction = function(node, xNDC, yNDC, inputState)
        if ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                node.transform.color = colorPreset.light
                return true
            elseif inputState == input.inputState.up then
                node.transform.color = colorPreset.white
                widget.isToggled = not widget.isToggled
                widget.handleNode.transform.active = widget.isToggled
                if callback then
                    callback(widget.isToggled)
                end
                return false
            else
                node.transform.color = colorPreset.white
                return false
            end
        else
            node.transform.color = colorPreset.white
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
        color = colorPreset.white,
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
    local image, imageFitMode, imageUV = uiDefault.getSprite(uiDefaultCornerRadiusPreset)

    local backgroundTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = colorPreset.white,
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
        color = colorPreset.white,
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
