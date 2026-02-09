local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknDropdownWidget = {}

function tknDropdownWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, items)
    local widget = {}
    widget.selectedIndex = 1
    widget.items = items
    widget.buttonWidget = tknButtonWidget.addWidget(pTknGfxContext, name .. "buttonNode", parent, index, horizontal, vertical, function(widget)
        ui.setNodeTransformActive(widget.backgroundNode, not widget.backgroundNode.transform.active)
    end)
    local paddedRelativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = tknWidgetConfig.defaultSpacing,
        maxOffset = -tknWidgetConfig.defaultSpacing,
        offset = 0,
    }
    local stretchedRelativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = -tknWidgetConfig.defaultSpacing,
        maxOffset = tknWidgetConfig.defaultSpacing,
        offset = 0,
    }
    local relativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }

    widget.dropdownTextNode = tknTextNode.addNode(pTknGfxContext, name .. "buttonTextNode", widget.buttonWidget.backgroundNode, 1, paddedRelativeOrientation, relativeOrientation, defaultTransform, widget.items[widget.selectedIndex].name, tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0, 0.5, false)

    widget.dropdownArrowTextNode = tknTextNode.addNode(pTknGfxContext, "arrowTextNode", widget.buttonWidget.backgroundNode, 2, paddedRelativeOrientation, relativeOrientation, defaultTransform, "\xef\x8c\xa6", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 1, 0.5, false)

    local inactiveTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = false,
    }
    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, name .. "dropdownBackgroundNode", widget.buttonWidget.backgroundNode, 3, stretchedRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 0,
        length = tknWidgetConfig.defaultSpacing + (#widget.items * (tknWidgetConfig.largeInteractableWidth + tknWidgetConfig.defaultSpacing)),
        offset = 0,
    }, inactiveTransform, tknWidgetConfig.color.semiDarker, false, true)

    widget.itemButtonWidgets = {}
    for i, item in ipairs(widget.items) do
        local itemButtonWidget = tknButtonWidget.addWidget(pTknGfxContext, name .. "ButtonNode" .. i, widget.backgroundNode, i, paddedRelativeOrientation, {
            type = ui.layoutType.anchored,
            anchor = 0,
            pivot = 0,
            length = tknWidgetConfig.largeInteractableWidth,
            offset = tknWidgetConfig.defaultSpacing + ((i - 1) * (tknWidgetConfig.largeInteractableWidth + tknWidgetConfig.defaultSpacing)),
        }, function(widget)
            ui.setNodeTransformActive(widget.backgroundNode, false)
            ui.setTextString(widget.dropdownTextNode, widget.items[widget.selectedIndex].name)
            if widget.selectedIndex ~= i then
                widget.selectedIndex = i
                if item.onSelect then
                    item.onSelect()
                end
            end
        end)
        tknTextNode.addNode(pTknGfxContext, name .. "itemTextNode" .. i, itemButtonWidget.backgroundNode, 1, paddedRelativeOrientation, paddedRelativeOrientation, defaultTransform, item.name, tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0.5, false)
        table.insert(widget.itemButtonWidgets, itemButtonWidget)
        widget.items[widget.selectedIndex].onSelect()
    end

    return widget
end

function tknDropdownWidget.removeWidget(pTknGfxContext, widget)
    -- Remove all item button widgets
    if widget.itemButtonWidgets then
        for _, itemButtonWidget in ipairs(widget.itemButtonWidgets) do
            tknButtonWidget.removeWidget(pTknGfxContext, itemButtonWidget)
        end
    end

    -- Remove main button widget
    if widget.buttonWidget then
        tknButtonWidget.removeWidget(pTknGfxContext, widget.buttonWidget)
    end

    -- Clear references
    widget.itemButtonWidgets = nil
    widget.buttonWidget = nil
    widget.backgroundNode = nil
    widget.dropdownTextNode = nil
    widget.dropdownArrowTextNode = nil
    widget.items = nil
end

return tknDropdownWidget
