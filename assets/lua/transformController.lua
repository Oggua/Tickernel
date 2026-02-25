local input = require("input")
local transformSystem = require("game.transformSystem")
local tknMath = require("tknMath")
local cameraTransformController = {}

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
    local moveSpeed = 0.1
    local rotateSpeed = 0.02

    -- ensure transform.position/rotation tables exist
    transform.position = transform.position or {x = transform.x or 0, y = transform.y or 0, z = transform.z or 0}
    transform.rotation = transform.rotation or {x = 0, y = 0, z = 0, w = 1}

    -- current orientation
    local qx, qy, qz, qw = transform.rotation.x or 0, transform.rotation.y or 0, transform.rotation.z or 0, transform.rotation.w or 1

    -- compute forward by rotating local +X (1,0,0) by quaternion
    local fx, fy, fz = quatRotateVec(1, 0, 0, qx, qy, qz, qw)
    fx, fy, fz = tknMath.normalize3D(fx, fy, fz)

    -- compute camera "up" by rotating local +Z (0,0,1) by quaternion
    local upX, upY, upZ = quatRotateVec(0, 0, 1, qx, qy, qz, qw)
    upX, upY, upZ = tknMath.normalize3D(upX, upY, upZ)

    -- right = normalize(cross(world_up, forward)) for left-handed coord
    local worldUpX, worldUpY, worldUpZ = 0.0, 0.0, 1.0
    local rx, ry, rz = tknMath.cross3D(worldUpX, worldUpY, worldUpZ, fx, fy, fz)
    rx, ry, rz = tknMath.normalize3D(rx, ry, rz)

    local px = transform.position.x or 0
    local py = transform.position.y or 0
    local pz = transform.position.z or 0

    if (input.getKeyState(input.keyCode.w) == input.inputState.down) then
        px = px + fx * moveSpeed
        py = py + fy * moveSpeed
        pz = pz + fz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.s) == input.inputState.down) then
        px = px - fx * moveSpeed
        py = py - fy * moveSpeed
        pz = pz - fz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.d) == input.inputState.down) then
        px = px + rx * moveSpeed
        py = py + ry * moveSpeed
        pz = pz + rz * moveSpeed
    end
    if (input.getKeyState(input.keyCode.a) == input.inputState.down) then
        px = px - rx * moveSpeed
        py = py - ry * moveSpeed
        pz = pz - rz * moveSpeed
    end

    -- Q/E removed: no vertical camera control here

    -- write position using transformSystem API
    transformSystem.setPosition(transform, px, py, pz)

    -- rotation controls disabled per user request
end

return cameraTransformController
