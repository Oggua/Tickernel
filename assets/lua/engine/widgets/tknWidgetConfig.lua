local ui = require("ui.ui")
local input = require("input")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknSliderWidget = require("engine.widgets.tknSliderWidget")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local tknScrollViewWidget = require("engine.widgets.tknScrollViewWidget")
local tknDragWidget = require("engine.widgets.tknDragWidget")
local tknWidgetConfig = {}

function tknWidgetConfig.setup(pTknGfxContext, assetsPath)

    tknWidgetConfig.updateClickWidgetColor = function(node, xNdc, yNdc, inputState)
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

    tknWidgetConfig.updateDragWidgetColor = function(node, xNdc, yNdc, inputState)
        if inputState == input.inputState.down then
            ui.setNodeTransformColor(node, colorPreset.light)
        else
            ui.setNodeTransformColor(node, colorPreset.white)
        end
    end

    uiDefault.load(pTknGfxContext, assetsPath)

    tknWidgetConfig.image, tknWidgetConfig.imageFitMode, tknWidgetConfig.imageUv, tknWidgetConfig.cornerRadius = uiDefault.getSprite(uiDefault.cornerRadiusPreset.small)

    tknWidgetConfig.font = ui.loadFont(pTknGfxContext, {"/fonts/Monaco.ttf", "/fonts/RemixIcon.ttf"}, 32, 2048, {32, 0})
    tknWidgetConfig.smallFontSize = 18
    tknWidgetConfig.normalFontSize = 24
    tknWidgetConfig.largeFontSize = 32
end

function tknWidgetConfig.teardown(pTknGfxContext)
    ui.unloadFont(pTknGfxContext, tknWidgetConfig.font)
    tknWidgetConfig.font = nil
    tknWidgetConfig.smallFontSize = nil
    tknWidgetConfig.normalFontSize = nil
    tknWidgetConfig.largeFontSize = nil
    tknWidgetConfig.image = nil
    tknWidgetConfig.imageFitMode = nil
    tknWidgetConfig.imageUv = nil
    tknWidgetConfig.cornerRadius = nil

    uiDefault.unload(pTknGfxContext)

    tknWidgetConfig.updateDragWidgetColor = nil
    tknWidgetConfig.updateClickWidgetColor = nil
end

function tknWidgetConfig.addButtonWidget(pTknGfxContext, name, parent, index, horizontal, vertical, text, onClick)
    local newButtonWidget = tknButtonWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, tknWidgetConfig.image, tknWidgetConfig.imageFitMode, tknWidgetConfig.imageUv, colorPreset.semiDark, tknWidgetConfig.font, text, tknWidgetConfig.normalFontSize, colorPreset.semiLighter, tknWidgetConfig.updateClickWidgetColor, onClick)
    return newButtonWidget
end

function tknWidgetConfig.removeButtonWidget(pTknGfxContext, widget)
    tknButtonWidget.removeWidget(pTknGfxContext, widget)
end

function tknWidgetConfig.addSliderWidget(pTknGfxContext, name, parent, index, horizontal, vertical, handleLength, direction, onValueChange)
    local newSliderWidget = tknSliderWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, colorPreset.semiDark, tknWidgetConfig.image, tknWidgetConfig.imageFitMode, tknWidgetConfig.imageUv, colorPreset.semiLighter, handleLength, direction, tknWidgetConfig.updateDragWidgetColor, onValueChange)
    return newSliderWidget
end

function tknWidgetConfig.removeSliderWidget(pTknGfxContext, sliderWidgetToRemove)
    tknSliderWidget.removeWidget(pTknGfxContext, sliderWidgetToRemove)
end

function tknWidgetConfig.addToggleWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    local newToggleWidget = tknToggleWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, colorPreset.semiDark, tknWidgetConfig.image, tknWidgetConfig.imageFitMode, tknWidgetConfig.imageUv, 1, colorPreset.semiLighter, tknWidgetConfig.updateClickWidgetColor, onValueChange)
    return newToggleWidget
end

function tknWidgetConfig.removeToggleWidget(pTknGfxContext, toggleWidgetToRemove)
    tknToggleWidget.removeWidget(pTknGfxContext, toggleWidgetToRemove)
end

function tknWidgetConfig.addScrollViewWidget(pTknGfxContext, name, parent, index, horizontal, vertical, onValueChange)
    local newScrollViewWidget = tknScrollViewWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, colorPreset.semiDark, tknWidgetConfig.image, tknWidgetConfig.imageFitMode, tknWidgetConfig.imageUv, colorPreset.semiLighter, tknWidgetConfig.cornerRadius * 2, tknWidgetConfig.updateDragWidgetColor, onValueChange)
    return newScrollViewWidget
end

function tknWidgetConfig.addDragWidget(pTknGfxContext, name, parent, index, horizontal, vertical)
    local newDragWidget = tknDragWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, tknWidgetConfig.image, tknWidgetConfig.imageFitMode, tknWidgetConfig.imageUv, colorPreset.semiDark, tknWidgetConfig.updateDragWidgetColor)
    return newDragWidget
end

function tknWidgetConfig.removeDragWidget(pTknGfxContext, dragWidgetToRemove)
    tknDragWidget.removeWidget(pTknGfxContext, dragWidgetToRemove)
end

function tknWidgetConfig.addBackgroundImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform)
    return ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, colorPreset.semiDarker, 0, tknWidgetConfig.imageFitMode, tknWidgetConfig.image, tknWidgetConfig.imageUv, false)
end

return tknWidgetConfig
