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

function tknEngine.updateUI(pGfxContext)
    local aKeyState = input.getKeyState(input.keyCode.a)
    if aKeyState == input.keyState.up then
        print("A key was just released this frame")
        tknEngine.currentNode = ui.addNode(pGfxContext, tknEngine.currentNode, 1, "testNode", {
            dirty = true,
            horizontal = {
                type = "relative",
                left = 100,
                right = 100,
            },
            vertical = {
                type = "relative",
                bottom = 100,
                top = 100,
            },
            rect = {},
        })
        ui.addImageComponent(pGfxContext, 0xFFFFFFFF, nil, tknEngine.pDefaultImageMaterial, tknEngine.currentNode)
    end
    local bKeyState = input.getKeyState(input.keyCode.b)
    if bKeyState == input.keyState.up then
        print("B key was just released this frame")
        tknEngine.currentNode = ui.addNode(pGfxContext, tknEngine.currentNode, 1, "testNode", {
            dirty = true,
            horizontal = {
                type = "relative",
                left = 100,
                right = 100,
            },
            vertical = {
                type = "relative",
                bottom = 100,
                top = 100,
            },
            rect = {},
        })
        ui.addTextComponent(pGfxContext, "HelloWorld!HaChiMi!", tknEngine.font, 32, 0xFFFFFFFF, tknEngine.currentNode)
    end
end

function tknEngine.updateGfx(pGfxContext, width, height)
    tknEngine.updateUI(pGfxContext)
    ui.update(pGfxContext, width, height)
    print("Lua updateGfx")
end

_G.tknEngine = tknEngine
return tknEngine
