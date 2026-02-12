local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknSliderWidget = require("engine.widgets.tknSliderWidget")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknScrollViewWidget = {}

function tknScrollViewWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, contentNodeHorizontal, contentNodeVertical)
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
    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    widget.scrollViewNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, defaultTransform)

    widget.scrollViewBackgroundNode = tknImageNode.addNode(pTknGfxContext, "scrollViewBackground", widget.scrollViewNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, defaultTransform, tknWidgetConfig.color.semiDark, true, true)

    widget.contentNode = ui.addNode(pTknGfxContext, widget.scrollViewBackgroundNode, 1, "scrollViewContent", contentNodeHorizontal, contentNodeVertical, defaultTransform)

    local onRightSliderValueChange = function(value)
        widget.contentNode.vertical.anchor = value
        widget.contentNode.vertical.pivot = value
        ui.setNodeOrientation(widget.contentNode, ui.orientationType.vertical, widget.contentNode.vertical)
    end
    widget.rightSliderWidget = tknSliderWidget.addWidget(pTknGfxContext, "rightScrollViewSlider", widget.scrollViewBackgroundNode, 2, {
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
        widget.contentNode.horizontal.anchor = value
        widget.contentNode.horizontal.pivot = value
        ui.setNodeOrientation(widget.contentNode, ui.orientationType.horizontal, widget.contentNode.horizontal)
    end
    widget.bottomSliderWidget = tknSliderWidget.addWidget(pTknGfxContext, "bottomScrollViewSlider", widget.scrollViewBackgroundNode, 3, {
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
    widget.postUpdateGfxCallback = function()
        if widget.handleLengthDirty then
            local contentWidth = widget.contentNode.rect.horizontal.max - widget.contentNode.rect.horizontal.min
            local contentHeight = widget.contentNode.rect.vertical.max - widget.contentNode.rect.vertical.min
            local viewWidth = widget.scrollViewBackgroundNode.rect.horizontal.max - widget.scrollViewBackgroundNode.rect.horizontal.min
            local viewHeight = widget.scrollViewBackgroundNode.rect.vertical.max - widget.scrollViewBackgroundNode.rect.vertical.min
            local horizontalLength = tknMath.clamp(viewWidth / contentWidth, 0.0, 1.0) * (widget.bottomSliderWidget.sliderNode.rect.horizontal.max - widget.bottomSliderWidget.sliderNode.rect.horizontal.min)
            local verticalLength = tknMath.clamp(viewHeight / contentHeight, 0.0, 1.0) * (widget.rightSliderWidget.sliderNode.rect.vertical.max - widget.rightSliderWidget.sliderNode.rect.vertical.min)
            tknSliderWidget.setHandleLength(widget.bottomSliderWidget, horizontalLength)
            tknSliderWidget.setHandleLength(widget.rightSliderWidget, verticalLength)
            widget.handleLengthDirty = false
        end
    end
    ui.addPostUpdateGfxCallback(widget.postUpdateGfxCallback)
    return widget
end

function tknScrollViewWidget.removeWidget(pTknGfxContext, widget)
    ui.removePostUpdateGfxCallback(widget.postUpdateGfxCallback)
    widget.postUpdateGfxCallback = nil
    tknSliderWidget.removeWidget(pTknGfxContext, widget.bottomSliderWidget)
    tknSliderWidget.removeWidget(pTknGfxContext, widget.rightSliderWidget)
    ui.removeNode(pTknGfxContext, widget.scrollViewNode)
    widget.scrollViewNode = nil
    widget.scrollViewBackgroundNode = nil
end

function tknScrollViewWidget.setContentOrientation(widget, orientationType, orientation)
    ui.setNodeOrientation(widget.contentNode, orientationType, orientation)
    widget.handleLengthDirty = true
end

return tknScrollViewWidget
