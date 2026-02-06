local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknToggleWidget = {}

function tknToggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    -- Lazy load tknWidgetConfig to avoid circular dependency
    local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")

    local widget = {}
    widget.isToggled = false
    local processInput = function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateClickWidgetColor then
            tknWidgetConfig.updateClickWidgetColor(node, xNdc, yNdc, inputState)
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
    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "buttonBackground", widget.toggleNode, 1, defaultRelativeHorizontal, defaultRelativeVertical, defaultTransform, tknWidgetConfig.color.semiDark, false)

    local handleTransform = {
        rotation = 0,
        horizontalScale = tknWidgetConfig.defaultToggleHandleScale,
        verticalScale = tknWidgetConfig.defaultToggleHandleScale,
        color = nil,
        active = false,
    }
    widget.handleNode = tknImageNode.addNode(pTknGfxContext, "toggleHandle", widget.toggleNode, 2, defaultRelativeHorizontal, defaultRelativeVertical, handleTransform, tknWidgetConfig.color.semiLighter, false)

    tknTextNode.addNode(pTknGfxContext, "toggleLabel", widget.toggleNode, 3, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 0,
        length = 256,
        offset = tknWidgetConfig.defaultPadding,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, defaultTransform, "Active Editor", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0.5, false)

    return widget
end

function tknToggleWidget.removeWidget(pTknGfxContext, widget)
    ui.removeNode(pTknGfxContext, widget.toggleNode)
    widget.toggleNode = nil
    widget.backgroundNode = nil
    widget.handleNode = nil
end

return tknToggleWidget
