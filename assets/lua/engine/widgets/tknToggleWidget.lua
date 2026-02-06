local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknToggleWidget = {}

function tknToggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, backgroundColor, image, imageFitMode, imageUv, handleScale, handleColor, animate, onValueChange)
    local widget = {}
    widget.isToggled = false
    local processInput = function(node, xNdc, yNdc, inputState)
        if animate then
            animate(node, xNdc, yNdc, inputState)
        end
        if ui.rectContainsPoint(node.rect, xNdc, yNdc) then
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                widget.isToggled = not widget.isToggled
                ui.setNodeTransformActive(widget.handleNode, widget.isToggled)
                if onValueChange then
                    onValueChange(widget.isToggled)
                end
                return false
            else
                return false
            end
        else
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
        color = nil,
        active = true,
    }
    widget.toggleNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, toggleTransform)

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
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.toggleNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, backgroundColor, 0, imageFitMode, image, imageUv, nil)

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
        color = nil,
        active = false,
    }
    widget.handleNode = ui.addImageNode(pTknGfxContext, widget.toggleNode, 2, "toggleHandle", handleHorizontal, handleVertical, handleTransform, handleColor, 0, imageFitMode, image, imageUv, nil)
    return widget
end

function tknToggleWidget.removeWidget(pTknGfxContext, widget)
    ui.removeNode(pTknGfxContext, widget.toggleNode)
    widget.toggleNode = nil
    widget.backgroundNode = nil
    widget.handleNode = nil
end

return tknToggleWidget
