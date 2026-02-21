local tknMath = require("tknMath")
local transform = {}

local function updateTransformRecursively(current, parentModel, parentActive, parentModelDirty, parentActiveDirty)
    if parentModelDirty or current.modelDirty then
        current.modelDirty = false
        parentModelDirty = true
        -- local model = T * R * S
        local px = current.position and current.position.x or 0
        local py = current.position and current.position.y or 0
        local pz = current.position and current.position.z or 0
        local sx = current.scale and current.scale.x or 1
        local sy = current.scale and current.scale.y or 1
        local sz = current.scale and current.scale.z or 1
        local q = current.rotation or {
            x = 0,
            y = 0,
            z = 0,
            w = 1,
        }
        local qx, qy, qz, qw = q.x or 0, q.y or 0, q.z or 0, q.w or 1

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
        r00 = r00 * sx;
        r10 = r10 * sx;
        r20 = r20 * sx
        r01 = r01 * sy;
        r11 = r11 * sy;
        r21 = r21 * sy
        r02 = r02 * sz;
        r12 = r12 * sz;
        r22 = r22 * sz

        local localModel = {r00, r01, r02, px, r10, r11, r12, py, r20, r21, r22, pz, 0, 0, 0, 1}

        current.model = tknMath.multiplyMatrix4x4(parentModel, localModel)
    end

    -- Active flag propagation
    if parentActiveDirty or current.activeDirty then
        current.activeDirty = false
        parentActiveDirty = true
        current.active = parentActive and current.active
    end

    if current.children then
        for _, child in ipairs(current.children) do
            updateTransformRecursively(child, current.model, current.active, parentModelDirty, parentActiveDirty)
        end
    end
end

function transform.setPosition(target, x, y, z)
    local valueDirty = x ~= target.position.x or y ~= target.position.y or z ~= target.position.z
    target.modelDirty = target.modelDirty or valueDirty
    target.position.x = x
    target.position.y = y
    target.position.z = z
end

function transform.setScale(target, x, y, z)
    local valueDirty = x ~= target.scale.x or y ~= target.scale.y or z ~= target.scale.z
    target.modelDirty = target.modelDirty or valueDirty
    target.scale.x = x
    target.scale.y = y
    target.scale.z = z
end

function transform.setRotation(target, x, y, z, w)
    local valueDirty = x ~= target.rotation.x or y ~= target.rotation.y or z ~= target.rotation.z or w ~= target.rotation.w
    target.modelDirty = target.modelDirty or valueDirty
    target.rotation.x = x
    target.rotation.y = y
    target.rotation.z = z
    target.rotation.w = w
end

function transform.setActive(target, active)
    local valueDirty = active ~= target.active
    target.activeDirty = target.activeDirty or valueDirty
    target.active = active
end

function transform.add(position, rotation, scale, active, parent, index)
    local result = {
        parent = parent,
        position = {},
        rotation = {},
        scale = {},
        active = nil,
        children = {},
    }
    result.setPosition(result, position.x, position.y, position.z)
    result.setRotation(result, rotation.x, rotation.y, rotation.z, rotation.w)
    result.setScale(result, scale.x, scale.y, scale.z)
    result.setActive(result, active)
    if parent then
        if index then
            assert(index >= 1 and index <= #parent.children + 1, "transform.add: index out of bounds")
            table.insert(parent.children, index, result)
        else
            table.insert(parent.children, result)
        end
    else
        assert(not result.rootTransform, "rootTransform already exists")
        result.rootTransform = result
    end
    return result
end

function transform.remove(target)
    if target.parent then
        for i = #target.parent.children, 1, -1 do
            local child = target.parent.children[i]
            if child == target then
                table.remove(target.parent.children, i)
                break
            end
        end
    else
        assert(target.rootTransform == target, "rootTransform mismatch")
        target.rootTransform = nil
    end
end
return transform
