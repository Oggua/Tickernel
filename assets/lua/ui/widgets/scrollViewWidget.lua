local ui = require("ui.ui")
local input = require("input")
local tknMath = require("tknMath")
local sliderWidget = require("ui.widgets.sliderWidget")
local scrollViewWidget = {}

function scrollViewWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, backgroundColor, image, imageFitMode, imageUv, handleOffset, handleColor, animate, onValueChange)
    local widget = {}
    local processInput = function(node, xNdc, yNdc, inputState)
        if animate then
            animate(node, xNdc, yNdc, inputState)
        end
        -- Scroll view specific input handling would go here
        return false
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

    widget.contentNode = ui.addNode(pTknGfxContext, widget.scrollViewBackgroundNode, 1, "scrollViewContent", {
        type = ui.layoutType.fit,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        type = ui.layoutType.fit,
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
    })

    local backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon2k.astc")
    local mainPanelRootNodeLayout = {
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 1920,
            offset = 0,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 1080,
            offset = 0,
        },
    }
    local mainPanelRootNodeFitMode = {
        type = ui.fitModeType.cover,
    }
    local mainPanelRootNodeUv = {
        u0 = 0,
        v0 = 0,
        u1 = 1,
        v1 = 1,
    }
    local rootTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    ui.addImageNode(pTknGfxContext, widget.contentNode, 1, "mainPanelRoot", mainPanelRootNodeLayout.horizontal, mainPanelRootNodeLayout.vertical, rootTransform, 0xFFFFFFFF, 0, mainPanelRootNodeFitMode, backgroundImage, mainPanelRootNodeUv, nil)

    widget.rightSliderWidget = sliderWidget.addWidget(pTknGfxContext, "rightScrollViewSlider", widget.scrollViewBackgroundNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = handleOffset * 2,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = -handleOffset * 2,
        offset = 0,
    }, backgroundColor, image, imageFitMode, imageUv, handleOffset, handleColor, 32, sliderWidget.direction.vertical, animate, function(value)

    end)

    widget.bottomSliderWidget = sliderWidget.addWidget(pTknGfxContext, "bottomScrollViewSlider", widget.scrollViewBackgroundNode, 3, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = -handleOffset * 2,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = handleOffset * 2,
        offset = 0,
    }, backgroundColor, image, imageFitMode, imageUv, handleOffset, handleColor, 32, sliderWidget.direction.horizontal, animate, function(value)

    end)
    return widget
end

function scrollViewWidget.removeWidget(pTknGfxContext, scrollViewWidget)
    sliderWidget.removeWidget(pTknGfxContext, scrollViewWidget.bottomSliderWidget)
    sliderWidget.removeWidget(pTknGfxContext, scrollViewWidget.rightSliderWidget)
    ui.removeNode(pTknGfxContext, scrollViewWidget.scrollViewNode)
    scrollViewWidget.scrollViewNode = nil
    scrollViewWidget.scrollViewBackgroundNode = nil
end

return scrollViewWidget
