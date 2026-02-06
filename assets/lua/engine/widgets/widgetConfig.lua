local ui = require("ui.ui")
local input = require("input")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local buttonWidget = require("engine.widgets.buttonWidget")
local sliderWidget = require("engine.widgets.sliderWidget")
local toggleWidget = require("engine.widgets.toggleWidget")
local scrollViewWidget = require("engine.widgets.scrollViewWidget")
local dragWidget = require("engine.widgets.dragWidget")
local widgetConfig = {}

function widgetConfig.setup(pTknGfxContext, assetsPath)
    widgetConfig.color = {
        darker = 0x000000CC,
        dark = 0x1A1A1ACC,
        light = 0xCCCCCCCC,
        lighter = 0xFFFFFFCC,
    }

    widgetConfig.updateClickWidgetColor = function(node, xNdc, yNdc, inputState)
        if ui.rectContainsPoint(node.rect, xNdc, yNdc) then
            if inputState == input.inputState.down then
                ui.setNodeTransformColor(node, colorPreset.light)
            else
                ui.setNodeTransformColor(node, colorPreset.white)
            end
        else
            ui.setNodeTransformColor(node, colorPreset.white)
        end
    end

    widgetConfig.updateDragWidgetColor = function(node, xNdc, yNdc, inputState)
        if inputState == input.inputState.down then
            ui.setNodeTransformColor(node, colorPreset.light)
        else
            ui.setNodeTransformColor(node, colorPreset.white)
        end
    end

    uiDefault.load(pTknGfxContext, assetsPath)

    widgetConfig.image, widgetConfig.imageFitMode, widgetConfig.imageUv, widgetConfig.cornerRadius = uiDefault.getSprite(uiDefault.cornerRadiusPreset.small)

    widgetConfig.font = ui.loadFont(pTknGfxContext, {"/fonts/Monaco.ttf", "/fonts/RemixIcon.ttf"}, 32, 2048, {32, 0})
    widgetConfig.smallFontSize = 18
    widgetConfig.normalFontSize = 24
    widgetConfig.largeFontSize = 32
end

function widgetConfig.teardown(pTknGfxContext)
    ui.unloadFont(pTknGfxContext, widgetConfig.font)
    widgetConfig.font = nil
    widgetConfig.smallFontSize = nil
    widgetConfig.normalFontSize = nil
    widgetConfig.largeFontSize = nil
    widgetConfig.image = nil
    widgetConfig.imageFitMode = nil
    widgetConfig.imageUv = nil
    widgetConfig.cornerRadius = nil

    widgetConfig.color = nil

    uiDefault.unload(pTknGfxContext)

    widgetConfig.updateDragWidgetColor = nil
    widgetConfig.updateClickWidgetColor = nil

    widgetConfig = nil
end

function widgetConfig.addButtonWidget(pTknGfxContext, name, parent, index, horizontal, vertical, text, onClick)
    local newButtonWidget = buttonWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widgetConfig.image, widgetConfig.imageFitMode, widgetConfig.imageUv, widgetConfig.color.dark, widgetConfig.font, text, widgetConfig.normalFontSize, widgetConfig.color.lighter, widgetConfig.updateClickWidgetColor, onClick)
    return newButtonWidget
end

function widgetConfig.removeButtonWidget(pTknGfxContext, widget)
    buttonWidget.removeWidget(pTknGfxContext, widget)
end

function widgetConfig.addSliderWidget(pTknGfxContext, name, parent, index, horizontal, vertical, handleLength, direction, onValueChange)
    local newSliderWidget = sliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widgetConfig.color.dark, widgetConfig.image, widgetConfig.imageFitMode, widgetConfig.imageUv, widgetConfig.color.lighter, handleLength, direction, widgetConfig.updateDragWidgetColor, onValueChange)
    return newSliderWidget
end

function widgetConfig.removeSliderWidget(pTknGfxContext, sliderWidgetToRemove)
    sliderWidget.removeWidget(pTknGfxContext, sliderWidgetToRemove)
end

function widgetConfig.addToggleWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    local newToggleWidget = toggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widgetConfig.color.dark, widgetConfig.image, widgetConfig.imageFitMode, widgetConfig.imageUv, 1, widgetConfig.color.lighter, widgetConfig.updateClickWidgetColor, onValueChange)
    return newToggleWidget
end

function widgetConfig.removeToggleWidget(pTknGfxContext, toggleWidgetToRemove)
    toggleWidget.removeWidget(pTknGfxContext, toggleWidgetToRemove)
end

function widgetConfig.addScrollViewWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    local newScrollViewWidget = scrollViewWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widgetConfig.color.dark, widgetConfig.image, widgetConfig.imageFitMode, widgetConfig.imageUv, widgetConfig.color.lighter, widgetConfig.cornerRadius * 2, widgetConfig.updateDragWidgetColor, onValueChange)
    return newScrollViewWidget
end

function widgetConfig.addDragWidget(pTknGfxContext, name, parent, index, horizontal, vertical)
    local newDragWidget = dragWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widgetConfig.image, widgetConfig.imageFitMode, widgetConfig.imageUv, widgetConfig.color.dark, widgetConfig.updateDragWidgetColor)
    return newDragWidget
end

function widgetConfig.removeDragWidget(pTknGfxContext, dragWidgetToRemove)
    dragWidget.removeWidget(pTknGfxContext, dragWidgetToRemove)
end

function widgetConfig.addBackgroundImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform)
    return ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, widgetConfig.color.darker, 0, widgetConfig.imageFitMode, widgetConfig.image, widgetConfig.imageUv, false)
end

return widgetConfig
