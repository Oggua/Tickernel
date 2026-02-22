local tknMath = require("tknMath")
local transformSystem = {}

local function updateTransformRecursively(transform, parentModel, parentDirty)
    if parentDirty or transform.dirty then
        transform.dirty = false
        parentDirty = true
        -- local model = T * R * S
        local px = transform.position and transform.position.x or 0
        local py = transform.position and transform.position.y or 0
        local pz = transform.position and transform.position.z or 0
        local sx = transform.scale and transform.scale.x or 1
        local sy = transform.scale and transform.scale.y or 1
        local sz = transform.scale and transform.scale.z or 1
        local q = transform.rotation or {
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

        transform.model = tknMath.multiplyMatrix4x4(parentModel, localModel)
    end

    if transform.children then
        for _, child in ipairs(transform.children) do
            updateTransformRecursively(child, transform.model, parentDirty)
        end
    end
end

function transformSystem.setPosition(transform, x, y, z)
    local valueDirty = x ~= transform.position.x or y ~= transform.position.y or z ~= transform.position.z
    transform.dirty = transform.dirty or valueDirty
    transform.position.x = x
    transform.position.y = y
    transform.position.z = z
end

function transformSystem.setScale(transform, x, y, z)
    local valueDirty = x ~= transform.scale.x or y ~= transform.scale.y or z ~= transform.scale.z
    transform.dirty = transform.dirty or valueDirty
    transform.scale.x = x
    transform.scale.y = y
    transform.scale.z = z
end

function transformSystem.setRotation(transform, x, y, z, w)
    local valueDirty = x ~= transform.rotation.x or y ~= transform.rotation.y or z ~= transform.rotation.z or w ~= transform.rotation.w
    transform.dirty = transform.dirty or valueDirty
    transform.rotation.x = x
    transform.rotation.y = y
    transform.rotation.z = z
    transform.rotation.w = w
end

function transformSystem.add(position, rotation, scale, parent, index)
    local result = {
        parent = parent,
        position = {},
        rotation = {},
        scale = {},
        children = {},
    }
    transformSystem.setPosition(result, position.x, position.y, position.z)
    transformSystem.setRotation(result, rotation.x, rotation.y, rotation.z, rotation.w)
    transformSystem.setScale(result, scale.x, scale.y, scale.z)
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
    transformSystem.add({
        x = 0,
        y = 0,
        z = 0,
    }, {
        x = 0,
        y = 0,
        z = 0,
        w = 1,
    }, {
        x = 1,
        y = 1,
        z = 1,
    }, nil, nil)
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
