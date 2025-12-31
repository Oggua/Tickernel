local ui = require("ui.ui")
local input = require("input")
local buttonWidget = {}

function buttonWidget.addButtonWidget(pTknGfxContext, name, parent, index, layout, onClick, image, ImageUV, imageFitMode, imageColor, font, text, fontSize, fontColor)
    local buttonWidget = {}
    local processInputFunction = function(node, xNDC, yNDC, inputState)
        if ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                node.overrideColor = 0xAAAAAAFF
                node.layout.horizontal.scale = 0.95
                node.layout.vertical.scale = 0.95
                return true
            elseif inputState == input.inputState.up then
                node.overrideColor = nil
                node.layout.horizontal.scale = 1
                node.layout.vertical.scale = 1
                if onClick then
                    onClick()
                end
                return false
            else
                return false
            end
        else
            node.overrideColor = nil
            node.layout.horizontal.scale = 1
            node.layout.vertical.scale = 1
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                return false
            else
                return false
            end
        end
    end
    buttonWidget.buttonNode = ui.addInteractableNode(pTknGfxContext, processInputFunction, parent, index, name, layout)
    local backgroundNodeLayout = {
        dirty = true,
        horizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
    }

    buttonWidget.backgroundNode = ui.addImageNode(pTknGfxContext, buttonWidget.buttonNode, 1, "buttonBackground", backgroundNodeLayout, imageColor, imageFitMode, image, ImageUV)

    local textNodeLayout = {
        dirty = true,
        horizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
    }
    buttonWidget.textNode = ui.addTextNode(pTknGfxContext, buttonWidget.backgroundNode, 1, "buttonText", textNodeLayout, text, font, fontSize, fontColor, 0.5, 0.5, true)
    return buttonWidget
end

function buttonWidget.removeButtonWidget(pTknGfxContext, buttonWidget)
    ui.removeNode(pTknGfxContext, buttonWidget.buttonNode)
    buttonWidget.buttonNode = nil
    buttonWidget.backgroundNode = nil
    buttonWidget.textNode = nil
end

return buttonWidget