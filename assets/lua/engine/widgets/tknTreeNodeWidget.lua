local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknDropdownWidget = require("engine.widgets.tknDropdownWidget")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknWindowWidget = require("engine.widgets.tknWindowWidget")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local tknScrollViewWidget = require("engine.widgets.tknScrollViewWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTreeNodeWidget = {}

function tknTreeNodeWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, contentString, onSelectedChange, onExpandedChange)
    local treeNodeWidget = {}
    treeNodeWidget.selectedToggleWidget = tknToggleWidget.addWidget(pTknGfxContext, "selectedToggleNode", parent, index, horizontal, vertical, 1, function(widget, isOn)
        if isOn then
            ui.setImageOrTextNodeColor(widget.textNode, tknWidgetConfig.color.inverseSemiLighter)
        else
            ui.setImageOrTextNodeColor(widget.textNode, tknWidgetConfig.color.semiLighter)
        end
        if onSelectedChange then
            onSelectedChange(treeNodeWidget, isOn)
        end
    end)
    treeNodeWidget.selectedToggleWidget.textNode = tknTextNode.addNode(pTknGfxContext, "contentText", treeNodeWidget.selectedToggleWidget.backgroundNode, 2, {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = tknWidgetConfig.smallInteractableWidth + tknWidgetConfig.defaultSpacing * 2,
        maxOffset = 0,
        offset = 0,
    }, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, contentString, tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0.5, false)

    local expandedString = "\xee\xa9\x8d"
    local collapsedString = "\xee\xa9\xad"
    treeNodeWidget.expandedButtonWidget = tknButtonWidget.addWidget(pTknGfxContext, "expandedButtonWidget", treeNodeWidget.selectedToggleWidget.backgroundNode, 3, {
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
    }, function(widget)
        if widget.isOn then
            widget.isOn = false
            ui.setTextString(widget.textNode, collapsedString)
        else
            widget.isOn = true
            ui.setTextString(widget.textNode, expandedString)
        end
        if onExpandedChange then
            onExpandedChange(treeNodeWidget, widget.isOn)
        end
    end)
    treeNodeWidget.expandedButtonWidget.textNode = tknTextNode.addNode(pTknGfxContext, "buttonTextNode", treeNodeWidget.expandedButtonWidget.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, collapsedString, tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0.5, 0.5, false)

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

function tknTreeNodeWidget.removeWidget()

end

return tknTreeNodeWidget
