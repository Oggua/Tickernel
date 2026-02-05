local ui = require("ui.ui")
local input = require("input")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local buttonWidget = require("engine.widgets.buttonWidget")
local sliderWidget = require("engine.widgets.sliderWidget")
local toggleWidget = require("engine.widgets.toggleWidget")
local scrollViewWidget = require("engine.widgets.scrollViewWidget")
local dragWidget = require("engine.widgets.dragWidget")
local widget = {}

function widget.setup(pTknGfxContext, assetsPath)
    widget.color = {
        -- background = 0x333333CC,
        -- foreground = 0xCCCCCCFF,
        background = 0x000000CC,
        foreground = 0xFFFFFFCC,
    }

    widget.updateClickWidgetColor = function(node, xNdc, yNdc, inputState)
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

    widget.updateDragWidgetColor = function(node, xNdc, yNdc, inputState)
        if inputState == input.inputState.down then
            ui.setNodeTransformColor(node, colorPreset.light)
        else
            ui.setNodeTransformColor(node, colorPreset.white)
        end
    end

    uiDefault.setup(pTknGfxContext, assetsPath)

    widget.image, widget.imageFitMode, widget.imageUv, widget.cornerRadius = uiDefault.getSprite(uiDefault.cornerRadiusPreset.small)

    widget.font = ui.loadFont(pTknGfxContext, {"/fonts/Monaco.ttf", "/fonts/RemixIcon.ttf"}, 32, 2048)
    widget.smallFontSize = 18
    widget.normalFontSize = 24
    widget.largeFontSize = 32
end

function widget.teardown(pTknGfxContext)
    ui.unloadFont(pTknGfxContext, widget.font)
    widget.font = nil
    widget.smallFontSize = nil
    widget.normalFontSize = nil
    widget.largeFontSize = nil
    widget.image = nil
    widget.imageFitMode = nil
    widget.imageUv = nil
    widget.cornerRadius = nil

    widget.color = nil

    uiDefault.teardown(pTknGfxContext)

    widget.updateDragWidgetColor = nil
    widget.updateClickWidgetColor = nil

    widget = nil
end

function widget.addButtonWidget(pTknGfxContext, name, parent, index, horizontal, vertical, text, onClick)
    local newButtonWidget = buttonWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.image, widget.imageFitMode, widget.imageUv, widget.color.background, widget.font, text, widget.normalFontSize, widget.color.foreground, widget.updateClickWidgetColor, onClick)
    return newButtonWidget
end

function widget.removeButtonWidget(pTknGfxContext, widget)
    buttonWidget.removeWidget(pTknGfxContext, widget)
end

function widget.addSliderWidget(pTknGfxContext, name, parent, index, horizontal, vertical, handleLength, direction, onValueChange)
    local newSliderWidget = sliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.color.background, widget.image, widget.imageFitMode, widget.imageUv, widget.color.foreground, handleLength, direction, widget.updateDragWidgetColor, onValueChange)
    return newSliderWidget
end

function widget.removeSliderWidget(pTknGfxContext, sliderWidgetToRemove)
    sliderWidget.removeWidget(pTknGfxContext, sliderWidgetToRemove)
end

function widget.addToggleWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    local newToggleWidget = toggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.color.background, widget.image, widget.imageFitMode, widget.imageUv, 0.6, widget.color.foreground, widget.updateClickWidgetColor, onValueChange)
    return newToggleWidget
end

function widget.removeToggleWidget(pTknGfxContext, toggleWidgetToRemove)
    toggleWidget.removeWidget(pTknGfxContext, toggleWidgetToRemove)
end

function widget.addScrollViewWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    local newScrollViewWidget = scrollViewWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.color.background, widget.image, widget.imageFitMode, widget.imageUv, widget.color.foreground, widget.cornerRadius * 2, widget.updateDragWidgetColor, onValueChange)
    return newScrollViewWidget
end

function widget.addDragWidget(pTknGfxContext, name, parent, index, horizontal, vertical)
    local newDragWidget = dragWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.image, widget.imageFitMode, widget.imageUv, widget.color.background, widget.updateDragWidgetColor)
    return newDragWidget
end

function widget.removeDragWidget(pTknGfxContext, dragWidgetToRemove)
    dragWidget.removeWidget(pTknGfxContext, dragWidgetToRemove)
end

return widget
