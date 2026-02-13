local game = {}
local mainScene = require("game.mainScene")
local ui = require("ui.ui")
local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local input = require("input")

local camera = {
    x = 0.0,
    y = 20.0,
    z = 30.0,
    yaw = -math.pi / 2,
    pitch = -0.98,
    near = 0.1,
    far = 1000.0,
    fov = 90.0,
    moveSpeed = 1.0,
    rotateSpeed = 0.03,
}

local function isKeyDown(key)
    return input.getKeyState(key) == input.inputState.down
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function cross(ax, ay, az, bx, by, bz)
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function normalize(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 0.000001 then
        return 0.0, 0.0, 0.0
    end
    return x / len, y / len, z / len
end

local function dot(ax, ay, az, bx, by, bz)
    return ax * bx + ay * by + az * bz
end

local function buildViewMatrix(eyeX, eyeY, eyeZ, centerX, centerY, centerZ)
    local fx, fy, fz = normalize(centerX - eyeX, centerY - eyeY, centerZ - eyeZ)
    local sx, sy, sz = cross(fx, fy, fz, 0.0, 0.0, 1.0)
    sx, sy, sz = normalize(sx, sy, sz)
    local ux, uy, uz = cross(fx, fy, fz, sx, sy, sz)

    return {sx, ux, -fx, 0, sy, uy, -fy, 0, sz, uz, -fz, 0, -dot(sx, sy, sz, eyeX, eyeY, eyeZ), -dot(ux, uy, uz, eyeX, eyeY, eyeZ), dot(fx, fy, fz, eyeX, eyeY, eyeZ), 1}
end

local function buildProjMatrix(fovDeg, aspect, near, far)
    local f = 1.0 / math.tan(math.rad(fovDeg) * 0.5)
    return {f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) / (near - far), -1, 0, 0, (2.0 * far * near) / (near - far), 0}
end

local function updateCameraInput()
    if isKeyDown(input.keyCode.left) then
        camera.yaw = camera.yaw - camera.rotateSpeed
    end
    if isKeyDown(input.keyCode.right) then
        camera.yaw = camera.yaw + camera.rotateSpeed
    end
    if isKeyDown(input.keyCode.up) then
        camera.pitch = camera.pitch + camera.rotateSpeed
    end
    if isKeyDown(input.keyCode.down) then
        camera.pitch = camera.pitch - camera.rotateSpeed
    end

    camera.pitch = clamp(camera.pitch, -1.45, 1.45)

    local forwardX = math.cos(camera.pitch) * math.cos(camera.yaw)
    local forwardY = math.cos(camera.pitch) * math.sin(camera.yaw)
    local forwardZ = math.sin(camera.pitch)
    forwardX, forwardY, forwardZ = normalize(forwardX, forwardY, forwardZ)

    local rightX, rightY, rightZ = cross(forwardX, forwardY, forwardZ, 0.0, 0.0, 1.0)
    rightX, rightY, rightZ = normalize(rightX, rightY, rightZ)

    local speed = camera.moveSpeed
    if isKeyDown(input.keyCode.w) then
        camera.x = camera.x + forwardX * speed
        camera.y = camera.y + forwardY * speed
        camera.z = camera.z + forwardZ * speed
    end
    if isKeyDown(input.keyCode.s) then
        camera.x = camera.x - forwardX * speed
        camera.y = camera.y - forwardY * speed
        camera.z = camera.z - forwardZ * speed
    end
    if isKeyDown(input.keyCode.d) then
        camera.x = camera.x + rightX * speed
        camera.y = camera.y + rightY * speed
        camera.z = camera.z + rightZ * speed
    end
    if isKeyDown(input.keyCode.a) then
        camera.x = camera.x - rightX * speed
        camera.y = camera.y - rightY * speed
        camera.z = camera.z - rightZ * speed
    end
    if isKeyDown(input.keyCode.e) then
        camera.z = camera.z + speed
    end
    if isKeyDown(input.keyCode.q) then
        camera.z = camera.z - speed
    end
end

function game.start(pTknGfxContext, pSwapchainAttachment, pDepthStencilAttachment, renderPassIndex, assetsPath, gameRootNode)
    deferredRenderPass.setup(pTknGfxContext, assetsPath, renderPassIndex, pDepthStencilAttachment, pSwapchainAttachment)
    game.assetsPath = assetsPath
    game.currentScene = mainScene
    game.nextScene = mainScene
    game.gameRootNode = gameRootNode
    game.currentScene.start(game, pTknGfxContext)
end

function game.stop()
    game.currentScene.stop(game)
end

function game.stopGfx(pTknGfxContext)
    game.currentScene.stopGfx(game, pTknGfxContext)
    game.currentScene = nil
    deferredRenderPass.teardown(pTknGfxContext)
end

-- Returns: nil = quit, self = continue, other scene = switch
function game.update()
    game.currentScene.update(game)
end

local function updateCamera(pTknGfxContext, width, height)
    updateCameraInput()

    local forwardX = math.cos(camera.pitch) * math.cos(camera.yaw)
    local forwardY = math.cos(camera.pitch) * math.sin(camera.yaw)
    local forwardZ = math.sin(camera.pitch)

    local view = buildViewMatrix(camera.x, camera.y, camera.z, camera.x + forwardX, camera.y + forwardY, camera.z + forwardZ)

    local aspect = (height ~= 0) and (width / height) or (16.0 / 9.0)
    local proj = buildProjMatrix(camera.fov, aspect, camera.near, camera.far)

    tkn.tknUpdateUniformBufferPtr(pTknGfxContext, deferredRenderPass.pGlobalUniformBuffer, deferredRenderPass.globalUniformBufferFormat, {
        view = view,
        proj = proj,
        pointSizeFactor = 1000.0,
        time = 0.0,
        frameCount = 0,
        near = camera.near,
        far = camera.far,
        fov = camera.fov,
    }, nil)
    -- local inputBindings = {{
    --     vkDescriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
    --     pTknUniformBuffer = deferredRenderPass.pGlobalUniformBuffer,
    --     binding = 0,
    -- }}
    -- deferredRenderPass.pGlobalMaterial = tkn.tknGetGlobalMaterialPtr(pTknGfxContext)
    -- tkn.tknUpdateMaterialPtr(pTknGfxContext, deferredRenderPass.pGlobalMaterial, inputBindings)
end

-- Called after waitRenderFence, handles GPU resources and scene switching
function game.updateGfx(pTknGfxContext, width, height)
    updateCamera(pTknGfxContext, width, height)
    game.currentScene.updateGfx(game, pTknGfxContext, width, height)

    local shouldQuit = false
    -- Check if scene wants to switch (set by update)
    if game.nextScene == nil then
        shouldQuit = true
    else
        if game.nextScene ~= game.currentScene then
            -- Switch scene: cleanup old, setup new
            game.currentScene.stop(game)
            game.currentScene.stopGfx(game, pTknGfxContext)
            game.currentScene = game.nextScene
            game.currentScene.start(game, pTknGfxContext, game.assetsPath)
            game.currentScene.updateGfx(game, pTknGfxContext, width, height)
        end
    end
    return shouldQuit
end

function game.switchScene(nextScene)
    game.nextScene = nextScene
end

function game.recordFrame(pTknGfxContext, pTknFrame)
    tkn.tknBeginRenderPassPtr(pTknGfxContext, pTknFrame, deferredRenderPass.pTknRenderPass)
    game.currentScene.recordFrame(game, pTknGfxContext, pTknFrame)
    tkn.tknNextSubpassPtr(pTknGfxContext, pTknFrame)
    tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, deferredRenderPass.pLightingDrawCall)
    tkn.tknEndRenderPassPtr(pTknGfxContext, pTknFrame)
end

return game
