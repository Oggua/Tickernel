local ui = require("ui.ui")
local input = require("input")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local tknWidgetConfig = {}

function tknWidgetConfig.setup(pTknGfxContext, assetsPath)
    -- Color presets
    tknWidgetConfig.color = {
        semiDarker = colorPreset.semiDarker,
        semiDark = colorPreset.semiDark,
        semiLight = colorPreset.semiLight,
        semiLighter = colorPreset.semiLighter,
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

    -- Rounded square sprite preset (use small radius variant)
    tknWidgetConfig.roundedImage, tknWidgetConfig.roundedImageFitMode, tknWidgetConfig.roundedImageUv, tknWidgetConfig.roundedCornerRadius = uiDefault.getSprite(uiDefault.cornerRadiusPreset.small)
    -- Extra preset: sharp square (no radius)
    tknWidgetConfig.squareImage, tknWidgetConfig.squareImageFitMode, tknWidgetConfig.squareImageUv, tknWidgetConfig.squareCornerRadius = uiDefault.getSprite(uiDefault.cornerRadiusPreset.none)

    tknWidgetConfig.font = ui.loadFont(pTknGfxContext, {"/fonts/Monaco.ttf", "/fonts/RemixIcon.ttf"}, 32, 2048, {32, 0})
    tknWidgetConfig.smallFontSize = 16
    tknWidgetConfig.normalFontSize = 22
    tknWidgetConfig.largeFontSize = 28

    tknWidgetConfig.defaultAlphaThreshold = 0.02
    tknWidgetConfig.defaultSliderWidth = 32
    tknWidgetConfig.defaultToggleHandleScale = 0.6
    tknWidgetConfig.defaultSmallButtonHeight = 32
    tknWidgetConfig.defaultNormalButtonHeight = 48
    tknWidgetConfig.defaultDropdownHeight = 48
    tknWidgetConfig.defaultToggleHeight = 32
    tknWidgetConfig.defaultDragEdgeWidth = 8
    tknWidgetConfig.defaultSpacing = 8
end

function tknWidgetConfig.teardown(pTknGfxContext)
    ui.unloadFont(pTknGfxContext, tknWidgetConfig.font)
    tknWidgetConfig.smallFontSize = nil
    tknWidgetConfig.normalFontSize = nil
    tknWidgetConfig.largeFontSize = nil

    tknWidgetConfig.defaultAlphaThreshold = nil
    tknWidgetConfig.defaultSliderWidth = nil
    tknWidgetConfig.defaultToggleHandleScale = nil
    tknWidgetConfig.defaultNormalButtonHeight = nil
    tknWidgetConfig.defaultToggleHeight = nil
    tknWidgetConfig.defaultDropdownHeight = nil
    tknWidgetConfig.defaultDragEdgeWidth = nil
    tknWidgetConfig.defaultSpacing = nil

    tknWidgetConfig.font = nil
    tknWidgetConfig.smallFontSize = nil
    tknWidgetConfig.normalFontSize = nil
    tknWidgetConfig.largeFontSize = nil
    tknWidgetConfig.roundedImage = nil
    tknWidgetConfig.roundedImageFitMode = nil
    tknWidgetConfig.roundedImageUv = nil
    tknWidgetConfig.roundedCornerRadius = nil
    tknWidgetConfig.squareImage = nil
    tknWidgetConfig.squareImageFitMode = nil
    tknWidgetConfig.squareImageUv = nil
    tknWidgetConfig.squareCornerRadius = nil
    tknWidgetConfig.color = nil

    uiDefault.unload(pTknGfxContext)

    tknWidgetConfig.updateDragWidgetColor = nil
    tknWidgetConfig.updateClickWidgetColor = nil
end

return tknWidgetConfig
