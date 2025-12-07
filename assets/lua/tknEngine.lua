local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer/deferredRenderPass")
local ui = require("ui.ui")
local input = require("input")
local tknEngine = {}

function tknEngine.start(pGfxContext, assetsPath)
    print("Lua start")
    tknEngine.assetsPath = assetsPath

    local renderPassIndex = 0
    deferredRenderPass.setup(pGfxContext, assetsPath, renderPassIndex)

    local vertices = {
        position = {-1.0, -1.0, 0.0, 1.0, -1.0, 0.0, 0.0, 1.0, 0.0},
        color = {0xFF0000FF, 0xFF00FF00, 0xFFFF0000},
        normal = {0x1, 0x0, 0x0},
    }

    tknEngine.pMesh = tkn.createMeshPtrWithData(pGfxContext, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.vertexFormat, vertices, 0, nil)
    local instances = {
        model = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
    }
    tknEngine.pInstance = tkn.createInstancePtr(pGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, instances)

    tknEngine.pGeometryDrawCall = tkn.createDrawCallPtr(pGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, tknEngine.pMesh, tknEngine.pInstance)
    tkn.insertDrawCallPtr(tknEngine.pGeometryDrawCall, 0)

    renderPassIndex = renderPassIndex + 1
    ui.setup(pGfxContext, deferredRenderPass.pSwapchainAttachment, assetsPath, renderPassIndex)
    
    tknEngine.pDefaultImage = tkn.createImagePtrWithPath(pGfxContext, assetsPath .. "/textures/default.astc")
    tknEngine.pDefaultImageMaterial = ui.createMaterialPtr(pGfxContext, tknEngine.pDefaultImage, ui.renderPass.pImagePipeline)
    tknEngine.currentNode = ui.rootNode

    tknEngine.font = ui.createFont(pGfxContext, assetsPath .. "/fonts/Monaco.ttf", 32, 2048)

    -- Create FIT container immediately on startup
    print("Creating FIT type container node")
    tknEngine.fitContainer = ui.addNode(pGfxContext, ui.rootNode, 1, "fitContainer", {
        dirty = true,
        horizontal = {
            type = "fit",
            pivot = 0.5,
            min = 50, -- 50 pixels left padding
            max = 50, -- 50 pixels right padding
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = "fit",
            pivot = 0.5,
            min = 50, -- 50 pixels top padding
            max = 50, -- 50 pixels bottom padding
            offset = 0,
            scale = 1.0,
        },
        rotation = 0,
    })
    -- Add background image to visualize the fit container
    ui.addImageComponent(pGfxContext, 0x80808080, nil, tknEngine.pDefaultImageMaterial, tknEngine.fitContainer)
end

function tknEngine.stop()
    print("Lua stop")
end

function tknEngine.stopGfx(pGfxContext)
    print("Lua stopGfx")
    ui.teardown(pGfxContext)
    tknEngine.pDefaultImageMaterial = nil

    tkn.destroyImagePtr(pGfxContext, tknEngine.pDefaultImage)
    print("Destroying draw call and instance")
    tkn.destroyDrawCallPtr(pGfxContext, tknEngine.pGeometryDrawCall)
    tknEngine.pGeometryDrawCall = nil
    tkn.destroyInstancePtr(pGfxContext, tknEngine.pInstance)
    tknEngine.pInstance = nil
    tkn.destroyMeshPtr(pGfxContext, tknEngine.pMesh)
    tknEngine.pMesh = nil
    print("Tearing down render pipeline")
    deferredRenderPass.teardown(pGfxContext)
end

function tknEngine.updateGameplay()
    print("Lua updateGameplay")
end

local idx = 1
function tknEngine.updateUI(pGfxContext)
    -- Q key: Top-Left (child of fit container)
    local qKeyState = input.getKeyState(input.keyCode.q)
    if qKeyState == input.keyState.up then
        print("Q key: Top-Left alignment (child of FIT container)")
        local childIdx = #tknEngine.fitContainer.children + 1
        local newNode = ui.addNode(pGfxContext, tknEngine.fitContainer, childIdx, "textNode_TL", {
            dirty = true,
            horizontal = {
                type = "relative",
                pivot = 0,
                min = 0,
                max = 0.5,
                offset = 100,
                scale = 1.0,
            },
            vertical = {
                type = "relative",
                pivot = 0,
                min = 0,
                max = 0.8,
                offset = 100,
                scale = 1.0,
            },
            rotation = 0,
        })
        ui.addTextComponent(pGfxContext, "Q - Top Left Corner", tknEngine.font, 32, 0xFF00FF00, 0, 0, false, newNode)
    end

    -- E key: Top-Right (child of fit container)
    local eKeyState = input.getKeyState(input.keyCode.e)
    if eKeyState == input.keyState.up then
        print("E key: Top-Right alignment (child of FIT container)")
        local childIdx = #tknEngine.fitContainer.children + 1
        local newNode = ui.addNode(pGfxContext, tknEngine.fitContainer, childIdx, "textNode_TR", {
            dirty = true,
            horizontal = {
                type = "anchored",
                anchor = 1,
                pivot = 1,
                length = 400,
                offset = -100,
                scale = 1.0,
            },
            vertical = {
                type = "anchored",
                anchor = 0,
                pivot = 0,
                length = 150,
                offset = 100,
                scale = 1.0,
            },
            rotation = 0,
        })
        ui.addTextComponent(pGfxContext, "E - Top Right Corner", tknEngine.font, 32, 0xFF0000FF, 1, 0, false, newNode)
    end

    -- Z key: Bottom-Left (child of fit container)
    local zKeyState = input.getKeyState(input.keyCode.z)
    if zKeyState == input.keyState.up then
        print("Z key: Bottom-Left alignment (child of FIT container)")
        local childIdx = #tknEngine.fitContainer.children + 1
        local newNode = ui.addNode(pGfxContext, tknEngine.fitContainer, childIdx, "textNode_BL", {
            dirty = true,
            horizontal = {
                type = "anchored",
                anchor = 0,
                pivot = 0,
                length = 400,
                offset = 100,
                scale = 1.0,
            },
            vertical = {
                type = "anchored",
                anchor = 1,
                pivot = 1,
                length = 150,
                offset = -100,
                scale = 1.0,
            },
            rotation = 0,
        })
        ui.addTextComponent(pGfxContext, "Z - Bottom Left Corner", tknEngine.font, 32, 0xFFFFFF00, 0, 1, false, newNode)
    end

    -- C key: Bottom-Right (child of fit container)
    local cKeyState = input.getKeyState(input.keyCode.c)
    if cKeyState == input.keyState.up then
        print("C key: Bottom-Right alignment (child of FIT container)")
        local childIdx = #tknEngine.fitContainer.children + 1
        local newNode = ui.addNode(pGfxContext, tknEngine.fitContainer, childIdx, "textNode_BR", {
            dirty = true,
            horizontal = {
                type = "anchored",
                anchor = 1,
                pivot = 1,
                length = 400,
                offset = -100,
                scale = 1.0,
            },
            vertical = {
                type = "anchored",
                anchor = 1,
                pivot = 1,
                length = 150,
                offset = -100,
                scale = 1.0,
            },
            rotation = 0,
        })
        ui.addTextComponent(pGfxContext, "C - Bottom Right Corner", tknEngine.font, 32, 0xFFFF00FF, 1, 1, false, newNode)
    end
end

function tknEngine.updateGfx(pGfxContext, width, height)
    tknEngine.updateUI(pGfxContext)
    ui.update(pGfxContext, width, height)
    print("Lua updateGfx")
end

_G.tknEngine = tknEngine
return tknEngine
