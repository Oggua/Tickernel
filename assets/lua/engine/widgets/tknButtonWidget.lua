local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknButtonWidget = {}

function tknButtonWidget.add(pTknGfxContext, name, parent, index, horizontal, vertical, onClick)
    local widget = {}
    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    local processInput = nil
    if onClick then
        processInput = function(node, xNdc, yNdc, inputState)
            if tknWidgetConfig.updateClickWidgetColor then
                tknWidgetConfig.updateClickWidgetColor(node, xNdc, yNdc, inputState)
            end
            if ui.rectContainsPoint(node.rect, xNdc, yNdc) then
                if inputState == input.inputState.down then
                    return true
                elseif inputState == input.inputState.up then
                    onClick(widget)
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
    end

    widget.buttonNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, defaultTransform)
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
    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "buttonBackground", widget.buttonNode, 1, backgroundHorizontal, backgroundVertical, defaultTransform, tknWidgetConfig.color.semiDark, false, true)
    return widget
end

function tknButtonWidget.remove(pTknGfxContext, widget)
    ui.removeNode(pTknGfxContext, widget.buttonNode)
    widget.buttonNode = nil
    widget.backgroundNode = nil
end

return tknButtonWidget
