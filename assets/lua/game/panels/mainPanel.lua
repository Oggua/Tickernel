local ui = require("ui.ui")
local widget = require("ui.widgets.widget")
local sliderWidget = require("ui.widgets.sliderWidget")
local colorPreset = require("ui.colorPreset")
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
    local mainPanelRootNodeUv = {
        u0 = 0,
        v0 = 0,
        u1 = 1,
        v1 = 1,
    }
    local rootTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    mainPanel.rootNode = ui.addImageNode(pTknGfxContext, parent, 1, "mainPanelRoot", mainPanelRootNodeLayout.horizontal, mainPanelRootNodeLayout.vertical, rootTransform, colorPreset.black, 0, mainPanelRootNodeFitMode, mainPanel.backgroundImage, mainPanelRootNodeUv, nil)

    local startButtonWidget = widget.addButtonWidget(pTknGfxContext, "startButton", mainPanel.rootNode, 1, {
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
    }, "Start Game", startButtonCallback)

    local settingButtonWidget = widget.addButtonWidget(pTknGfxContext, "settingButton", mainPanel.rootNode, 2, {
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
    }, "Settings", settingsButtonCallback)

    local quitButtonWidget = widget.addButtonWidget(pTknGfxContext, "quitButton", mainPanel.rootNode, 3, {
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
    }, "Quit Game", quitButtonCallback)

    local customSliderWidget = widget.addSliderWidget(pTknGfxContext, "customSlider", mainPanel.rootNode, 4, {
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
    }, 32, sliderWidget.direction.vertical, function(value)
        -- print("Slider value changed to: " .. tostring(value))
    end)

    local sv = widget.addScrollViewWidget(pTknGfxContext, "customScrollView", mainPanel.rootNode, 5, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 800,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 400,
        offset = -200,
    }, function(value)
        -- print("ScrollView value changed to: " .. tostring(value))
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
