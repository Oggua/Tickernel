local transformSystem = require("game.transformSystem")
local physicsSystem = {}

function physicsSystem.setup(gravity)
    physicsSystem.gravity = gravity or {0, 0, -9.8}
    physicsSystem.bodies = {}
end

function physicsSystem.teardown()
    physicsSystem.gravity = nil
    physicsSystem.bodies = nil
end

function physicsSystem.addBody(transform, halfExtents, options)
    options = options or {}
    local body = {
        transform = transform,
        halfExtents = {halfExtents[1], halfExtents[2], halfExtents[3]},
        velocity = {0, 0, 0},
        isStatic = options.isStatic or false,
        onGround = false,
    }
    table.insert(physicsSystem.bodies, body)
    return body
end

function physicsSystem.removeBody(body)
    local list = physicsSystem.bodies
    for i, v in ipairs(list) do
        if v == body then
            table.remove(list, i)
            break
        end
    end
end

local function getAABB(body)
    local pos = body.transform.position
    local hx = body.halfExtents[1]
    local hy = body.halfExtents[2]
    local hz = body.halfExtents[3]
    return {
        minX = pos[1] - hx,
        minY = pos[2] - hy,
        minZ = pos[3] - hz,
        maxX = pos[1] + hx,
        maxY = pos[2] + hy,
        maxZ = pos[3] + hz,
    }
end

local function testAABB(a, b)
    return a.minX < b.maxX and a.maxX > b.minX and a.minY < b.maxY and a.maxY > b.minY and a.minZ < b.maxZ and a.maxZ > b.minZ
end

local function getOverlap(a, b)
    local ox = math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX)
    local oy = math.min(a.maxY, b.maxY) - math.max(a.minY, b.minY)
    local oz = math.min(a.maxZ, b.maxZ) - math.max(a.minZ, b.minZ)
    return ox, oy, oz
end

function physicsSystem.update(dt)
    local bodies = physicsSystem.bodies
    local gx = physicsSystem.gravity[1]
    local gy = physicsSystem.gravity[2]
    local gz = physicsSystem.gravity[3]

    for _, body in ipairs(bodies) do
        if not body.isStatic then
            local vel = body.velocity
            vel[1] = vel[1] + gx * dt
            vel[2] = vel[2] + gy * dt
            vel[3] = vel[3] + gz * dt

            local pos = body.transform.position
            transformSystem.setPosition(body.transform, pos[1] + vel[1] * dt, pos[2] + vel[2] * dt, pos[3] + vel[3] * dt)

            body.onGround = false
        end
    end

    for i = 1, #bodies do
        for j = i + 1, #bodies do
            local a = bodies[i]
            local b = bodies[j]
            if a.isStatic and b.isStatic then
                goto continue
            end

            local aabbA = getAABB(a)
            local aabbB = getAABB(b)

            if testAABB(aabbA, aabbB) then
                local ox, oy, oz = getOverlap(aabbA, aabbB)

                if ox < oy and ox < oz then
                    local sign = (a.transform.position[1] < b.transform.position[1]) and -1 or 1
                    if not a.isStatic then
                        transformSystem.setPosition(a.transform, a.transform.position[1] + sign * ox * 0.5, a.transform.position[2], a.transform.position[3])
                        a.velocity[1] = 0
                    end
                    if not b.isStatic then
                        transformSystem.setPosition(b.transform, b.transform.position[1] - sign * ox * 0.5, b.transform.position[2], b.transform.position[3])
                        b.velocity[1] = 0
                    end
                elseif oy < ox and oy < oz then
                    local sign = (a.transform.position[2] < b.transform.position[2]) and -1 or 1
                    if not a.isStatic then
                        transformSystem.setPosition(a.transform, a.transform.position[1], a.transform.position[2] + sign * oy * 0.5, a.transform.position[3])
                        a.velocity[2] = 0
                    end
                    if not b.isStatic then
                        transformSystem.setPosition(b.transform, b.transform.position[1], b.transform.position[2] - sign * oy * 0.5, b.transform.position[3])
                        b.velocity[2] = 0
                    end
                else
                    local sign = (a.transform.position[3] < b.transform.position[3]) and -1 or 1
                    if not a.isStatic then
                        transformSystem.setPosition(a.transform, a.transform.position[1], a.transform.position[2], a.transform.position[3] + sign * oz * 0.5)
                        a.velocity[3] = 0
                        if sign == -1 then
                            a.onGround = true
                        end
                    end
                    if not b.isStatic then
                        transformSystem.setPosition(b.transform, b.transform.position[1], b.transform.position[2], b.transform.position[3] - sign * oz * 0.5)
                        b.velocity[3] = 0
                        if sign == 1 then
                            b.onGround = true
                        end
                    end
                end
            end

            ::continue::
        end
    end
end

return physicsSystem
