local tkn = require("tkn")
local tknRenderPipeline = require("tknRenderPipeline")
local ui = require("ui")
local format = require("format")
local input = require("input")
local tknEngine = {}

function tknEngine.start(pGfxContext, assetsPath)
    print("Lua start")
    tknEngine.assetsPath = assetsPath
    format.createLayouts(pGfxContext)
    local renderPassIndex = 0
    tknRenderPipeline.setup(pGfxContext, assetsPath, format.voxelVertexFormat.pVertexInputLayout, format.instanceFormat.pVertexInputLayout, renderPassIndex)

    local pGlobalUniformBuffer = {
        view = {0.7071, -0.4082, 0.5774, 0, 0, 0.8165, 0.5774, 0, -0.7071, -0.4082, 0.5774, 0, 0, 0, -8.6603, 1},
        proj = {1.3584, 0, 0, 0, 0, 2.4142, 0, 0, 0, 0, -1.0020, -1, 0, 0, -0.2002, 0},
        inv_view_proj = {0.5206, 0, -0.5206, 0, -0.3007, 0.6013, -0.3007, 0, 0.0231, 0.0231, 0.0231, 0, 2.3077, 4.3301, 2.3077, 43.301},
        pointSizeFactor = 1000.0,
        time = 0.0,
        frameCount = 0,
        near = 0.1,
        far = 100.0,
        fov = 90.0,
    }
    tknEngine.pGlobalUniformBuffer = tkn.createUniformBufferPtr(pGfxContext, format.globalUniformBufferFormat, pGlobalUniformBuffer)
    local inputBindings = {{
        vkDescriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pUniformBuffer = tknEngine.pGlobalUniformBuffer,
        binding = 0,
    }}
    tknEngine.pGlobalMaterial = tkn.getGlobalMaterialPtr(pGfxContext)
    tkn.updateMaterialPtr(pGfxContext, tknEngine.pGlobalMaterial, inputBindings)

    local pLightsUniformBuffer = {
        directionalLightColor = {1.0, 1.0, 0.9, 1.0},
        directionalLightDirection = {0.5, -1.0, 0.3, 0.0},
        pointLights = {},
        pointLightCount = 0,
    }
    for i = 1, 128 * 8 do
        table.insert(pLightsUniformBuffer.pointLights, 0.0)
    end
    tknEngine.pLightsUniformBuffer = tkn.createUniformBufferPtr(pGfxContext, format.lightsUniformBufferFormat, pLightsUniformBuffer)

    local deferredRenderPass = tknRenderPipeline.deferredRenderPass
    tknEngine.pLightingMaterial = tkn.getSubpassMaterialPtr(pGfxContext, deferredRenderPass.pRenderPass, 1)
    local lightingInputBindings = {{
        vkDescriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pUniformBuffer = tknEngine.pLightsUniformBuffer,
        binding = 3,
    }}
    tkn.updateMaterialPtr(pGfxContext, tknEngine.pLightingMaterial, lightingInputBindings)

    local vertices = {
        position = {-1.0, -1.0, 0.0, 1.0, -1.0, 0.0, 0.0, 1.0, 0.0},
        color = {0xFF0000FF, 0xFF00FF00, 0xFFFF0000},
        normal = {0x1, 0x0, 0x0},
    }

    tknEngine.pMesh = tkn.createMeshPtrWithData(pGfxContext, format.voxelVertexFormat.pVertexInputLayout, format.voxelVertexFormat, vertices, 0, nil)
    local instances = {
        model = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
    }
    tknEngine.pInstance = tkn.createInstancePtr(pGfxContext, format.instanceFormat.pVertexInputLayout, format.instanceFormat, instances)

    local deferredRenderPass = tknRenderPipeline.deferredRenderPass
    tknEngine.pGeometryDrawCall = tkn.createDrawCallPtr(pGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, tknEngine.pMesh, tknEngine.pInstance)
    tkn.insertDrawCallPtr(tknEngine.pGeometryDrawCall, 0)

    renderPassIndex = renderPassIndex + 1
    ui.setup(pGfxContext, tknRenderPipeline.pSwapchainAttachment, assetsPath, renderPassIndex)

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
            min = 50,      -- 50 pixels left padding
            max = 50,     -- 50 pixels right padding
            offset = 0,
            scale = 1.0,
        },
        vertical = {
            type = "fit",
            pivot = 0.5,
            min = 50,       -- 50 pixels top padding
            max = 50,    -- 50 pixels bottom padding
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
    tknEngine.pLightingMaterial = nil
    print("Tearing down render pipeline")
    tkn.destroyUniformBufferPtr(pGfxContext, tknEngine.pGlobalUniformBuffer)
    tknEngine.pGlobalUniformBuffer = nil
    tkn.destroyUniformBufferPtr(pGfxContext, tknEngine.pLightsUniformBuffer)
    tknEngine.pLightsUniformBuffer = nil
    tknRenderPipeline.teardown(pGfxContext)
    format.destroyLayouts(pGfxContext)
end

function tknEngine.updateGameplay()
    print("Lua updateGameplay")
end

local idx = 1
function tknEngine.updateUI(pGfxContext)
    local spaceKeyState = input.getKeyState(input.keyCode.space)
    if spaceKeyState == input.keyState.up then
        print("Space key: Creating FIT type image node")
        local newNode = ui.addNode(pGfxContext, ui.rootNode, idx, "fitImageNode", {
            dirty = true,
            horizontal = {
                type = "fit",
                pivot = 0.5,
                min = 50,      -- 50 pixels left padding
                max = 50,     -- 50 pixels right padding
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = "fit",
                pivot = 0.5,
                min = 50,       -- 50 pixels top padding
                max = 50,    -- 50 pixels bottom padding
                offset = 0,
                scale = 1.0,
            },
            rotation = 0,
        })
        ui.addImageComponent(pGfxContext, 0xFFFFFFFF, nil, tknEngine.pDefaultImageMaterial, newNode)
        idx = idx + 1
    end

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
                max = 0.7,
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = "relative",
                pivot = 0,
                min = 0,
                max = 0.8,
                offset = 0,
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
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = "anchored",
                anchor = 0,
                pivot = 0,
                length = 150,
                offset = 0,
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
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = "anchored",
                anchor = 1,
                pivot = 1,
                length = 150,
                offset = 0,
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
                offset = 0,
                scale = 1.0,
            },
            vertical = {
                type = "anchored",
                anchor = 1,
                pivot = 1,
                length = 150,
                offset = 0,
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
