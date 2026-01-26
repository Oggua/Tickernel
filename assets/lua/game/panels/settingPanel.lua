local ui = require("ui.ui")
local colorPreset = require("ui.colorPreset")
local buttonWidget = require("ui.widgets.buttonWidget")
local uiDefault = require("atlas.uiDefault")
local settingPanel = {}
function settingPanel.create(pTknGfxContext, game, parent, backButtonCallback)
    settingPanel.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/settingBackground.astc")
    local settingPanelRootNodeLayout = {
        horizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
        },
    }
    local settingPanelRootNodeFitMode = {
        type = ui.fitModeType.cover,
    }
    local settingPanelRootNodeUV = {
        u0 = 0,
        v0 = 0,
        u1 = 1,
        v1 = 1,
    }
    local rootTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = colorPreset.white,
        active = true,
    }
    settingPanel.rootNode = ui.addImageNode(pTknGfxContext, parent, 1, "settingPanelRoot", settingPanelRootNodeLayout.horizontal, settingPanelRootNodeLayout.vertical, rootTransform, colorPreset.white, 0, settingPanelRootNodeFitMode, settingPanel.backgroundImage, settingPanelRootNodeUV, nil)

    local cornerRadiusPreset = uiDefault.cornerRadiusPreset.small
    local backButtonWidget = buttonWidget.addWidget(pTknGfxContext, "backButton", settingPanel.rootNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 256,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 64,
        offset = -200,
    }, backButtonCallback, cornerRadiusPreset, colorPreset.darker, game.font, "Back", 24, colorPreset.white)
end

function settingPanel.destroy()

end
return settingPanel
