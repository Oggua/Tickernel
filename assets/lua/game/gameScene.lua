local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local buttonWidget = require("ui.buttonWidget")

local function addButton(game, pTknGfxContext, name, text, layout, callback)
    local callback = function(node, xNDC, yNDC, inputState)
        print("Button input received: ", name, ui.rectContainsPoint(node.rect, xNDC, yNDC))
        if ui.rectContainsPoint(node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                node.overrideColor = 0xFFAAAAAA
                node.layout.horizontal.scale = 0.95
                node.layout.vertical.scale = 0.95
                return true
            elseif inputState == input.inputState.up then
                node.overrideColor = nil
                node.layout.horizontal.scale = 1
                node.layout.vertical.scale = 1
                if callback then
                    callback()
                end
                return false
            else
                return false
            end
        else
            node.overrideColor = nil
            node.layout.horizontal.scale = 1
            node.layout.vertical.scale = 1
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                return false
            else
                return false
            end
        end
    end
    local buttonNode = ui.addInteractableNode(pTknGfxContext, callback, mainScene.mainSceneRootNode, 1, name, layout)
    mainScene.nameToButtonWidget[name] = buttonNode

    local backgroundNodeLayout = {
        dirty = true,
        horizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
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
    local backgroundNode = ui.addImageNode(pTknGfxContext, buttonNode, 1, "buttonBackground", backgroundNodeLayout, 0xFFFFFFFF, backgroundNodeFitMode, game.uiDefaultImage, require("atlas.uiDefault").circle16x16)
    local textNodeLayout = {
        dirty = true,
        horizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
    }
    local textNode = ui.addTextNode(pTknGfxContext, backgroundNode, 1, "buttonText", textNodeLayout, text, game.font, 24, 0xFF323232, 0.5, 0.5, true)
end

function mainScene.start(game, pTknGfxContext, assetsPath)
    mainScene.nameToButtonWidget = {}
    mainScene.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon2k.astc")
    print("Creating FIT type container node")
    local mainSceneRootNodeLayout = {
        dirty = true,
        horizontal = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = ui.layoutType.relative,
            pivot = 0.5,
            minOffset = 32,
            maxOffset = -32,
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
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
    mainScene.mainSceneRootNode = ui.addImageNode(pTknGfxContext, ui.rootNode, 1, "mainSceneRoot", mainSceneRootNodeLayout, 0xFFFFFFFF, mainSceneRootNodeFitMode, mainScene.backgroundImage, mainSceneRootNodeUV)

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
    local startButtonWidget = buttonWidget.addButtonWidget(pTknGfxContext, "startButton", mainScene.mainSceneRootNode, 1, {
        dirty = true,
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 512,
            offset = 0,
            scale = 1,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = 0,
            scale = 1,
        },
        rotation = 0,
    }, function()
        game.switchScene(gameScene)
    end, game.uiDefaultImage, buttonImageUV, buttonImageFitMode, 0x323232CD, game.font, "Start Game", 24, 0xFFFFFFFF)

    local settingButtonWidget = buttonWidget.addButtonWidget(pTknGfxContext, "settingButton", mainScene.mainSceneRootNode, 2, {
        dirty = true,
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 512,
            offset = 0,
            scale = 1,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = 96,
            scale = 1,
        },
        rotation = 0,
    }, function()
        game.switchScene(nil)
    end, game.uiDefaultImage, buttonImageUV, buttonImageFitMode, 0x323232CD, game.font, "Settings", 24, 0xFFFFFFFF)

    local quitButtonWidget = buttonWidget.addButtonWidget(pTknGfxContext, "quitButton", mainScene.mainSceneRootNode, 3, {
        dirty = true,
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 512,
            offset = 0,
            scale = 1,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = 192,
            scale = 1,
        },
        rotation = 0,
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
