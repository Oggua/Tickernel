local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknToggleWidget = {}

function tknToggleWidget.add(pTknGfxContext, name, parent, index, horizontal, vertical, handleScale, onValueChange)
    local widget = {}
    widget.isOn = false
    local processInput = nil
    if onValueChange then
        widget.onValueChange = onValueChange
        processInput = function(node, xNdc, yNdc, inputState)
            if tknWidgetConfig.updateClickWidgetColor then
                tknWidgetConfig.updateClickWidgetColor(node, xNdc, yNdc, inputState)
            end
            if ui.rectContainsPoint(node.rect, xNdc, yNdc) then
                if inputState == input.inputState.down then
                    return true
                elseif inputState == input.inputState.up then
                    widget.isOn = not widget.isOn
                    ui.setNodeTransformActive(widget.handleNode, widget.isOn)
                    onValueChange(widget, widget.isOn)
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

    widget.toggleNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, tknWidgetConfig.defaultTransform)

    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "buttonBackground", widget.toggleNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, tknWidgetConfig.color.semiDark, false, true)

    local handleTransform = {
        rotation = 0,
        horizontalScale = handleScale,
        verticalScale = handleScale,
        color = nil,
        active = false,
    }
    widget.handleNode = tknImageNode.addNode(pTknGfxContext, "toggleHandle", widget.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, handleTransform, tknWidgetConfig.color.semiLighter, false, true)

    return widget
end

function tknToggleWidget.remove(pTknGfxContext, widget)
    ui.removeNode(pTknGfxContext, widget.toggleNode)
    widget.toggleNode = nil
    widget.backgroundNode = nil
    widget.handleNode = nil
end

function tknToggleWidget.setIsOn(widget, isOn)
    if isOn ~= widget.isOn then
        widget.isOn = isOn
        ui.setNodeTransformActive(widget.handleNode, widget.isOn)
        if widget.onValueChange then
            widget.onValueChange(widget.isOn)
        end
    end
end
return tknToggleWidget
