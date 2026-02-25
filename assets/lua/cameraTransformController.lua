local input = require("input")
local transformSystem = require("game.transformSystem")
local tknMath = require("tknMath")
local cameraTransformController = {}
-- store previous mouse position for delta calculation
cameraTransformController.prevMouseX = nil
cameraTransformController.prevMouseY = nil
-- keep explicit yaw/pitch to avoid roll accumulation
cameraTransformController.yaw = nil
cameraTransformController.pitch = nil

local function quatMul(ax, ay, az, aw, bx, by, bz, bw)
    local px = aw * bx + bw * ax + ay * bz - az * by
    local py = aw * by + bw * ay + az * bx - ax * bz
    local pz = aw * bz + bw * az + ax * by - ay * bx
    local pw = aw * bw - ax * bx - ay * by - az * bz
    return px, py, pz, pw
end

local function quatFromAxisAngle(ax, ay, az, angle)
    local half = angle * 0.5
    local s = math.sin(half)
    return ax * s, ay * s, az * s, math.cos(half)
end

local function quatNormalize(x, y, z, w)
    local len = math.sqrt(x * x + y * y + z * z + w * w)
    if len == 0 then
        return 0, 0, 0, 1
    end
    return x / len, y / len, z / len, w / len
end

local function quatRotateVec(vx, vy, vz, qx, qy, qz, qw)
    -- rotate vector v by quaternion q: v' = v + 2*qw*(q_xyz x v) + 2*(q_xyz x (q_xyz x v))
    local tx = 2 * (qy * vz - qz * vy)
    local ty = 2 * (qz * vx - qx * vz)
    local tz = 2 * (qx * vy - qy * vx)

    local cx = qy * tz - qz * ty
    local cy = qz * tx - qx * tz
    local cz = qx * ty - qy * tx

    return vx + qw * tx + cx, vy + qw * ty + cy, vz + qw * tz + cz
end

function cameraTransformController.update(transform)
    local moveSpeed = 1
    local rotateSpeed = 1

    -- ensure transform.position/rotation tables exist
    transform.position = transform.position or {
        x = transform.x or 0,
        y = transform.y or 0,
        z = transform.z or 0,
    }
    transform.rotation = transform.rotation or {
        x = 0,
        y = 0,
        z = 0,
        w = 1,
    }

    -- current orientation
    local qx, qy, qz, qw = transform.rotation.x or 0, transform.rotation.y or 0, transform.rotation.z or 0, transform.rotation.w or 1

    -- compute forward by rotating local +X (1,0,0) by quaternion (match cameraSystem forward)
    local fx, fy, fz = quatRotateVec(1, 0, 0, qx, qy, qz, qw)
    fx, fy, fz = tknMath.normalize3D(fx, fy, fz)

    -- compute camera "up" by rotating local +Z (0,0,1) by quaternion
    local upX, upY, upZ = quatRotateVec(0, 0, 1, qx, qy, qz, qw)
    upX, upY, upZ = tknMath.normalize3D(upX, upY, upZ)

    -- project forward to horizontal (XY) plane because z is world-up
    local hfx, hfy, hfz = fx, fy, 0
    hfx, hfy, hfz = tknMath.normalize3D(hfx, hfy, hfz)

    -- right = normalize(cross(world_up, forward_horizontal)) for left-handed coord
    local worldUpX, worldUpY, worldUpZ = 0.0, 0.0, 1.0
    local rx, ry, rz = tknMath.cross3D(worldUpX, worldUpY, worldUpZ, hfx, hfy, hfz)
    rx, ry, rz = tknMath.normalize3D(rx, ry, rz)

    local px = transform.position.x or 0
    local py = transform.position.y or 0
    local pz = transform.position.z or 0

    if (input.getKeyState(input.keyCode.w) == input.inputState.down) then
        px = px - fx * moveSpeed
        py = py - fy * moveSpeed
        pz = pz - fz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.s) == input.inputState.down) then
        px = px + fx * moveSpeed
        py = py + fy * moveSpeed
        pz = pz + fz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.d) == input.inputState.down) then
        px = px + rx * moveSpeed
        py = py + ry * moveSpeed
    end
    if (input.getKeyState(input.keyCode.a) == input.inputState.down) then
        px = px - rx * moveSpeed
        py = py - ry * moveSpeed
    end

    -- Q/E removed: vertical control disabled here

    -- write position using transformSystem API
    transformSystem.setPosition(transform, px, py, pz)

    -- mouse-driven rotation: right mouse button held => rotate
    local mx = input.mousePositionNDC and input.mousePositionNDC.x or 0
    local my = input.mousePositionNDC and input.mousePositionNDC.y or 0
    local rightDown = input.getMouseState(input.mouseCode.right) == input.inputState.down

    if rightDown then
        -- initialize prev if missing
        if cameraTransformController.prevMouseX == nil then
            cameraTransformController.prevMouseX = mx
            cameraTransformController.prevMouseY = my
        end

        local dx = mx - cameraTransformController.prevMouseX
        local dy = my - cameraTransformController.prevMouseY

        -- sensitivity: scale screen NDC delta to rotation (increased)
        local yawDelta = -dx * rotateSpeed
        local pitchDelta = -dy * rotateSpeed

        -- initialize yaw/pitch from current forward vector if missing
        if cameraTransformController.yaw == nil or cameraTransformController.pitch == nil then
            -- derive from forward vector
            local fxx, fyy, fzz = fx, fy, fz
            cameraTransformController.yaw = math.atan(fyy, fxx)
            -- clamp asin input
            local v = math.max(-1, math.min(1, fzz))
            cameraTransformController.pitch = math.asin(v)
        end

        cameraTransformController.yaw = cameraTransformController.yaw + yawDelta
        cameraTransformController.pitch = cameraTransformController.pitch + pitchDelta
        cameraTransformController.pitch = tknMath.clamp(cameraTransformController.pitch, -1.45, 1.45)

        -- build quaternion from yaw (around world Z) and pitch (around local Y)
        local yx, yy, yz, yw = quatFromAxisAngle(0, 0, 1, cameraTransformController.yaw)
        local pxq, pyq, pzq, pwq = quatFromAxisAngle(0, 1, 0, cameraTransformController.pitch)
        local newQx, newQy, newQz, newQw = quatMul(yx, yy, yz, yw, pxq, pyq, pzq, pwq)

        newQx, newQy, newQz, newQw = quatNormalize(newQx, newQy, newQz, newQw)
        transformSystem.setRotation(transform, newQx, newQy, newQz, newQw)

        cameraTransformController.prevMouseX = mx
        cameraTransformController.prevMouseY = my
    else
        -- clear prev so mouse jump won't produce a large delta next time
        cameraTransformController.prevMouseX = nil
        cameraTransformController.prevMouseY = nil
    end
end

return cameraTransformController
