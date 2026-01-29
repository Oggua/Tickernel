local ui = require("ui.ui")
local input = require("input")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local buttonWidget = require("ui.widgets.buttonWidget")
local sliderWidget = require("ui.widgets.sliderWidget")
local toggleWidget = require("ui.widgets.toggleWidget")
local scrollViewWidget = require("ui.widgets.scrollViewWidget")
local widget = {}

function widget.setup(pTknGfxContext, assetsPath)
    widget.color = {
        background = 0x333333CC,
        foreground = 0xCCCCCCFF,
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

    widget.font = ui.loadFont(pTknGfxContext, "/fonts/Hiragino Sans GB.ttc", 32, 2048)
    widget.fontSize = 20
end

function widget.teardown(pTknGfxContext)
    ui.unloadFont(pTknGfxContext, widget.font)
    widget.font = nil
    widget.fontSize = nil

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
    local newButtonWidget = buttonWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.image, widget.imageFitMode, widget.imageUv, widget.color.background, widget.font, text, widget.fontSize, widget.color.foreground, widget.updateClickWidgetColor, onClick)
    return newButtonWidget
end

function widget.removeButtonWidget(pTknGfxContext, buttonWidget)
    buttonWidget.removeWidget(pTknGfxContext, buttonWidget)
end

function widget.addSliderWidget(pTknGfxContext, name, parent, index, horizontal, vertical, handleLength, direction, onValueChange)
    local newSliderWidget = sliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.color.background, widget.image, widget.imageFitMode, widget.imageUv, widget.cornerRadius, widget.color.foreground, handleLength, direction, widget.updateDragWidgetColor, onValueChange)
    return newSliderWidget
end

function widget.removeSliderWidget(pTknGfxContext, sliderWidgetToRemove)
    sliderWidget.removeWidget(pTknGfxContext, sliderWidgetToRemove)
end

function widget.addToggleWidget(pTknGfxContext, name, parent, index, horizontal, vertical, handleScale, onValueChange)
    local newToggleWidget = toggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.color.background, widget.image, widget.imageFitMode, widget.imageUv, handleScale, widget.color.foreground, widget.updateClickWidgetColor, onValueChange)
    return newToggleWidget
end

function widget.removeToggleWidget(pTknGfxContext, toggleWidgetToRemove)
    toggleWidget.removeWidget(pTknGfxContext, toggleWidgetToRemove)
end

function widget.addScrollViewWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    local newScrollViewWidget = scrollViewWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, widget.color.background, widget.image, widget.imageFitMode, widget.imageUv, widget.cornerRadius, widget.color.foreground, handleLength, widget.updateDragWidgetColor, onValueChange)
    return newScrollViewWidget
end

return widget
