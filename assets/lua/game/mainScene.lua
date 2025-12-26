local mainScene = {}
local ui = require("ui.ui")
local input = require("input")
function mainScene.start(game, pTknGfxContext, assetsPath)
    mainScene.backgroundImage = ui.loadImage(pTknGfxContext, "/textures/default.astc")
    print("Creating FIT type container node")
    mainScene.backgroundNode = ui.addNode(pTknGfxContext, ui.rootNode, 1, "mainSceneRoot", {
        dirty = true,
        horizontal = {
            type = "relative",
            pivot = 0.5,
            minOffset = 50,
            maxOffset = -50,
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = "relative",
            pivot = 0.5,
            minOffset = 50,
            maxOffset = -50,
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
    })
    local fitMode = {
        type = "Contain",
    }
    -- Add background image to visualize the fit container
    ui.addImageComponent(pTknGfxContext, 0xFFFFFFFF, fitMode, mainScene.backgroundImage, mainScene.backgroundNode)

    mainScene.buttonNode = ui.addNode(pTknGfxContext, mainScene.backgroundNode, 1, "startButton", {
        dirty = true,
        horizontal = {
            type = "anchored",
            anchor = 0.5,
            pivot = 0.5,
            length = 256,
            offset = 0,
            scale = 1,
        },
        vertical = {
            type = "anchored",
            anchor = 0.5,
            pivot = 0.5,
            length = 128,
            offset = 0,
            scale = 1,
        },
        rotation = 0,
    })
    ui.addButtonComponent(pTknGfxContext, function(component, xNDC, yNDC, inputState)
        if inputState == input.inputState.down then
            print("Button pressed!")
            component.overrideColor = 0xFFAAAAAA
            component.node.layout.horizontal.scale = 0.8
        elseif inputState == input.inputState.up then
            print("Button released!")
            component.overrideColor = nil
            component.node.layout.horizontal.scale = 1
        else
            -- Do nothing
        end
    end, mainScene.buttonNode)

    mainScene.buttonBackground = ui.addNode(pTknGfxContext, mainScene.buttonNode, 1, "buttonBackground", {
        dirty = true,
        horizontal = {
            type = "relative",
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = "relative",
            pivot = 0.5,
            minOffset = 0,
            maxOffset = 0,
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
    })
    local fitMode = {
        type = "Cover",
    }
    -- Add background image to visualize the fit container
    ui.addImageComponent(pTknGfxContext, 0xFFFFFFFF, fitMode, mainScene.backgroundImage, mainScene.buttonBackground)
end

function mainScene.stop(game)
end

function mainScene.stopGfx(game, pTknGfxContext)
    mainScene.pDefaultImageMaterial = nil
    ui.unloadImage(pTknGfxContext, mainScene.backgroundImage)
    print("Tearing down render pipeline")
end

function mainScene.update(game)
end

function mainScene.updateGfx(game, pTknGfxContext, width, height)
    return mainScene
end

return mainScene
