local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknTreeNodeWidget = {}

function tknTreeNodeWidget.add(pTknGfxContext, parent, index, horizontal, vertical, contentString, onSelectedChange, onExpandedChange)
    local treeNodeWidget = {}
    local onValueChange = nil
    if onSelectedChange then
        onValueChange = function(widget, isOn)
            if isOn then
                ui.setImageOrTextNodeColor(treeNodeWidget.selectedToggleWidget.textNode, tknWidgetConfig.color.inverseSemiLighter)
            else
                ui.setImageOrTextNodeColor(treeNodeWidget.selectedToggleWidget.textNode, tknWidgetConfig.color.semiLighter)
            end
            onSelectedChange(treeNodeWidget, isOn)
        end
    end
    treeNodeWidget.selectedToggleWidget = tknToggleWidget.add(pTknGfxContext, "selectedToggleNode", parent, index, horizontal, vertical, 1, onValueChange)
    treeNodeWidget.selectedToggleWidget.textNode = tknTextNode.add(pTknGfxContext, "contentText", treeNodeWidget.selectedToggleWidget.backgroundNode, 2, {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = tknWidgetConfig.smallInteractableWidth + tknWidgetConfig.defaultSpacing * 2,
        maxOffset = 0,
        offset = 0,
    }, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, contentString, tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0.5, false)

    local expandedString = "\xee\xa9\x8e"
    local collapsedString = "\xee\xa9\xae"
    local noChildrenString = "-"

    local onClick = nil
    if onExpandedChange then
        onClick = function(widget)
            if widget.isOn then
                widget.isOn = false
                ui.setTextContent(widget.textNode, collapsedString)
            else
                widget.isOn = true
                ui.setTextContent(widget.textNode, expandedString)
            end
            onExpandedChange(treeNodeWidget, widget.isOn)
        end
    end

    treeNodeWidget.expandedButtonWidget = tknButtonWidget.add(pTknGfxContext, "expandedButtonWidget", treeNodeWidget.selectedToggleWidget.backgroundNode, 3, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.smallInteractableWidth,
        offset = tknWidgetConfig.defaultSpacing,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.smallInteractableWidth,
        offset = 0,
    }, onClick)

    if onExpandedChange then
        treeNodeWidget.expandedButtonWidget.textNode = tknTextNode.add(pTknGfxContext, "buttonTextNode", treeNodeWidget.expandedButtonWidget.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, collapsedString, tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0.5, 0.5, false)
    else
        treeNodeWidget.expandedButtonWidget.textNode = tknTextNode.add(pTknGfxContext, "buttonTextNode", treeNodeWidget.expandedButtonWidget.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, noChildrenString, tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0.5, 0.5, false)
    end

    treeNodeWidget.bottomInteractionNode = ui.addInteractableNode(pTknGfxContext, function(widget, xNdc, yNdc, inputState)
        return false
    end, treeNodeWidget.selectedToggleWidget.backgroundNode, 3, "interactionNode", tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = tknWidgetConfig.defaultDragEdgeWidth,
        offset = 0,
    }, tknWidgetConfig.defaultTransform)
    ui.setNodeTransformActive(treeNodeWidget.bottomInteractionNode, false)
    return treeNodeWidget
end

function tknTreeNodeWidget.remove(pTknGfxContext, treeNodeWidget)
    tknButtonWidget.remove(pTknGfxContext, treeNodeWidget.expandedButtonWidget)
    tknToggleWidget.remove(pTknGfxContext, treeNodeWidget.selectedToggleWidget)
    treeNodeWidget.selectedToggleWidget = nil
    treeNodeWidget.expandedButtonWidget = nil
    treeNodeWidget.bottomInteractionNode = nil
end

return tknTreeNodeWidget
