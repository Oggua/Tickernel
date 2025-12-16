local mainScene = {}
local ui = require("ui.ui")

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
        type = "Cover",
    }
    -- Add background image to visualize the fit container
    ui.addImageComponent(pTknGfxContext, 0xFFFFFFFF, fitMode, mainScene.backgroundImage, mainScene.backgroundNode)
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
