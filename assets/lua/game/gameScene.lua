local gameScene = {}
local ui = require("ui.ui")
local input = require("input")

function gameScene.start(game, pTknGfxContext, assetsPath)
    gameScene.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon1.astc")
    print("Creating FIT type container node")
    local rootNodeLayout = {
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
    local rootNodeFitMode = {
        type = ui.fitModeType.cover,
    }
    local rootNodeUV = {
        u0 = 0,
        v0 = 0,
        u1 = 1,
        v1 = 1,
    }
    gameScene.rootNode = ui.addImageNode(pTknGfxContext, ui.rootNode, 1, "mainSceneRoot", rootNodeLayout, 0xFFFFFFFF, rootNodeFitMode, gameScene.backgroundImage, rootNodeUV)

    gameScene.buttonNode = ui.addNode(pTknGfxContext, gameScene.rootNode, 1, "startButton", {
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
            offset = 0,
            scale = 1,
        },
        rotation = 0,
    })
    ui.addInteractableNode(pTknGfxContext, function(component, xNDC, yNDC, inputState)
        if inputState == input.inputState.down then
            print("Button pressed!")
            component.overrideColor = 0xFFAAAAAA
            component.node.layout.horizontal.scale = 0.95
            component.node.layout.vertical.scale = 0.95
        elseif inputState == input.inputState.up then
            print("Button released!")
            component.overrideColor = nil
            component.node.layout.horizontal.scale = 1
            component.node.layout.vertical.scale = 1
        else
            -- Do nothing
        end
    end, gameScene.buttonNode)

    gameScene.buttonBackgroundNode = ui.addNode(pTknGfxContext, gameScene.buttonNode, 1, "buttonBackground", {
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
    ui.addImageNode(pTknGfxContext, 0xFFFFFFFF, fitMode, game.uiDefaultImage, require("atlas.uiDefault").circle32x32, gameScene.buttonBackgroundNode)

    gameScene.textNode = ui.addNode(pTknGfxContext, gameScene.buttonBackgroundNode, 1, "buttonText", {
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
    ui.addTextNode(pTknGfxContext, "Start", game.font, 32, 0xFF323232, 0.5, 0.5, true, gameScene.textNode)
end

function gameScene.stop(game)
end

function gameScene.stopGfx(game, pTknGfxContext)
    ui.removeNode(pTknGfxContext, gameScene.rootNode)
    gameScene.rootNode = nil
    ui.unloadImage(pTknGfxContext, gameScene.backgroundImage)
    gameScene.backgroundImage = nil
end

function gameScene.update(game)
end

function gameScene.updateGfx(game, pTknGfxContext, width, height)
    return gameScene
end

return gameScene
