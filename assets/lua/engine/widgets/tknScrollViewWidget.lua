local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknSliderWidget = require("engine.widgets.tknSliderWidget")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknScrollViewWidget = {}

function tknScrollViewWidget.add(pTknGfxContext, name, parent, index, horizontal, vertical, contentNodeHorizontal, contentNodeVertical)
    local widget = {}
    local startX, startY = nil, nil
    local processInput = function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then
            if startX == nil or startY == nil then
                startX = xNdc
                startY = yNdc
            end
            local currentX = xNdc
            local currentY = yNdc
            local deltaX = currentX - startX
            local deltaY = currentY - startY
            tknSliderWidget.setValue(widget.rightSliderWidget, widget.rightSliderWidget.handleNode.vertical.anchor - deltaY)
            tknSliderWidget.setValue(widget.bottomSliderWidget, widget.bottomSliderWidget.handleNode.horizontal.anchor - deltaX)
            startX = currentX
            startY = currentY
            return true
        elseif inputState == input.inputState.up then
            startX = nil
            startY = nil
            return false
        else
            return false
        end
    end
    widget.scrollViewNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, tknWidgetConfig.defaultTransform)

    widget.scrollViewBackgroundNode = tknImageNode.addNode(pTknGfxContext, "scrollViewBackground", widget.scrollViewNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, tknWidgetConfig.color.semiDark, true, true)

    widget.contentNode = ui.addNode(pTknGfxContext, widget.scrollViewBackgroundNode, 1, "scrollViewContent", contentNodeHorizontal, contentNodeVertical, tknWidgetConfig.defaultTransform)

    local onRightSliderValueChange = function(value)
        if widget.contentNode.rect.vertical.max - widget.contentNode.rect.vertical.min >= widget.scrollViewBackgroundNode.rect.vertical.max - widget.scrollViewBackgroundNode.rect.vertical.min then
            widget.contentNode.vertical.anchor = value
            widget.contentNode.vertical.pivot = value
            ui.setNodeOrientation(widget.contentNode, ui.orientationType.vertical, widget.contentNode.vertical)
        else
            widget.contentNode.vertical.anchor = 0
            widget.contentNode.vertical.pivot = 0
            ui.setNodeOrientation(widget.contentNode, ui.orientationType.vertical, widget.contentNode.vertical)
        end
    end
    widget.rightSliderWidget = tknSliderWidget.add(pTknGfxContext, "rightScrollViewSlider", widget.scrollViewBackgroundNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = tknWidgetConfig.smallInteractableWidth,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = -tknWidgetConfig.smallInteractableWidth,
        offset = 0,
    }, ui.orientationType.vertical, 0, onRightSliderValueChange)

    local onBottomSliderValueChange = function(value)
        if widget.contentNode.rect.horizontal.max - widget.contentNode.rect.horizontal.min >= widget.scrollViewBackgroundNode.rect.horizontal.max - widget.scrollViewBackgroundNode.rect.horizontal.min then
            widget.contentNode.horizontal.anchor = value
            widget.contentNode.horizontal.pivot = value
            ui.setNodeOrientation(widget.contentNode, ui.orientationType.horizontal, widget.contentNode.horizontal)
        else
            widget.contentNode.horizontal.anchor = 0
            widget.contentNode.horizontal.pivot = 0
            ui.setNodeOrientation(widget.contentNode, ui.orientationType.horizontal, widget.contentNode.horizontal)
        end

    end
    widget.bottomSliderWidget = tknSliderWidget.add(pTknGfxContext, "bottomScrollViewSlider", widget.scrollViewBackgroundNode, 3, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = -tknWidgetConfig.smallInteractableWidth,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = tknWidgetConfig.smallInteractableWidth,
        offset = 0,
    }, ui.orientationType.horizontal, 0, onBottomSliderValueChange)

    widget.handleLengthDirty = true
    widget.update = function()

    end
    if not tknScrollViewWidget.widgets then
        tknScrollViewWidget.widgets = {}
    end
    table.insert(tknScrollViewWidget.widgets, widget)
    return widget
end

function tknScrollViewWidget.remove(pTknGfxContext, widget)
    for i, w in ipairs(tknScrollViewWidget.widgets) do
        if w == widget then
            table.remove(tknScrollViewWidget.widgets, i)
            break
        end
    end
    tknSliderWidget.remove(pTknGfxContext, widget.bottomSliderWidget)
    tknSliderWidget.remove(pTknGfxContext, widget.rightSliderWidget)
    ui.removeNode(pTknGfxContext, widget.scrollViewNode)
    widget.scrollViewNode = nil
    widget.scrollViewBackgroundNode = nil
end

function tknScrollViewWidget.setContentOrientation(widget, orientationType, orientation)
    widget.oldContentWidth = widget.contentNode.rect.horizontal.max - widget.contentNode.rect.horizontal.min
    widget.oldContentHeight = widget.contentNode.rect.vertical.max - widget.contentNode.rect.vertical.min
    ui.setNodeOrientation(widget.contentNode, orientationType, orientation)
    widget.handleLengthDirty = true
end

function tknScrollViewWidget.update()
    if tknScrollViewWidget.widgets then
        for i, widget in ipairs(tknScrollViewWidget.widgets) do
            if widget.handleLengthDirty then
                local contentWidth = widget.contentNode.rect.horizontal.max - widget.contentNode.rect.horizontal.min
                local contentHeight = widget.contentNode.rect.vertical.max - widget.contentNode.rect.vertical.min
                local viewWidth = widget.scrollViewBackgroundNode.rect.horizontal.max - widget.scrollViewBackgroundNode.rect.horizontal.min
                local viewHeight = widget.scrollViewBackgroundNode.rect.vertical.max - widget.scrollViewBackgroundNode.rect.vertical.min
                local horizontalLength = tknMath.clamp(viewWidth / contentWidth, 0.0, 1.0) * (widget.bottomSliderWidget.sliderNode.rect.horizontal.max - widget.bottomSliderWidget.sliderNode.rect.horizontal.min)
                local verticalLength = tknMath.clamp(viewHeight / contentHeight, 0.0, 1.0) * (widget.rightSliderWidget.sliderNode.rect.vertical.max - widget.rightSliderWidget.sliderNode.rect.vertical.min)
                tknSliderWidget.setHandleLength(widget.bottomSliderWidget, horizontalLength)
                tknSliderWidget.setHandleLength(widget.rightSliderWidget, verticalLength)
                if widget.oldContentHeight ~= nil and widget.oldContentWidth ~= nil then
                    local absoluteVerticalPosition = widget.oldContentHeight * widget.rightSliderWidget.handleNode.vertical.anchor
                    local absoluteHorizontalPosition = widget.oldContentWidth * widget.bottomSliderWidget.handleNode.horizontal.anchor

                    tknSliderWidget.setValue(widget.rightSliderWidget, absoluteVerticalPosition / contentHeight)
                    tknSliderWidget.setValue(widget.bottomSliderWidget, absoluteHorizontalPosition / contentWidth)
                end

                widget.handleLengthDirty = false
            end
        end
    end
end

return tknScrollViewWidget
