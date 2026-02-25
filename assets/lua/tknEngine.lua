local tkn = require("tkn")
local vulkan = require("vulkan")
local ui = require("ui.ui")
local game = require("game.game")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local editorPanel = require("engine.panels.editorPanel")
local transformSystem = require("game.transformSystem")
local cameraSystem = require("game.cameraSystem")
local cameraTransformController = require("cameraTransformController")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")

local tknEngine = {}

local function setupGlobalMaterial(pTknGfxContext)
    tknEngine.globalUniformBufferFormat = {{
        name = "view",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "proj",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "near",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "far",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "fov",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "time",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "frameCount",
        type = tkn.type.int32,
        count = 1,
    }, {
        name = "screenWidth",
        type = tkn.type.int32,
        count = 1,
    }, {
        name = "screenHeight",
        type = tkn.type.int32,
        count = 1,
    }}

    -- Create global uniform buffer
    local pGlobalUniformBuffer = {
        view = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
        proj = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
        near = 2,
        far = 128,
        fov = 90,
        time = 0.0,
        frameCount = 0,
        screenWidth = 800,
        screenHeight = 600,
    }
    tknEngine.pGlobalUniformBuffer = tkn.tknCreateUniformBufferPtr(pTknGfxContext, tknEngine.globalUniformBufferFormat, pGlobalUniformBuffer)
    local inputBindings = {{
        vkDescriptorType = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pTknUniformBuffer = tknEngine.pGlobalUniformBuffer,
        binding = 0,
    }}
    tknEngine.pGlobalMaterial = tkn.tknGetGlobalMaterialPtr(pTknGfxContext)
    tkn.tknUpdateMaterialPtr(pTknGfxContext, tknEngine.pGlobalMaterial, inputBindings)
end
local function teardownGlobalMaterial(pTknGfxContext)
    tkn.tknDestroyUniformBufferPtr(pTknGfxContext, tknEngine.pGlobalUniformBuffer)
    tknEngine.pGlobalUniformBuffer = nil
    tknEngine.pGlobalMaterial = nil
    tknEngine.globalUniformBufferFormat = nil
end
local function updateGlobalMaterial(pTknGfxContext, camera, time, frameCount, screenWidth, screenHeight)
    local view = camera.view
    local proj = camera.proj
    -- Create global uniform buffer
    local pGlobalUniformBuffer = {
        view = view,
        proj = proj,
        near = camera.near,
        far = camera.far,
        fov = camera.fov,
        time = time,
        frameCount = frameCount,
        screenWidth = screenWidth,
        screenHeight = screenHeight,
    }
    -- tknEngine.pGlobalUniformBuffer = tkn.tknCreateUniformBufferPtr(pTknGfxContext, tknEngine.globalUniformBufferFormat, pGlobalUniformBuffer)
    tkn.tknUpdateUniformBufferPtr(pTknGfxContext, tknEngine.pGlobalUniformBuffer, tknEngine.globalUniformBufferFormat, pGlobalUniformBuffer, nil)
    local inputBindings = {{
        vkDescriptorType = vulkan.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        pTknUniformBuffer = tknEngine.pGlobalUniformBuffer,
        binding = 0,
    }}
    tknEngine.pGlobalMaterial = tkn.tknGetGlobalMaterialPtr(pTknGfxContext)
    tkn.tknUpdateMaterialPtr(pTknGfxContext, tknEngine.pGlobalMaterial, inputBindings)
end

local function updateDeferredGeometrySubpassMaterial(pTknGfxContext, camera, screenWidth, screenHeight, sizeFactor)
    camera.screenWidth = screenWidth
    camera.screenHeight = screenHeight
    local aspect = (screenHeight ~= 0) and (screenWidth / screenHeight) or (16.0 / 9.0)
    local focalX = camera.screenWidth * camera.proj[1] * 0.5 -- proj[1] == m00 (f/aspect)
    local focalY = camera.screenHeight * camera.proj[6] * 0.5 -- proj[6] == m11 (f)
    -- print("focalX:", focalX, "focalY:", focalY)
    local focal = math.max(focalX, focalY)
    tkn.tknUpdateUniformBufferPtr(pTknGfxContext, deferredRenderPass.pGeometryUniformBuffer, deferredRenderPass.geometryUniformBufferFormat, {
        pointSize = focal * sizeFactor,
    }, nil)
end

function tknEngine.start(pTknGfxContext, assetsPath)
    tknEngine.assetsPath = assetsPath
    -- Global uniform buffer format (view, projection, etc.)
    local depthVkFormat = tkn.tknGetSupportedFormat(pTknGfxContext, {vulkan.VK_FORMAT_D24_UNORM_S8_UINT, vulkan.VK_FORMAT_D32_SFLOAT_S8_UINT}, vulkan.VK_IMAGE_TILING_OPTIMAL, vulkan.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT)
    tknEngine.pDepthStencilAttachment = tkn.tknCreateDynamicAttachmentPtr(pTknGfxContext, depthVkFormat, vulkan.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, vulkan.VK_IMAGE_ASPECT_DEPTH_BIT, 1)
    tknEngine.pSwapchainAttachment = tkn.tknGetSwapchainAttachmentPtr(pTknGfxContext)
    ui.setup(pTknGfxContext, tknEngine.pSwapchainAttachment, tknEngine.pDepthStencilAttachment, assetsPath, 1)
    tknWidgetConfig.setup(pTknGfxContext, assetsPath)
    tknEngine.gameRootUINode = ui.addNode(pTknGfxContext, ui.rootNode, 1, "TickernelEngine", tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform)
    tknEngine.editorRootUINode = ui.addNode(pTknGfxContext, ui.rootNode, 2, "Editor", tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform)
    tknEngine.editorPanel = editorPanel.create(pTknGfxContext, tknEngine.editorRootUINode)

    deferredRenderPass.setup(pTknGfxContext, assetsPath, 0, tknEngine.pDepthStencilAttachment, tknEngine.pSwapchainAttachment)

    game.start(pTknGfxContext, assetsPath, tknEngine.gameRootUINode)

    setupGlobalMaterial(pTknGfxContext)
    transformSystem.setup()
    cameraSystem.setup()

    tknEngine.cameraTransform = transformSystem.add({10, 0, 0}, {0, 0, 0, 0}, {1, 1, 1}, transformSystem.rootTransform, nil)
    tknEngine.camera = cameraSystem.add(tknEngine.cameraTransform, 2, 256, 90)
end

function tknEngine.stop(pTknGfxContext)
    cameraSystem.remove(tknEngine.camera)
    transformSystem.remove(tknEngine.cameraTransform)

    transformSystem.teardown()
    cameraSystem.teardown()
    game.stop()

    tkn.tknWaitRenderFence(pTknGfxContext)
    game.stopGfx(pTknGfxContext)

    editorPanel.destroy(pTknGfxContext, tknEngine.editorPanel)

    ui.removeNode(pTknGfxContext, tknEngine.editorRootUINode)
    ui.removeNode(pTknGfxContext, tknEngine.gameRootUINode)
    tknWidgetConfig.teardown(pTknGfxContext)
    ui.teardown(pTknGfxContext)

    teardownGlobalMaterial(pTknGfxContext)
    deferredRenderPass.teardown(pTknGfxContext)

    tkn.tknDestroyDynamicAttachmentPtr(pTknGfxContext, tknEngine.pDepthStencilAttachment)
    tknEngine.pDepthStencilAttachment = nil
    tknEngine.pSwapchainAttachment = nil

end

function tknEngine.update(pTknGfxContext, width, height)
    game.update()
    cameraTransformController.update(tknEngine.cameraTransform)
    transformSystem.update()
    cameraSystem.update(pTknGfxContext, width, height)
    updateGlobalMaterial(pTknGfxContext, tknEngine.camera, 0, 0, width, height)
    updateDeferredGeometrySubpassMaterial(pTknGfxContext, tknEngine.camera, width, height, 1.0)
    tkn.tknWaitRenderFence(pTknGfxContext)
    local shouldQuit = game.updateGfx(pTknGfxContext, width, height)
    ui.update(pTknGfxContext, width, height)
    return shouldQuit
end

function tknEngine.recordFrame(pTknGfxContext, pTknFrame)
    tkn.tknBeginRenderPassPtr(pTknGfxContext, pTknFrame, deferredRenderPass.pTknRenderPass)
    game.recordFrame(pTknGfxContext, pTknFrame)
    tkn.tknNextSubpassPtr(pTknGfxContext, pTknFrame)
    tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, deferredRenderPass.pLightingDrawCall)
    tkn.tknEndRenderPassPtr(pTknGfxContext, pTknFrame)
    ui.recordFrame(pTknGfxContext, pTknFrame)
end

_G.tknEngine = tknEngine
return tknEngine
