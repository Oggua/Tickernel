local input = require("input")
local transformSystem = require("game.transformSystem")
local tknMath = require("tknMath")
local transformController = {}

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

function transformController.update(transform)
    local moveSpeed = 0.1
    local rotateSpeed = 0.02

    -- ensure transform.position/rotation tables exist
    transform.position = transform.position or {x = transform.x or 0, y = transform.y or 0, z = transform.z or 0}
    transform.rotation = transform.rotation or {x = 0, y = 0, z = 0, w = 1}

    -- current orientation
    local qx, qy, qz, qw = transform.rotation.x or 0, transform.rotation.y or 0, transform.rotation.z or 0, transform.rotation.w or 1

    -- compute forward by rotating local +X (1,0,0) by quaternion
    local tx = 0
    local ty = 2 * qz
    local tz = -2 * qy
    local cx = qy * tz - qz * ty
    local cy = qz * tx - qx * tz
    local cz = qx * ty - qy * tx
    local fx = 1 + qw * tx + cx
    local fy = 0 + qw * ty + cy
    local fz = 0 + qw * tz + cz
    fx, fy, fz = tknMath.normalize3D(fx, fy, fz)

    -- up vector Z-up
    local upX, upY, upZ = 0.0, 0.0, 1.0

    -- right = normalize(cross(forward, up))
    local rx, ry, rz = tknMath.cross3D(fx, fy, fz, upX, upY, upZ)
    rx, ry, rz = tknMath.normalize3D(rx, ry, rz)

    local px = transform.position.x or 0
    local py = transform.position.y or 0
    local pz = transform.position.z or 0

    if (input.getKeyState(input.keyCode.w) == input.inputState.down) then
        px = px + fx * moveSpeed
        pz = pz + fz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.s) == input.inputState.down) then
        px = px - fx * moveSpeed
        pz = pz - fz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.d) == input.inputState.down) then
        px = px + rx * moveSpeed
        pz = pz + rz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.a) == input.inputState.down) then
        px = px - rx * moveSpeed
        pz = pz - rz * moveSpeed
    end

    if (input.getKeyState(input.keyCode.q) == input.inputState.down) then
        py = py + moveSpeed
    end
    if (input.getKeyState(input.keyCode.e) == input.inputState.down) then
        py = py - moveSpeed
    end

    -- write position using transformSystem API
    transformSystem.setPosition(transform, px, py, pz)

    -- handle rotations: yaw around world Z, pitch around local right
    local newQx, newQy, newQz, newQw = qx, qy, qz, qw

    if (input.getKeyState(input.keyCode.left) == input.inputState.down) then
        -- yaw left (negative)
        local ryx, ryy, ryz, ryw = quatFromAxisAngle(0, 0, 1, -rotateSpeed)
        newQx, newQy, newQz, newQw = quatMul(ryx, ryy, ryz, ryw, newQx, newQy, newQz, newQw)
    end
    if (input.getKeyState(input.keyCode.right) == input.inputState.down) then
        local ryx, ryy, ryz, ryw = quatFromAxisAngle(0, 0, 1, rotateSpeed)
        newQx, newQy, newQz, newQw = quatMul(ryx, ryy, ryz, ryw, newQx, newQy, newQz, newQw)
    end
    if (input.getKeyState(input.keyCode.up) == input.inputState.down) then
        -- pitch up around local right (positive)
        local pxq, pyq, pzq, pwq = quatFromAxisAngle(rx, ry, rz, rotateSpeed)
        newQx, newQy, newQz, newQw = quatMul(newQx, newQy, newQz, newQw, pxq, pyq, pzq, pwq)
    end
    if (input.getKeyState(input.keyCode.down) == input.inputState.down) then
        local pxq, pyq, pzq, pwq = quatFromAxisAngle(rx, ry, rz, -rotateSpeed)
        newQx, newQy, newQz, newQw = quatMul(newQx, newQy, newQz, newQw, pxq, pyq, pzq, pwq)
    end

    newQx, newQy, newQz, newQw = quatNormalize(newQx, newQy, newQz, newQw)
    transformSystem.setRotation(transform, newQx, newQy, newQz, newQw)
end

return transformController
