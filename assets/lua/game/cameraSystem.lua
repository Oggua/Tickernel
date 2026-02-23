local cameraSystem = {}

local tkn = require("tkn")
local input = require("input")
local tknMath = require("tknMath")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")

-- local function buildViewMatrix(eyeX, eyeY, eyeZ, centerX, centerY, centerZ)
--     local fx, fy, fz = tknMath.normalize3D(centerX - eyeX, centerY - eyeY, centerZ - eyeZ)
--     local sx, sy, sz = tknMath.cross3D(fx, fy, fz, 0.0, 0.0, 1.0)
--     sx, sy, sz = tknMath.normalize3D(sx, sy, sz)
--     local ux, uy, uz = tknMath.cross3D(fx, fy, fz, sx, sy, sz)

--     return {sx, ux, -fx, 0, sy, uy, -fy, 0, sz, uz, -fz, 0, -tknMath.dot3D(sx, sy, sz, eyeX, eyeY, eyeZ), -tknMath.dot3D(ux, uy, uz, eyeX, eyeY, eyeZ), tknMath.dot3D(fx, fy, fz, eyeX, eyeY, eyeZ), 1}
-- end

-- local function buildProjMatrix(fovDeg, aspect, near, far)
--     local f = 1.0 / math.tan(math.rad(fovDeg) * 0.5)
--     return {f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) / (near - far), -1, 0, 0, (2.0 * far * near) / (near - far), 0}
-- end

-- local function updateCameraInput()
--     if (input.getKeyState(input.keyCode.left) == input.inputState.down) then
--         camera.yaw = camera.yaw - camera.rotateSpeed
--     end
--     if (input.getKeyState(input.keyCode.right) == input.inputState.down) then
--         camera.yaw = camera.yaw + camera.rotateSpeed
--     end
--     if (input.getKeyState(input.keyCode.up) == input.inputState.down) then
--         camera.pitch = camera.pitch + camera.rotateSpeed
--     end
--     if (input.getKeyState(input.keyCode.down) == input.inputState.down) then
--         camera.pitch = camera.pitch - camera.rotateSpeed
--     end

--     camera.pitch = tknMath.clamp(camera.pitch, -1.45, 1.45)

--     -- 水平面上的前进方向（只考虑yaw，pitch不影响水平移动）
--     local forwardX = math.cos(camera.yaw)
--     local forwardY = math.sin(camera.yaw)

--     -- 右方向 = cross(forward, up) 在XY平面上的投影
--     local rightX = math.sin(camera.yaw)
--     local rightY = -math.cos(camera.yaw)

--     local speed = camera.moveSpeed
--     if (input.getKeyState(input.keyCode.w) == input.inputState.down) then
--         camera.x = camera.x + forwardX * speed
--         camera.y = camera.y + forwardY * speed
--         -- z不变
--     end
--     if (input.getKeyState(input.keyCode.s) == input.inputState.down) then
--         camera.x = camera.x - forwardX * speed
--         camera.y = camera.y - forwardY * speed
--         -- z不变
--     end
--     if (input.getKeyState(input.keyCode.d) == input.inputState.down) then
--         camera.x = camera.x + rightX * speed
--         camera.y = camera.y + rightY * speed
--         -- z不变
--     end
--     if (input.getKeyState(input.keyCode.a) == input.inputState.down) then
--         camera.x = camera.x - rightX * speed
--         camera.y = camera.y - rightY * speed
--         -- z不变
--     end
--     if (input.getKeyState(input.keyCode.e) == input.inputState.down) then
--         camera.z = camera.z + speed
--     end
--     if (input.getKeyState(input.keyCode.q) == input.inputState.down) then
--         camera.z = camera.z - speed
--     end
-- end

-- function cameraSystem.update(pTknGfxContext, width, height, sizeFactor)
--     updateCameraInput()
--     camera.screenWidth = width
--     camera.screenHeight = height
--     -- Use focal-length (pixels) from vertical FOV to map world-unit voxel size -> pixels:
--     -- f = 1 / tan(fov/2), focal pixels = (screenHeight / 2) * f
--     local f = 1.0 / math.tan(math.rad(camera.fov) * 0.5)
--     camera.pointSize = (camera.screenHeight * 0.5 * f) * sizeFactor

--     local forwardX = math.cos(camera.pitch) * math.cos(camera.yaw)
--     local forwardY = math.cos(camera.pitch) * math.sin(camera.yaw)
--     local forwardZ = math.sin(camera.pitch)

--     local view = buildViewMatrix(camera.x, camera.y, camera.z, camera.x + forwardX, camera.y + forwardY, camera.z + forwardZ)
--     local aspect = (height ~= 0) and (width / height) or (16.0 / 9.0)
--     local proj = buildProjMatrix(camera.fov, aspect, camera.near, camera.far)

--     local focalX = camera.screenWidth * proj[1] * 0.5 -- proj[1] == m00 (f/aspect)
--     local focalY = camera.screenHeight * proj[6] * 0.5 -- proj[6] == m11 (f)
--     local focal = math.max(focalX, focalY)
--     camera.pointSize = focal * sizeFactor

--     tkn.tknUpdateUniformBufferPtr(pTknGfxContext, deferredRenderPass.pGlobalUniformBuffer, deferredRenderPass.globalUniformBufferFormat, {
--         view = view,
--         proj = proj,
--         pointSize = camera.pointSize,
--         time = 0.0,
--         frameCount = 0,
--         near = camera.near,
--         far = camera.far,
--         fov = camera.fov,
--         screenWidth = camera.screenWidth,
--         screenHeight = camera.screenHeight,
--     }, nil)
-- end

local function updateViewAndProj(camera, screenWidth, screenHeight)
    -- Resolve eye position
    local eyeX, eyeY, eyeZ
    eyeX = camera.transform.position.x or 0
    eyeY = camera.transform.position.y or 0
    eyeZ = camera.transform.position.z or 0

    -- compute forward by rotating local +X (1,0,0) by quaternion
    local q = camera.transform.rotation
    local qx, qy, qz, qw = q.x or 0, q.y or 0, q.z or 0, q.w or 1
    -- t = 2 * cross(q.xyz, v) where v = (1,0,0)
    local tx = 0
    local ty = 2 * qz
    local tz = -2 * qy
    -- v' = v + qw * t + cross(q.xyz, t)
    local cx = qy * tz - qz * ty
    local cy = qz * tx - qx * tz
    local cz = qx * ty - qy * tx
    local fx = 1 + qw * tx + cx
    local fy = 0 + qw * ty + cy
    local fz = 0 + qw * tz + cz
    fx, fy, fz = tknMath.normalize3D(fx, fy, fz)

    -- Up vector for Z-up
    local upX, upY, upZ = 0.0, 0.0, 1.0

    local sx, sy, sz = tknMath.cross3D(fx, fy, fz, upX, upY, upZ)
    sx, sy, sz = tknMath.normalize3D(sx, sy, sz)
    local ux, uy, uz = tknMath.cross3D(fx, fy, fz, sx, sy, sz)

    -- write view into existing camera.view array in-place
    camera.view[1] = sx
    camera.view[2] = ux
    camera.view[3] = -fx
    camera.view[4] = 0
    camera.view[5] = sy
    camera.view[6] = uy
    camera.view[7] = -fy
    camera.view[8] = 0
    camera.view[9] = sz
    camera.view[10] = uz
    camera.view[11] = -fz
    camera.view[12] = 0
    camera.view[13] = -tknMath.dot3D(sx, sy, sz, eyeX, eyeY, eyeZ)
    camera.view[14] = -tknMath.dot3D(ux, uy, uz, eyeX, eyeY, eyeZ)
    camera.view[15] = tknMath.dot3D(fx, fy, fz, eyeX, eyeY, eyeZ)
    camera.view[16] = 1

    local aspect = screenWidth / screenHeight
    local fov = camera.fov
    local near = camera.near
    local far = camera.far

    local f = 1.0 / math.tan(math.rad(fov) * 0.5)
    camera.proj[1] = f / aspect
    camera.proj[2] = 0
    camera.proj[3] = 0
    camera.proj[4] = 0
    camera.proj[5] = 0
    camera.proj[6] = f
    camera.proj[7] = 0
    camera.proj[8] = 0
    camera.proj[9] = 0
    camera.proj[10] = 0
    camera.proj[11] = (far + near) / (near - far)
    camera.proj[12] = -1
    camera.proj[13] = 0
    camera.proj[14] = 0
    camera.proj[15] = (2.0 * far * near) / (near - far)
    camera.proj[16] = 0
end

function cameraSystem.update(pTknGfxContext, screenWidth, screenHeight)
    -- Only compute view/proj and store them on each camera. Do NOT write to GPU uniforms here.
    for i, camera in ipairs(cameraSystem.cameras) do
        updateViewAndProj(camera, screenWidth, screenHeight)
    end
end

function cameraSystem.add(transform, near, far, fov)
    local camera = {
        transform = transform,
        near = near,
        far = far,
        fov = fov,
        view = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
        proj = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
    }
    table.insert(cameraSystem.cameras, camera)
    return camera
end

function cameraSystem.remove(camera)
    for i, c in ipairs(cameraSystem.cameras) do
        if c == camera then
            table.remove(cameraSystem.cameras, i)
            break
        end
    end
end

function cameraSystem.setup(maxCameraCount)
    cameraSystem.cameras = {}
end

function cameraSystem.teardown()
    for i = #cameraSystem.cameras, 1, -1 do
        cameraSystem.remove(cameraSystem.cameras[i])
    end
    cameraSystem.cameras = nil
end

return cameraSystem
