local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
local gameScene = require("game.gameScene")
local function addButton(game, pTknGfxContext, name, text, layout, callback)
    local buttonNode = ui.addNode(pTknGfxContext, mainScene.mainSceneRootNode, 1, name, layout)
    mainScene.nameToButton[name] = buttonNode
    ui.addInteractableComponent(pTknGfxContext, function(component, xNDC, yNDC, inputState)
        print("Button input received: ", name, ui.rectContainsPoint(component.node.rect, xNDC, yNDC))
        if ui.rectContainsPoint(component.node.rect, xNDC, yNDC) then
            if inputState == input.inputState.down then
                component.overrideColor = 0xFFAAAAAA
                component.node.layout.horizontal.scale = 0.95
                component.node.layout.vertical.scale = 0.95
                return true
            elseif inputState == input.inputState.up then
                component.overrideColor = nil
                component.node.layout.horizontal.scale = 1
                component.node.layout.vertical.scale = 1
                if callback then
                    callback()
                end
                return false
            else
                return false
            end
        else
            component.overrideColor = nil
            component.node.layout.horizontal.scale = 1
            component.node.layout.vertical.scale = 1
            if inputState == input.inputState.down then
                return true
            elseif inputState == input.inputState.up then
                return false
            else
                return false
            end
        end
    end, buttonNode)

    local backgroundNode = ui.addNode(pTknGfxContext, buttonNode, 1, "buttonBackground", {
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
    })

    local fitMode = {
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
    -- Add background image to visualize the fit container
    ui.addImageComponent(pTknGfxContext, 0xFFFFFFFF, fitMode, game.uiDefaultImage, require("atlas.uiDefault").circle32x32, backgroundNode)

    local textNode = ui.addNode(pTknGfxContext, backgroundNode, 1, "buttonText", {
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
    })
    ui.addTextComponent(pTknGfxContext, text, game.font, 24, 0xFF323232, 0.5, 0.5, true, textNode)
end

function mainScene.start(game, pTknGfxContext, assetsPath)
    mainScene.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon1.astc")
    print("Creating FIT type container node")
    mainScene.mainSceneRootNode = ui.addNode(pTknGfxContext, ui.rootNode, 1, "mainSceneRoot", {
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
    })
    local fitMode = {
        type = ui.fitModeType.cover,
    }
    local uv = {
        u0 = 0,
        v0 = 0,
        u1 = 1,
        v1 = 1,
    }
    ui.addImageComponent(pTknGfxContext, 0xFFFFFFFF, fitMode, mainScene.backgroundImage, uv, mainScene.mainSceneRootNode)
    mainScene.nameToButton = {}
    addButton(game, pTknGfxContext, "startButton", "Start Game", {
        dirty = true,
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 256,
            offset = 0,
            scale = 1,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = -48,
            scale = 1,
        },
        rotation = 0,
    }, function()
        game.switchScene(gameScene)
    end)
    addButton(game, pTknGfxContext, "quitButton", "Quit Game", {
        dirty = true,
        horizontal = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 256,
            offset = 0,
            scale = 1,
        },
        vertical = {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = 64,
            offset = 48,
            scale = 1,
        },
        rotation = 0,
    }, function()
        game.switchScene(nil)
    end)
end

function mainScene.stop(game)
end

function mainScene.stopGfx(game, pTknGfxContext)
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
