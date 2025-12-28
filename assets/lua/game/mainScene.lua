local mainScene = {}
local ui = require("ui.ui")
local input = require("input")

function mainScene.start(game, pTknGfxContext, assetsPath)
    mainScene.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/pokemon1.astc")
    print("Creating FIT type container node")
    mainScene.backgroundNode = ui.addNode(pTknGfxContext, ui.rootNode, 1, "mainSceneRoot", {
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
            minOffset = 50,
            maxOffset = -50,
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
    ui.addImageComponent(pTknGfxContext, 0xFFFFFFFF, fitMode, mainScene.backgroundImage, uv, mainScene.backgroundNode)

    mainScene.buttonNode = ui.addNode(pTknGfxContext, mainScene.backgroundNode, 1, "startButton", {
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
    ui.addButtonComponent(pTknGfxContext, function(component, xNDC, yNDC, inputState)
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
    end, mainScene.buttonNode)

    mainScene.buttonBackgroundNode = ui.addNode(pTknGfxContext, mainScene.buttonNode, 1, "buttonBackground", {
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
    ui.addImageComponent(pTknGfxContext, 0xFFFFFFFF, fitMode, game.uiDefaultImage, require("atlas.uiDefault").circle32x32, mainScene.buttonBackgroundNode)

    mainScene.textNode = ui.addNode(pTknGfxContext, mainScene.buttonBackgroundNode, 1, "buttonText", {
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

    ui.addTextComponent(pTknGfxContext, "Start", game.font, 32, 0xFF323232, 0.5, 0.5, true, mainScene.textNode)

end

function mainScene.stop(game)
end

function mainScene.stopGfx(game, pTknGfxContext)
    ui.unloadImage(pTknGfxContext, mainScene.backgroundImage)
    print("Tearing down render pipeline")
end

function mainScene.update(game)
end

function mainScene.updateGfx(game, pTknGfxContext, width, height)
    return mainScene
end

return mainScene
