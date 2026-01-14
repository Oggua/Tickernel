local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local buttonWidget = require("ui.widgets.buttonWidget")

local function addButton(game, pTknGfxContext, name, text, layout, callback)
    local callback = function(node, xNDC, yNDC, inputState)
        print("Button input received: ", name, ui.rectContainsPoint(node.rect, xNDC, yNDC))
        if ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                node.transform.color = 0xFFAAAAAA
                return true
            elseif inputState == input.inputState.up then
                node.transform.color = nil
                if callback then
                    callback()
                end
                return false
            else
                return false
            end
        else
            node.transform.color = nil
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                return false
            else
                return false
            end
        end
    end
    local buttonTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = 0xFFFFFFFF,
        active = true,
    }
    local buttonNode = ui.addInteractableNode(pTknGfxContext, callback, mainScene.mainSceneRootNode, 1, name, layout.horizontal, layout.vertical, buttonTransform)
    mainScene.nameToButtonWidget[name] = buttonNode

    -- Directly use horizontal/vertical for background node, no need for extra layout object
    local backgroundHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local backgroundVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local backgroundNodeFitMode = {
        type = ui.fitModeType.sliced,
        horizontal = {
            minPadding = 16,
            maxPadding = 16,
        },
        vertical = {
            minPadding = 16,
            maxPadding = 16,
        },
    }
    local backgroundTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = 0xFFFFFFFF,
        active = true,
    }
    local backgroundNode = ui.addImageNode(pTknGfxContext, buttonNode, 1, "buttonBackground", backgroundHorizontal, backgroundVertical, backgroundTransform, 0xFFFFFFFF, backgroundNodeFitMode, game.uiDefaultImage, require("atlas.uiDefault").circle16x16)
    -- Directly use horizontal/vertical for text node, no need for extra layout object
    local textHorizontal = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local textVertical = {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }
    local textTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = 0xFFFFFFFF,
        active = true,
    }
    local textNode = ui.addTextNode(pTknGfxContext, backgroundNode, 1, "buttonText", textHorizontal, textVertical, textTransform, text, game.font, 24, 0xFF323232, 0.5, 0.5, true)
end

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
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 32,
            maxOffset = -32,
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
        color = 0xFFFFFFFF,
        active = true,
    }
    mainScene.mainSceneRootNode = ui.addImageNode(pTknGfxContext, ui.rootNode, 1, "mainSceneRoot", mainSceneRootNodeLayout.horizontal, mainSceneRootNodeLayout.vertical, rootTransform, 0xFFFFFFFF, mainSceneRootNodeFitMode, mainScene.backgroundImage, mainSceneRootNodeUV)

    local buttonImageFitMode = {
        type = ui.fitModeType.sliced,
        horizontal = {
            minPadding = 8,
            maxPadding = 8,
        },
        vertical = {
            minPadding = 8,
            maxPadding = 8,
        },
    }
    local buttonImageUV = require("atlas.uiDefault").circle16x16
    local startButtonWidget = buttonWidget.addWidget(pTknGfxContext, "startButton", mainScene.mainSceneRootNode, 1, {
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
    }, function()
        game.switchScene(gameScene)
    end, game.uiDefaultImage, buttonImageUV, buttonImageFitMode, 0x323232CD, game.font, "Start Game", 24, 0xFFFFFFFF)

    local settingButtonWidget = buttonWidget.addWidget(pTknGfxContext, "settingButton", mainScene.mainSceneRootNode, 2, {
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
    }, function()
        game.switchScene(nil)
    end, game.uiDefaultImage, buttonImageUV, buttonImageFitMode, 0x323232CD, game.font, "Settings", 24, 0xFFFFFFFF)

    local quitButtonWidget = buttonWidget.addWidget(pTknGfxContext, "quitButton", mainScene.mainSceneRootNode, 3, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 512,
        offset = 0,
        scale = 1,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 64,
        offset = 192,
        scale = 1,
    }, function()
        game.switchScene(nil)
    end, game.uiDefaultImage, buttonImageUV, buttonImageFitMode, 0x323232CD, game.font, "退出游戏", 24, 0xFFFFFFFF)
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
