local ui = require("ui.ui")
local widgetConfig = require("engine.widgets.widgetConfig")
local sliderWidget = require("engine.widgets.sliderWidget")
local colorPreset = require("ui.colorPreset")
local mainPanel = {}

function mainPanel.create(pTknGfxContext, game, parent, startButtonCallback, settingsButtonCallback, quitButtonCallback)
    local panel = {}
    panel.rootNode = ui.addNode(pTknGfxContext, parent, 1, "mainPanelRoot", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    })

    local startButtonWidget = widgetConfig.addButtonWidget(pTknGfxContext, "startButton", panel.rootNode, 1, {
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

    local settingButtonWidget = widgetConfig.addButtonWidget(pTknGfxContext, "settingButton", panel.rootNode, 2, {
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

    local quitButtonWidget = widgetConfig.addButtonWidget(pTknGfxContext, "quitButton", panel.rootNode, 3, {
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

    local customSliderWidget = widgetConfig.addSliderWidget(pTknGfxContext, "customSlider", panel.rootNode, 4, {
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
    }, 64, sliderWidget.direction.vertical, function(value)
        -- print("Slider value changed to: " .. tostring(value))
    end)
    -- sliderWidget.setHandleLength(customSliderWidget, 0.2)

    local sv = widgetConfig.addScrollViewWidget(pTknGfxContext, "customScrollView", panel.rootNode, 5, {
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
        offset = -400,
    }, function(value)
        -- print("ScrollView value changed to: " .. tostring(value))
    end)

    panel.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon2k.astc")
    local rootNode = ui.addImageNode(pTknGfxContext, sv.contentNode, 1, "mainPanelRoot", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }, 0xFFFFFFFF, 0, {
        type = ui.fitModeType.cover,
    }, panel.backgroundImage, {
        u0 = 0,
        v0 = 0,
        u1 = 1,
        v1 = 1,
    }, nil)

    return panel
end

function mainPanel.destroy(panel, pTknGfxContext)
    ui.removeNode(pTknGfxContext, panel.rootNode)
    panel.rootNode = nil
    ui.unloadImage(pTknGfxContext, panel.backgroundImage)
    panel.backgroundImage = nil
end

return mainPanel
