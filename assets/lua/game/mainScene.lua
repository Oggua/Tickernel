local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local gameScene = require("game.gameScene")
local buttonWidget = require("ui.widgets.buttonWidget")
local sliderWidget = require("ui.widgets.sliderWidget")

function mainScene.start(game, pTknGfxContext, assetsPath)
    mainScene.nameToButtonWidget = {}
    mainScene.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon2k.astc")
    print("Creating FIT type container node")
    local mainSceneRootNodeLayout = {
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
            minOffset = 32,
            maxOffset = -32,
            offset = 0,
        },
    }
    local mainSceneRootNodeFitMode = {
        type = ui.fitModeType.cover,
    }
    local mainSceneRootNodeUV = {
        u0 = 0,
        v0 = 0,
        u1 = 1,
        v1 = 1,
    }
    local rootTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
    }
    mainScene.mainSceneRootNode = ui.addImageNode(pTknGfxContext, ui.rootNode, 1, "mainSceneRoot", mainSceneRootNodeLayout, rootTransform, 0xFFFFFFFF, mainSceneRootNodeFitMode, mainScene.backgroundImage, mainSceneRootNodeUV)

    local radiusType = buttonWidget.radiusType.small
    local startButtonWidget = buttonWidget.addWidget(pTknGfxContext, "startButton", mainScene.mainSceneRootNode, 1, {
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 512,
            offset = 0,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = 0,
        },
    }, function()
        print("Start Game button clicked")
        -- game.switchScene(gameScene)
    end, radiusType, 0x323232CD, game.font, "Start Game", 24, 0xFFFFFFFF)

    local settingButtonWidget = buttonWidget.addWidget(pTknGfxContext, "settingButton", mainScene.mainSceneRootNode, 2, {
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 512,
            offset = 0,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = 96,
        },
    }, function()
        print("Settings button clicked")
        -- game.switchScene(nil)
    end, radiusType, 0x323232CD, game.font, "Settings", 24, 0xFFFFFFFF)

    local quitButtonWidget = buttonWidget.addWidget(pTknGfxContext, "quitButton", mainScene.mainSceneRootNode, 3, {
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 512,
            offset = 0,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = 192,
        },
    }, function()
        -- game.switchScene(nil)
        print("Quit Game button clicked")
    end, radiusType, 0x323232CD, game.font, "Quit Game", 24, 0xFFFFFFFF)

    local customSliderWidget = sliderWidget.addWidget(pTknGfxContext, "customSlider", mainScene.mainSceneRootNode, 4, {
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.3,
            pivot = 0.5,
            length = 512,
            offset = 0,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 32,
            offset = 288,
        },
    }, 0x555555FF, sliderWidget.radiusType.small)
end

function mainScene.stop(game)
end

function mainScene.stopGfx(game, pTknGfxContext)
    for name, buttonWidget in pairs(mainScene.nameToButtonWidget) do
        buttonWidget.removeButtonWidget(pTknGfxContext, buttonWidget)
    end
    mainScene.nameToButtonWidget = nil
    ui.removeNode(pTknGfxContext, mainScene.mainSceneRootNode)
    mainScene.mainSceneRootNode = nil
    ui.unloadImage(pTknGfxContext, mainScene.backgroundImage)
    mainScene.backgroundImage = nil
end

function mainScene.update(game)
end

function mainScene.updateGfx(game, pTknGfxContext, width, height)

end

return mainScene
