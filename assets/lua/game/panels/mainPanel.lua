local ui = require("ui.ui")
local colorPreset = require("ui.colorPreset")
local buttonWidget = require("ui.widgets.buttonWidget")
local sliderWidget = require("ui.widgets.sliderWidget")
local uiDefault = require("atlas.uiDefault")
local mainPanel = {}

function mainPanel.create(pTknGfxContext, game, parent, startButtonCallback, settingsButtonCallback, quitButtonCallback)
    mainPanel.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon2k.astc")
    local mainPanelRootNodeLayout = {
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
    local mainPanelRootNodeFitMode = {
        type = ui.fitModeType.cover,
    }
    local mainPanelRootNodeUV = {
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
    mainPanel.rootNode = ui.addImageNode(pTknGfxContext, parent, 1, "mainPanelRoot", mainPanelRootNodeLayout.horizontal, mainPanelRootNodeLayout.vertical, rootTransform, colorPreset.white, 0, mainPanelRootNodeFitMode, mainPanel.backgroundImage, mainPanelRootNodeUV, nil)

    local cornerRadiusPreset = uiDefault.cornerRadiusPreset.small
    local startButtonWidget = buttonWidget.addWidget(pTknGfxContext, "startButton", mainPanel.rootNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 512,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 64,
        offset = 0,
    }, startButtonCallback, cornerRadiusPreset, colorPreset.darker, game.font, "Start Game", 24, colorPreset.white)

    local settingButtonWidget = buttonWidget.addWidget(pTknGfxContext, "settingButton", mainPanel.rootNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 512,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 64,
        offset = 96,
    }, settingsButtonCallback, cornerRadiusPreset, colorPreset.darker, game.font, "Settings", 24, colorPreset.white)

    local quitButtonWidget = buttonWidget.addWidget(pTknGfxContext, "quitButton", mainPanel.rootNode, 3, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 512,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 64,
        offset = 192,
    }, quitButtonCallback, cornerRadiusPreset, colorPreset.darker, game.font, "Quit Game", 24, colorPreset.white)

    local customSliderWidget = sliderWidget.addWidget(pTknGfxContext, "customSlider", mainPanel.rootNode, 4, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 32,
        offset = 444,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 512,
        offset = 288,
    }, colorPreset.darker, "small", colorPreset.white, 32, sliderWidget.direction.vertical, function(value)
        -- print("Slider value changed to: " .. tostring(value))
    end)

    return mainPanel
end

function mainPanel.destroy(mainPanel, pTknGfxContext)
    ui.removeNode(pTknGfxContext, mainPanel.rootNode)
    mainPanel.rootNode = nil
    ui.unloadImage(pTknGfxContext, mainPanel.backgroundImage)
    mainPanel.backgroundImage = nil
end

return mainPanel
