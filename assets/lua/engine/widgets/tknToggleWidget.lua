local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknToggleWidget = {}

function tknToggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, handleScale, onValueChange)
    local widget = {}
    widget.isOn = false
    widget.onValueChange = onValueChange
    local processInput = function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateClickWidgetColor then
            tknWidgetConfig.updateClickWidgetColor(node, xNdc, yNdc, inputState)
        end
        if ui.rectContainsPoint(node.rect, xNdc, yNdc) then
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                widget.isOn = not widget.isOn
                ui.setNodeTransformActive(widget.handleNode, widget.isOn)
                if onValueChange then
                    onValueChange(widget, widget.isOn)
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
    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    widget.toggleNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, defaultTransform)

    -- Directly use horizontal/vertical for background node, no need for extra layout object
    local defaultRelativeHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local defaultRelativeVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "buttonBackground", widget.toggleNode, 1, defaultRelativeHorizontal, defaultRelativeVertical, defaultTransform, tknWidgetConfig.color.semiDark, false, true)

    local handleTransform = {
        rotation = 0,
        horizontalScale = handleScale,
        verticalScale = handleScale,
        color = nil,
        active = false,
    }
    widget.handleNode = tknImageNode.addNode(pTknGfxContext, "toggleHandle", widget.backgroundNode, 1, defaultRelativeHorizontal, defaultRelativeVertical, handleTransform, tknWidgetConfig.color.semiLighter, false, true)

    -- tknTextNode.addNode(pTknGfxContext, "toggleLabel", widget.toggleNode, 3, {
    --     type = ui.layoutType.anchored,
    --     anchor = 1,
    --     pivot = 0,
    --     length = 256,
    --     offset = tknWidgetConfig.defaultSpacing,
    -- }, {
    --     type = ui.layoutType.relative,
    --     pivot = 0.5,
    --     minOffset = 0,
    --     maxOffset = 0,
    --     offset = 0,
    -- }, defaultTransform, "Active Editor", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0.5, false)

    return widget
end

function tknToggleWidget.removeWidget(pTknGfxContext, widget)
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
