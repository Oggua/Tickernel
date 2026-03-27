local cameraSystem = {}

local tkn = require("tkn")
local input = require("input")
local tknMath = require("tknMath")
local deferredRenderPass = require("game.deferredRenderer.deferredRenderPass")
local transformSystem = require("game.transformSystem")

local function updateViewAndProj(camera, screenWidth, screenHeight)
    -- Resolve eye position
    local eyeX, eyeY, eyeZ
    eyeX = camera.transform.position[1] or 0
    eyeY = camera.transform.position[2] or 0
    eyeZ = camera.transform.position[3] or 0

    -- compute forward by rotating local +X (1,0,0) by quaternion
    local q = camera.transform.rotation
    local qx, qy, qz, qw = q[1] or 0, q[2] or 0, q[3] or 0, q[4] or 1
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

    -- Left-handed: right = cross(up, forward), up' = cross(forward, right)
    local sx, sy, sz = tknMath.cross3D(upX, upY, upZ, fx, fy, fz)
    sx, sy, sz = tknMath.normalize3D(sx, sy, sz)
    -- try alternate up = cross(right, forward) to match engine handedness
    local ux, uy, uz = tknMath.cross3D(sx, sy, sz, fx, fy, fz)

    -- write view into existing camera.view array in-place (left-handed view)
    camera.view[1] = sx
    camera.view[2] = ux
    camera.view[3] = fx
    camera.view[4] = 0
    camera.view[5] = sy
    camera.view[6] = uy
    camera.view[7] = fy
    camera.view[8] = 0
    camera.view[9] = sz
    camera.view[10] = uz
    camera.view[11] = fz
    camera.view[12] = 0
    camera.view[13] = -tknMath.dot3D(sx, sy, sz, eyeX, eyeY, eyeZ)
    camera.view[14] = -tknMath.dot3D(ux, uy, uz, eyeX, eyeY, eyeZ)
    camera.view[15] = -tknMath.dot3D(fx, fy, fz, eyeX, eyeY, eyeZ)
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

function cameraSystem.add(px, py, pz, rx, ry, rz, rw, parentTransform, near, far, fov)
    local transform = transformSystem.add(px, py, pz, rx, ry, rz, rw, 1, 1, 1, parentTransform, nil)
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
    transformSystem.remove(camera.transform)
    camera.transform = nil
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
