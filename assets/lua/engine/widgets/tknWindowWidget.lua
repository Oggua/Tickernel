local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknSliderWidget = require("engine.widgets.tknSliderWidget")
local tknDragWidget = require("engine.widgets.tknDragWidget")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknScrollViewWidget = require("engine.widgets.tknScrollViewWidget")
local tknWindowWidget = {}

function tknWindowWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, title)
    local widget = {}
    local defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    widget.dragWidget = tknDragWidget.addWidget(pTknGfxContext, "windowDragWidget", parent, index, horizontal, vertical)

    local relativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local paddedRelativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = tknWidgetConfig.defaultSpacing,
        maxOffset = -tknWidgetConfig.defaultSpacing,
        offset = 0,
    }
    local dragEdgePaddedRelativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = tknWidgetConfig.roundedCornerRadius,
        maxOffset = -tknWidgetConfig.roundedCornerRadius,
        offset = 0,
    }
    local leftDragEdgeNode = ui.addInteractableNode(pTknGfxContext, function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then

            return true
        elseif inputState == input.inputState.up then

            return false
        else

            return false
        end
    end, widget.dragWidget.backgroundNode, 1, "leftDragEdgeNode", {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.defaultDragEdgeWidth,
        offset = 0,
    }, dragEdgePaddedRelativeOrientation, defaultTransform)

    tknImageNode.addNode(pTknGfxContext, "leftDragEdgeImage", leftDragEdgeNode, 1, relativeOrientation, relativeOrientation, defaultTransform, tknWidgetConfig.color.semiDark, false, false)

    local rightDragEdgeNode = ui.addInteractableNode(pTknGfxContext, function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then
            return true
        elseif inputState == input.inputState.up then
            return false
        else
            return false
        end
    end, widget.dragWidget.backgroundNode, 2, "rightDragEdgeNode", {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = tknWidgetConfig.defaultDragEdgeWidth,
        offset = 0,
    }, dragEdgePaddedRelativeOrientation, defaultTransform)

    tknImageNode.addNode(pTknGfxContext, "rightDragEdgeImage", rightDragEdgeNode, 1, relativeOrientation, relativeOrientation, defaultTransform, tknWidgetConfig.color.semiDark, false, false)

    local topDragEdgeNode = ui.addInteractableNode(pTknGfxContext, function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then
            return true
        elseif inputState == input.inputState.up then
            return false
        else
            return false
        end
    end, widget.dragWidget.backgroundNode, 3, "topDragEdgeNode", dragEdgePaddedRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.defaultDragEdgeWidth,
        offset = 0,
    }, defaultTransform)

    tknImageNode.addNode(pTknGfxContext, "topDragEdgeImage", topDragEdgeNode, 1, relativeOrientation, relativeOrientation, defaultTransform, tknWidgetConfig.color.semiDark, false, false)

    local bottomDragEdgeNode = ui.addInteractableNode(pTknGfxContext, function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateDragWidgetColor then
            tknWidgetConfig.updateDragWidgetColor(node, xNdc, yNdc, inputState)
        end
        if inputState == input.inputState.down then
            return true
        elseif inputState == input.inputState.up then
            return false
        else
            return false
        end
    end, widget.dragWidget.backgroundNode, 4, "bottomDragEdgeNode", dragEdgePaddedRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = tknWidgetConfig.defaultDragEdgeWidth,
        offset = 0,
    }, defaultTransform)

    tknImageNode.addNode(pTknGfxContext, "bottomDragEdgeImage", bottomDragEdgeNode, 1, relativeOrientation, relativeOrientation, defaultTransform, tknWidgetConfig.color.semiDark, false, false)

    local innerRelativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = tknWidgetConfig.defaultDragEdgeWidth,
        maxOffset = -tknWidgetConfig.defaultDragEdgeWidth,
        offset = 0,
    }
    local innerParentNode = ui.addNode(pTknGfxContext, widget.dragWidget.backgroundNode, 5, "innerParentNode", innerRelativeOrientation, innerRelativeOrientation, defaultTransform)
    local titleBackgroundNode = tknImageNode.addNode(pTknGfxContext, "titleBackgroundNode", innerParentNode, 1, relativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.defaultSmallButtonHeight + tknWidgetConfig.defaultSpacing * 2,
        offset = 0,
    }, defaultTransform, tknWidgetConfig.color.semiDarker, false, true)

    widget.titleNode = tknTextNode.addNode(pTknGfxContext, "titleNode", titleBackgroundNode, 1, paddedRelativeOrientation, relativeOrientation, defaultTransform, title or "Window Title", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0.5, false)

    widget.closeButtonWidget = tknButtonWidget.addWidget(pTknGfxContext, "closeButtonWidget", titleBackgroundNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = tknWidgetConfig.defaultSmallButtonHeight,
        offset = -tknWidgetConfig.defaultSpacing,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.defaultSmallButtonHeight,
        offset = 0,
    }, function()
        ui.setNodeTransformActive(widget.dragWidget.backgroundNode, false)
    end)
    tknTextNode.addNode(pTknGfxContext, "closeButtonTextNode", widget.closeButtonWidget.backgroundNode, 1, paddedRelativeOrientation, relativeOrientation, defaultTransform, "\xee\xae\x98", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0.5, 0.5, false)
    --  tknWidgetConfig.color.semiDark, tknWidgetConfig.color.semiLight, tknWidgetConfig.color.semiDark, "\xee\xae\x98", tknWidgetConfig.normalFontSize)

    widget.fullScreenButtonWidget = tknButtonWidget.addWidget(pTknGfxContext, "fullScreenButtonWidget", titleBackgroundNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = tknWidgetConfig.defaultSmallButtonHeight,
        offset = -tknWidgetConfig.defaultSpacing * 2 - tknWidgetConfig.defaultSmallButtonHeight,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.defaultSmallButtonHeight,
        offset = 0,
    }, function()
    end)
    tknTextNode.addNode(pTknGfxContext, "fullScreenButtonTextNode", widget.fullScreenButtonWidget.backgroundNode, 1, paddedRelativeOrientation, relativeOrientation, defaultTransform, "\xef\x93\x8e", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0.5, 0.5, false)
    -- tknWidgetConfig.color.semiDark, tknWidgetConfig.color.semiLight, tknWidgetConfig.color.semiDark, "", tknWidgetConfig.normalFontSize

    widget.contentParentNode = ui.addNode(pTknGfxContext, innerParentNode, 2, "contentParentNode", relativeOrientation, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = tknWidgetConfig.defaultSmallButtonHeight + tknWidgetConfig.defaultSpacing * 2,
        maxOffset = 0,
        offset = 0,
    }, defaultTransform)

    widget.uiDetailScrollView = tknScrollViewWidget.addWidget(pTknGfxContext, "uiDetailScrollView", widget.contentParentNode, 1, relativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 512,
        offset = 0,
    }, relativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 1024,
        offset = 0,
    })

    widget.uiTreeScrollView = tknScrollViewWidget.addWidget(pTknGfxContext, "uiTreeScrollView", widget.contentParentNode, 1, relativeOrientation, {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = 512,
        maxOffset = 0,
        offset = 0,
    }, relativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 1024,
        offset = 0,
    })
    return widget
end

function tknWindowWidget.removeWidget(pTknGfxContext, widget)

end

return tknWindowWidget
