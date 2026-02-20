local game = {}
local mainScene = require("game.mainScene")
local ui = require("ui.ui")
local tkn = require("tkn")
local tknMath = require("tknMath")
local input = require("input")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local tknSliderWidget = require("engine.widgets.tknSliderWidget")

function game.start(pTknGfxContext, pSwapchainAttachment, pDepthStencilAttachment, renderPassIndex, assetsPath, rootUINode)
    deferredRenderPass.setup(pTknGfxContext, assetsPath, renderPassIndex, pDepthStencilAttachment, pSwapchainAttachment)
    game.assetsPath = assetsPath
    game.currentScene = mainScene
    game.nextScene = mainScene
    game.rootUINode = rootUINode
    game.rootGameNode = game.addNode("rootGameNode", {
        x = 0,
        y = 0,
        z = 0,
    }, {
        x = 0,
        y = 0,
        z = 0,
        w = 0,
    }, {
        x = 1,
        y = 1,
        z = 1,
    }, true, nil, nil)

    game.currentScene.start(game, pTknGfxContext)
end

function game.stop()
    game.currentScene.stop(game)
end

function game.stopGfx(pTknGfxContext)
    game.currentScene.stopGfx(game, pTknGfxContext)
    game.currentScene = nil
    deferredRenderPass.teardown(pTknGfxContext)
    game.removeNode(game.rootGameNode)
end

local function updateGameNodeRecursively(node, parentModel, parentActive, parentModelDirty, parentActiveDirty)
    -- Ensure transform table exists
    node.transform = node.transform or {}

    -- Determine whether this node's world model should be recomputed
    if parentModelDirty or node.transform.modelDirty then
        node.transform.modelDirty = false
        parentModelDirty = true
        -- local model = T * R * S
        local px = node.transform.position and node.transform.position.x or 0
        local py = node.transform.position and node.transform.position.y or 0
        local pz = node.transform.position and node.transform.position.z or 0
        local sx = node.transform.scale and node.transform.scale.x or 1
        local sy = node.transform.scale and node.transform.scale.y or 1
        local sz = node.transform.scale and node.transform.scale.z or 1
        local q = node.transform.rotation or {
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

        node.transform.model = tknMath.multiplyMatrix4x4(parentModel, localModel)
    end

    -- Active flag propagation
    if parentActiveDirty or node.transform.activeDirty then
        node.transform.activeDirty = false
        parentActiveDirty = true
        node.transform.active = parentActive and node.transform.active
    end

    if node.children then
        for _, child in ipairs(node.children) do
            updateGameNodeRecursively(child, node.transform.model, node.transform.active, parentModelDirty, parentActiveDirty)
        end
    end
end

function game.update()
    game.currentScene.update(game)
    updateGameNodeRecursively(game.rootGameNode, {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}, true, false, false)

end

function game.updateGfx(pTknGfxContext, width, height)
    game.currentScene.updateGfx(game, pTknGfxContext, width, height)
    local shouldQuit = false
    if game.nextScene == nil then
        shouldQuit = true
    else
        if game.nextScene ~= game.currentScene then
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

function game.setNodeTransformPosition(node, x, y, z)
    local valueDirty = x ~= node.transform.position.x or y ~= node.transform.position.y or z ~= node.transform.position.z
    node.transform.modelDirty = node.transform.modelDirty or valueDirty
    node.transform.position.x = x
    node.transform.position.y = y
    node.transform.position.z = z
end

function game.setNodeTransformScale(node, x, y, z)
    local valueDirty = x ~= node.transform.scale.x or y ~= node.transform.scale.y or z ~= node.transform.scale.z
    node.transform.modelDirty = node.transform.modelDirty or valueDirty
    node.transform.scale.x = x
    node.transform.scale.y = y
    node.transform.scale.z = z
end

function game.setNodeTransformRotation(node, x, y, z, w)
    local valueDirty = x ~= node.transform.rotation.x or y ~= node.transform.rotation.y or z ~= node.transform.rotation.z or w ~= node.transform.rotation.w
    node.transform.modelDirty = node.transform.modelDirty or valueDirty
    node.transform.rotation.x = x
    node.transform.rotation.y = y
    node.transform.rotation.z = z
    node.transform.rotation.w = w
end

function game.setNodeTransformActive(node, active)
    local valueDirty = active ~= node.transform.active
    node.transform.activeDirty = node.transform.activeDirty or valueDirty
    node.transform.active = active
end

function game.addNode(name, position, rotation, scale, active, parent, index)
    local node = {
        name = name,
        parent = parent,
        transform = {
            position = {},
            rotation = {},
            scale = {},
            active = nil,
        },
        children = {},
    }
    game.setNodeTransformPosition(node, position.x, position.y, position.z)
    game.setNodeTransformRotation(node, rotation.x, rotation.y, rotation.z, rotation.w)
    game.setNodeTransformScale(node, scale.x, scale.y, scale.z)
    game.setNodeTransformActive(node, active)
    if parent then
        if index then
            assert(index >= 1 and index <= #parent.children + 1, "game.addNode: index out of bounds")
            table.insert(parent.children, index, node)
        else
            table.insert(parent.children, node)
        end
    else
        assert(not game.rootGameNode, "Game root node already exists")
        game.rootGameNode = node
    end
    return node
end

function game.removeNode(node)
    if node.parent then
        for i = #node.parent.children, 1, -1 do
            local child = node.parent.children[i]
            if child == node then
                table.remove(node.parent.children, i)
                break
            end
        end
    else
        assert(game.rootGameNode == node, "Game root node mismatch")
        game.rootGameNode = nil
    end
end

return game
