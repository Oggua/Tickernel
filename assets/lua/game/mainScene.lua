local mainScene = {}
local ui = require("ui.ui")
local tkn = require("tkn")
function mainScene.start(game, pGfxContext, assetsPath)
    mainScene.pDefaultImage = tkn.tknCreateImagePtrWithPath(pGfxContext, assetsPath .. "/textures/default.astc")
    mainScene.pDefaultImageMaterial = ui.createMaterialPtr(pGfxContext, mainScene.pDefaultImage, ui.renderPass.pImagePipeline)
    mainScene.currentNode = ui.rootNode
    print("Creating FIT type container node")
    mainScene.fitContainer = ui.addNode(pGfxContext, ui.rootNode, 1, "mainSceneRoot", {
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
    -- Add background image to visualize the fit container
    ui.addImageComponent(pGfxContext, 0xFFFFFFFF, nil, mainScene.pDefaultImageMaterial, mainScene.fitContainer)
end

function mainScene.stop(game)
end

function mainScene.stopGfx(game, pGfxContext)
    mainScene.pDefaultImageMaterial = nil
    tkn.tknDestroyImagePtr(pGfxContext, mainScene.pDefaultImage)

    print("Tearing down render pipeline")
end

function mainScene.update(game)
end

function mainScene.updateGfx(game, pGfxContext, width, height)
    return mainScene
end

return mainScene
