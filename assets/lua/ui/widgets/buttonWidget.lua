local ui = require("ui.ui")
local input = require("input")
local buttonWidget = {}
function buttonWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, image, imageFitMode, imageUv, imageColor, font, text, fontSize, fontColor, animate, onClick)
    local widget = {}
    local buttonTransform = {
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
        if ui.rectContainsPoint(node.rect, xNdc, yNdc) then
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                if onClick then
                    onClick()
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
    widget.buttonNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, buttonTransform)
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
    widget.backgroundNode = ui.addImageNode(pTknGfxContext, widget.buttonNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, imageColor, 0, imageFitMode, image, imageUv, nil)

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
        color = nil,
        active = true,
    }
    widget.textNode = ui.addTextNode(pTknGfxContext, widget.backgroundNode, 1, "buttonText", textHorizontal, textVertical, textTransform, text, font, fontSize, fontColor, 0, 0.5, 0.5, true)
    return widget
end

function buttonWidget.removeWidget(pTknGfxContext, buttonWidget)
    ui.removeNode(pTknGfxContext, buttonWidget.buttonNode)
    buttonWidget.buttonNode = nil
    buttonWidget.backgroundNode = nil
    buttonWidget.textNode = nil
end

return buttonWidget
