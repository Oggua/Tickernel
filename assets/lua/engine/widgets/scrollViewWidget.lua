local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local sliderWidget = require("engine.widgets.sliderWidget")
local scrollViewWidget = {}

function scrollViewWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, backgroundColor, image, imageFitMode, imageUv, handleColor, handleWidth, animate, onValueChange)
    local widget = {}
    local startX, startY = nil, nil
    local processInput = function(node, xNdc, yNdc, inputState)
        if animate then
            animate(node, xNdc, yNdc, inputState)
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
            sliderWidget.setValue(widget.rightSliderWidget, widget.rightSliderWidget.handleNode.vertical.anchor - deltaY)
            sliderWidget.setValue(widget.bottomSliderWidget, widget.bottomSliderWidget.handleNode.horizontal.anchor - deltaX)
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
    widget.scrollViewNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    })

    widget.scrollViewBackgroundNode = ui.addImageNode(pTknGfxContext, widget.scrollViewNode, 1, "scrollViewBackground", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }, backgroundColor, 0.1, imageFitMode, image, imageUv, true)

    local contentNodeHorizontal = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1920,
        offset = 0,
    }
    local contentNodeVertical = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1080,
        offset = 0,
    }

    widget.contentNode = ui.addNode(pTknGfxContext, widget.scrollViewBackgroundNode, 1, "scrollViewContent", contentNodeHorizontal, contentNodeVertical, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    })

    -- Save references for later modification
    widget.contentNodeHorizontal = contentNodeHorizontal
    widget.contentNodeVertical = contentNodeVertical

    local onRightSliderValueChange = function(value)
        widget.contentNodeVertical.anchor = value
        widget.contentNodeVertical.pivot = value
        ui.setNodeOrienation(widget.contentNode, "vertical", widget.contentNodeVertical)
    end
    widget.rightSliderWidget = sliderWidget.addWidget(pTknGfxContext, "rightScrollViewSlider", widget.scrollViewBackgroundNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = handleWidth,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = -handleWidth,
        offset = 0,
    }, backgroundColor, image, imageFitMode, imageUv, handleColor, 0, sliderWidget.direction.vertical, animate, onRightSliderValueChange)

    local onBottomSliderValueChange = function(value)
        widget.contentNodeHorizontal.anchor = value
        widget.contentNodeHorizontal.pivot = value
        ui.setNodeOrienation(widget.contentNode, "horizontal", widget.contentNodeHorizontal)
    end
    widget.bottomSliderWidget = sliderWidget.addWidget(pTknGfxContext, "bottomScrollViewSlider", widget.scrollViewBackgroundNode, 3, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = -handleWidth,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = handleWidth,
        offset = 0,
    }, backgroundColor, image, imageFitMode, imageUv, handleColor, 0, sliderWidget.direction.horizontal, animate, onBottomSliderValueChange)
    widget.postUpdateGfxCallback = function()
        local contentWidth = widget.contentNode.rect.horizontal.max - widget.contentNode.rect.horizontal.min
        local contentHeight = widget.contentNode.rect.vertical.max - widget.contentNode.rect.vertical.min
        local viewWidth = widget.scrollViewBackgroundNode.rect.horizontal.max - widget.scrollViewBackgroundNode.rect.horizontal.min
        local viewHeight = widget.scrollViewBackgroundNode.rect.vertical.max - widget.scrollViewBackgroundNode.rect.vertical.min
        local horizontalLength = tknMath.clamp(viewWidth / contentWidth, 0.0, 1.0) * (widget.bottomSliderWidget.sliderNode.rect.horizontal.max - widget.bottomSliderWidget.sliderNode.rect.horizontal.min)
        local verticalLength = tknMath.clamp(viewHeight / contentHeight, 0.0, 1.0) * (widget.rightSliderWidget.sliderNode.rect.vertical.max - widget.rightSliderWidget.sliderNode.rect.vertical.min)
        sliderWidget.setHandleLength(widget.bottomSliderWidget, horizontalLength)
        sliderWidget.setHandleLength(widget.rightSliderWidget, verticalLength)
    end
    ui.addPostUpdateGfxCallback(widget.postUpdateGfxCallback)
    return widget
end

function scrollViewWidget.removeWidget(pTknGfxContext, widget)
    ui.removePostUpdateGfxCallback(widget.postUpdateGfxCallback)
    widget.postUpdateGfxCallback = nil
    sliderWidget.removeWidget(pTknGfxContext, widget.bottomSliderWidget)
    sliderWidget.removeWidget(pTknGfxContext, widget.rightSliderWidget)
    ui.removeNode(pTknGfxContext, widget.scrollViewNode)
    widget.scrollViewNode = nil
    widget.scrollViewBackgroundNode = nil
end

return scrollViewWidget
