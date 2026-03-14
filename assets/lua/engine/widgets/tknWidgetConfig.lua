local ui = require("ui.ui")
local input = require("input")
local uiDefault = require("atlas.uiDefault")
local colorPreset = require("ui.colorPreset")
local tknWidgetConfig = {}

function tknWidgetConfig.setup(pTknGfxContext, assetsPath)
    -- Color presets
    tknWidgetConfig.color = {
        darker = colorPreset.darker,
        semiDarker = colorPreset.semiDarker,
        semiDark = colorPreset.semiDark,
        semiLight = colorPreset.semiLight,
        semiLighter = colorPreset.semiLighter,
        inverseSemiDarker = colorPreset.inverseSemiDarker,
        inverseSemiDark = colorPreset.inverseSemiDark,
        inverseSemiLighter = colorPreset.inverseSemiLighter,
        inverseSemiLight = colorPreset.inverseSemiLight,
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
    tknWidgetConfig.smallFontSize = 14
    tknWidgetConfig.normalFontSize = 20
    tknWidgetConfig.largeFontSize = 26

    tknWidgetConfig.smallInteractableWidth = 32
    tknWidgetConfig.largeInteractableWidth = 48

    tknWidgetConfig.defaultAlphaThreshold = 0.02
    tknWidgetConfig.defaultToggleHandleScale = 0.6
    tknWidgetConfig.defaultDragEdgeWidth = 8
    tknWidgetConfig.defaultSpacing = 8

    tknWidgetConfig.fullRelativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    tknWidgetConfig.paddedRelativeOrientation = {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = tknWidgetConfig.defaultSpacing,
        maxOffset = -tknWidgetConfig.defaultSpacing,
        offset = 0,
    }
    tknWidgetConfig.defaultTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
end

function tknWidgetConfig.teardown(pTknGfxContext)
    tknWidgetConfig.fullRelativeOrientation = nil
    tknWidgetConfig.paddedRelativeOrientation = nil
    tknWidgetConfig.defaultTransform = nil

    ui.unloadFont(pTknGfxContext, tknWidgetConfig.font)
    tknWidgetConfig.smallFontSize = nil
    tknWidgetConfig.normalFontSize = nil
    tknWidgetConfig.largeFontSize = nil

    tknWidgetConfig.largeInteractableWidth = nil
    tknWidgetConfig.smallInteractableWidth = nil

    tknWidgetConfig.defaultAlphaThreshold = nil
    tknWidgetConfig.defaultToggleHandleScale = nil
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
