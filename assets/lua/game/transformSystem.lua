local tknMath = require("tknMath")
local transformSystem = {}

local function updateTransformRecursively(transform, parentModel, parentDirty)
    if parentDirty or transform.dirty then
        transform.dirty = false
        parentDirty = true
        -- local model = T * R * S
        local px = transform.position and transform.position[1] or 0
        local py = transform.position and transform.position[2] or 0
        local pz = transform.position and transform.position[3] or 0
        local sx = transform.scale and transform.scale[1] or 1
        local sy = transform.scale and transform.scale[2] or 1
        local sz = transform.scale and transform.scale[3] or 1
        local q = transform.rotation or {0, 0, 0, 1}
        local qx, qy, qz, qw = q[1] or 0, q[2] or 0, q[3] or 0, q[4] or 1

        -- rotation matrix from quaternion (row-major)
        local xx = qx * qx
        local yy = qy * qy
        local zz = qz * qz
        local xy = qx * qy
        local xz = qx * qz
        local yz = qy * qz
        local wx = qw * qx
        local wy = qw * qy
        local wz = qw * qz

        local r00 = 1 - 2 * (yy + zz)
        local r01 = 2 * (xy + wz)
        local r02 = 2 * (xz - wy)

        local r10 = 2 * (xy - wz)
        local r11 = 1 - 2 * (xx + zz)
        local r12 = 2 * (yz + wx)

        local r20 = 2 * (xz + wy)
        local r21 = 2 * (yz - wx)
        local r22 = 1 - 2 * (xx + yy)

        -- apply scale to rotation (R * S) by scaling each column of R
        r00 = r00 * sx; r10 = r10 * sx; r20 = r20 * sx
        r01 = r01 * sy; r11 = r11 * sy; r21 = r21 * sy
        r02 = r02 * sz; r12 = r12 * sz; r22 = r22 * sz

        local localModel = {r00, r01, r02, px, r10, r11, r12, py, r20, r21, r22, pz, 0, 0, 0, 1}

        transform.model = tknMath.multiplyMatrix4x4(parentModel, localModel)
    end

    if transform.children then
        for _, child in ipairs(transform.children) do
            updateTransformRecursively(child, transform.model, parentDirty)
        end
    end
end

-- position: {x, y, z}  (array indices [1][2][3])
function transformSystem.setPosition(transform, x, y, z)
    local p = transform.position
    local valueDirty = x ~= p[1] or y ~= p[2] or z ~= p[3]
    transform.dirty = transform.dirty or valueDirty
    p[1] = x
    p[2] = y
    p[3] = z
end

-- scale: {x, y, z}  (array indices [1][2][3])
function transformSystem.setScale(transform, x, y, z)
    local s = transform.scale
    local valueDirty = x ~= s[1] or y ~= s[2] or z ~= s[3]
    transform.dirty = transform.dirty or valueDirty
    s[1] = x
    s[2] = y
    s[3] = z
end

-- rotation: {x, y, z, w}  (array indices [1][2][3][4], quaternion)
function transformSystem.setRotation(transform, x, y, z, w)
    local r = transform.rotation
    local valueDirty = x ~= r[1] or y ~= r[2] or z ~= r[3] or w ~= r[4]
    transform.dirty = transform.dirty or valueDirty
    r[1] = x
    r[2] = y
    r[3] = z
    r[4] = w
end

function transformSystem.add(px, py, pz, rx, ry, rz, rw, sx, sy, sz, parent, index)
    local result = {
        parent = parent,
        position = {},
        rotation = {},
        scale = {},
        children = {},
    }
    transformSystem.setPosition(result, px, py, pz)
    transformSystem.setRotation(result, rx, ry, rz, rw)
    transformSystem.setScale(result, sx, sy, sz)
    if parent then
        if index then
            assert(index >= 1 and index <= #parent.children + 1, "transform.add: index out of bounds")
            table.insert(parent.children, index, result)
        else
            table.insert(parent.children, result)
        end
    else
        assert(not transformSystem.rootTransform, "rootTransform already exists")
        transformSystem.rootTransform = result
    end
    return result
end

function transformSystem.remove(transform)
    if transform.parent then
        for i = #transform.parent.children, 1, -1 do
            local child = transform.parent.children[i]
            if child == transform then
                table.remove(transform.parent.children, i)
                break
            end
        end
    else
        assert(transformSystem.rootTransform == transform, "rootTransform mismatch")
        transformSystem.rootTransform = nil
    end
end

local defaultModel = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}

function transformSystem.setup()
    transformSystem.add(0, 0, 0, 0, 0, 0, 1, 1, 1, 1, nil, nil)
end

function transformSystem.teardown()
    transformSystem.remove(transformSystem.rootTransform)
end

function transformSystem.update()
    if transformSystem.rootTransform then
        updateTransformRecursively(transformSystem.rootTransform, defaultModel, false)
    end
end

return transformSystem
