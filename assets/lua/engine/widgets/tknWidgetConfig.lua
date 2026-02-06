local ui = require("ui.ui")
local input = require("input")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local tknWidgetConfig = {}

function tknWidgetConfig.setup(pTknGfxContext, assetsPath)
    -- Color presets
    tknWidgetConfig.color = {
        semiDark = colorPreset.semiDark,
        semiLight = colorPreset.semiLight,
        semiLighter = colorPreset.semiLighter,
        semiDarker = colorPreset.semiDarker,
    }

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

    tknWidgetConfig.defaultAlphaThreshold = 0.02
    tknWidgetConfig.defaultSliderWidth = 32
    tknWidgetConfig.defaultToggleHandleScale = 0.8
    tknWidgetConfig.defaultButtonHeight = 48
    tknWidgetConfig.defaultToggleHeight = 32
    tknWidgetConfig.defaultPadding = 8
end

function tknWidgetConfig.teardown(pTknGfxContext)
    ui.unloadFont(pTknGfxContext, tknWidgetConfig.font)
    tknWidgetConfig.smallFontSize = nil
    tknWidgetConfig.normalFontSize = nil
    tknWidgetConfig.largeFontSize = nil

    tknWidgetConfig.defaultAlphaThreshold = nil
    tknWidgetConfig.defaultSliderWidth = nil
    tknWidgetConfig.defaultToggleHandleScale = nil
    tknWidgetConfig.defaultButtonHeight = nil
    tknWidgetConfig.defaultToggleHeight = nil
    tknWidgetConfig.defaultPadding = nil

    tknWidgetConfig.font = nil
    tknWidgetConfig.smallFontSize = nil
    tknWidgetConfig.normalFontSize = nil
    tknWidgetConfig.largeFontSize = nil
    tknWidgetConfig.image = nil
    tknWidgetConfig.imageFitMode = nil
    tknWidgetConfig.imageUv = nil
    tknWidgetConfig.cornerRadius = nil
    tknWidgetConfig.color = nil

    uiDefault.unload(pTknGfxContext)

    tknWidgetConfig.updateDragWidgetColor = nil
    tknWidgetConfig.updateClickWidgetColor = nil
end

return tknWidgetConfig
