local ui = require("ui.ui")
local uiDefault = {}

function uiDefault.setup(pTknGfxContext)
    uiDefault.image = ui.loadImage(pTknGfxContext, "/textures/uiDefault.astc")
    uiDefault.cornerRadiusPreset = {
        none = "none",
        xsmall = "xsmall",
        small = "small",
        medium = "medium",
        large = "large",
    }
    uiDefault.cornerRadiusPresetToRadius = {
        none = 4,
        xsmall = 8,
        small = 16,
        medium = 32,
        large = 64,
    }
    uiDefault.cornerRadiusPresetToFitMode = {}
    for cornerRadiusPreset, padding in pairs(uiDefault.cornerRadiusPresetToRadius) do
        uiDefault.cornerRadiusPresetToFitMode[cornerRadiusPreset] = {
            type = ui.fitModeType.sliced,
            horizontal = {
                minPadding = padding,
                maxPadding = padding,
            },
            vertical = {
                minPadding = padding,
                maxPadding = padding,
            },
        }
    end
    uiDefault.cornerRadiusPresetToUv = {
        none = {
            u0 = 0.96875,
            v0 = 0.0,
            u1 = 1.0,
            v1 = 0.0625,
        },
        xsmall = {
            u0 = 0.875,
            v0 = 0.0,
            u1 = 0.9375,
            v1 = 0.125,
        },
        small = {
            u0 = 0.75,
            v0 = 0.0,
            u1 = 0.875,
            v1 = 0.25,
        },
        medium = {
            u0 = 0.5,
            v0 = 0.0,
            u1 = 0.75,
            v1 = 0.5,
        },
        large = {
            u0 = 0.0,
            v0 = 0.0,
            u1 = 0.5,
            v1 = 1.0,
        },
    }

end

function uiDefault.teardown(pTknGfxContext)
    ui.unloadImage(pTknGfxContext, uiDefault.image)
    uiDefault.image = nil
    uiDefault.cornerRadiusPresetToRadius = nil
    uiDefault.cornerRadiusPresetToFitMode = nil
    uiDefault.cornerRadiusPresetToUv = nil
end

function uiDefault.getSprite(cornerRadiusPreset)
    return uiDefault.image, uiDefault.cornerRadiusPresetToFitMode[cornerRadiusPreset], uiDefault.cornerRadiusPresetToUv[cornerRadiusPreset], uiDefault.cornerRadiusPresetToRadius[cornerRadiusPreset]
end

return uiDefault
