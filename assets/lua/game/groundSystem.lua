local tknMath = require("tknMath")
local tkn = require("tkn")
local deferredRenderPass = require("game.deferredRenderer.deferredRenderPass")
local voxelConfig = require("game.voxelConfig")
local groundSystem = {}

function groundSystem.setup(voxelPerMeter)
    groundSystem.ground = {
        snow = 1,
        ice = 2,
        sand = 3,
        grass = 4,
        water = 5,
        lava = 6,
        volcanic = 7,
    }

    groundSystem.groundConfig = {
        [1] = {
            name = "snow",
            temperature = -1,
            humidity = 0,
            temperatureVariance = 0.15,
            humidityVariance = 0.15,
        },
        [2] = {
            name = "ice",
            temperature = -1,
            humidity = 1,
            temperatureVariance = 0.15,
            humidityVariance = 0.12,
        },
        [3] = {
            name = "sand",
            temperature = 0,
            humidity = -1,
            temperatureVariance = 0.18,
            humidityVariance = 0.15,
        },
        [4] = {
            name = "grass",
            temperature = 0,
            humidity = 0,
            temperatureVariance = 0.18,
            humidityVariance = 0.18,
        },
        [5] = {
            name = "water",
            temperature = 0,
            humidity = 1,
            temperatureVariance = 0.15,
            humidityVariance = 0.12,
        },
        [6] = {
            name = "lava",
            temperature = 1,
            humidity = -1,
            temperatureVariance = 0.15,
            humidityVariance = 0.12,
        },
        [7] = {
            name = "volcanic",
            temperature = 1,
            humidity = 0,
            temperatureVariance = 0.15,
            humidityVariance = 0.15,
        },
    }

    groundSystem.temperatureStep = 0.27
    groundSystem.humidityStep = 0.27

    groundSystem.voxelPerMeter = voxelPerMeter
end

function groundSystem.teardown()
    groundSystem.temperatureStep = nil
    groundSystem.humidityStep = nil
    groundSystem.temperatureNoiseScale = nil
    groundSystem.humidityNoiseScale = nil
    groundSystem.voxelPerMeter = nil

    groundSystem.ground = nil
    groundSystem.groundConfig = nil
end

function groundSystem.getGround(temperature, humidity)
    local result
    if temperature < -groundSystem.temperatureStep then
        if humidity < -groundSystem.humidityStep then
            result = groundSystem.ground.snow
        elseif humidity < groundSystem.humidityStep then
            result = groundSystem.ground.snow
        else
            result = groundSystem.ground.ice
        end
    elseif temperature < groundSystem.temperatureStep then
        if humidity < -groundSystem.humidityStep then
            result = groundSystem.ground.sand
        elseif humidity < groundSystem.humidityStep then
            result = groundSystem.ground.grass
        else
            result = groundSystem.ground.water
        end
    else
        if humidity < -groundSystem.humidityStep then
            result = groundSystem.ground.lava
        elseif humidity < groundSystem.humidityStep then
            result = groundSystem.ground.volcanic
        else
            result = groundSystem.ground.volcanic
        end
    end

    return result
end

-- Returns temperature and humidity for a single ground cell at integer coords (gx, gy),
-- with LCG-based fluctuation whose range is determined by the ground type.
local function getGroundTempHumidity(groundMap, gx, gy)
    gx = math.max(1, math.min(groundMap.length, math.floor(gx)))
    gy = math.max(1, math.min(groundMap.width, math.floor(gy)))

    local ground = groundMap.groundMap[gx][gy]
    local groundData = groundSystem.groundConfig[ground]
    local baseTemp = groundData.temperature
    local baseHumidity = groundData.humidity
    local tempVariance = groundData.temperatureVariance
    local humidVariance = groundData.humidityVariance

    local pairKey = tknMath.cantorPair(gx, gy)
    local tempRand = tknMath.lcgRandom(groundMap.temperatureSeed + pairKey)
    local humidRand = tknMath.lcgRandom(groundMap.humiditySeed + pairKey)

    -- Normalise [0, 0xFFFFFFFF] → [-1, 1]
    local tempNorm = (tempRand % 65536) / 32767.5 - 1.0
    local humidNorm = (humidRand % 65536) / 32767.5 - 1.0

    return baseTemp + tempNorm * tempVariance, baseHumidity + humidNorm * humidVariance
end

-- Bilinear-interpolates temperature and humidity from the 4 ground cells
-- surrounding the real-space position (rvx, rvy).
-- A power-curve is applied to tx/ty so each ground cell dominates the
-- majority of its area and transitions only occur near cell boundaries.
local function sharpenT(t)
    -- Exponent of the symmetric power curve applied to the bilinear weights.
    -- Controls how strongly each ground cell dominates its own area:
    --   1.0 = linear (most natural blend, heavy neighbour influence)
    --   2.0 = quadratic (gentle dominance)
    --   3.0 = cubic (cells clearly distinct, recommended default)
    --   5.0 = quintic (very sharp biome borders, may look blocky)
    local groundSharpen = 4.5
    -- Symmetric power curve: pushes values toward 0 or 1.
    -- groundSharpen is the exponent; higher = more distinct cells.
    if t <= 0.5 then
        return 0.5 * (2.0 * t) ^ groundSharpen
    else
        return 1.0 - 0.5 * (2.0 * (1.0 - t)) ^ groundSharpen
    end
end

local function getTemperatureHumidityFromGroundMap(groundMap, rvx, rvy)
    local gx0 = math.floor(rvx)
    local gy0 = math.floor(rvy)
    local gx1 = gx0 + 1
    local gy1 = gy0 + 1
    -- Apply sharpening so each cell's centre strongly dominates
    local tx = sharpenT(rvx - gx0)
    local ty = sharpenT(rvy - gy0)

    local t00, h00 = getGroundTempHumidity(groundMap, gx0, gy0)
    local t10, h10 = getGroundTempHumidity(groundMap, gx1, gy0)
    local t01, h01 = getGroundTempHumidity(groundMap, gx0, gy1)
    local t11, h11 = getGroundTempHumidity(groundMap, gx1, gy1)

    local temperature = tknMath.lerp(tknMath.lerp(t00, t10, tx), tknMath.lerp(t01, t11, tx), ty)
    local humidity = tknMath.lerp(tknMath.lerp(h00, h10, tx), tknMath.lerp(h01, h11, tx), ty)
    return temperature, humidity
end

local function setBaseVoxel(temperature, humidity, columnVoxels, seed, rvx, rvy, vx, vy)
    local voxel
    local ground = groundSystem.getGround(temperature, humidity)
    local height
    if ground == groundSystem.ground.snow or ground == groundSystem.ground.ice then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 14, rvy * 14)
        noise = noise * noise * noise
        voxel = voxelConfig.rock
        height = (noise + 1) * 1.5
    elseif ground == groundSystem.ground.sand or ground == groundSystem.ground.grass or ground == groundSystem.ground.water then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 7.77, rvy * 7.77)
        voxel = voxelConfig.dirt
        height = (noise + 1) * 1.5
    elseif ground == groundSystem.ground.lava or ground == groundSystem.ground.volcanic then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 17, rvy * 17)
        noise = noise * noise * noise
        voxel = voxelConfig.darkRock
        height = (noise + 1) * 2
    else
        error("Unsupported ground for base voxel: " .. ground)
    end

    for h = 1, height, 1 do
        -- columnVoxels[h] = voxels[tknMath.lcgRandom(seed + vx + vy + h) % #voxels + 1]
        columnVoxels[h] = voxel
    end
    
    if ground == groundSystem.ground.snow then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 4, rvy * 4)
        local voxel = voxelConfig.snow
        local step = 0.2
        if noise > step then
            height = 4
        elseif noise > -step then
            height = 3
        else
            height = 2
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == groundSystem.ground.ice then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 4, rvy * 4)
        local voxel = voxelConfig.ice
        local step = 0.4
        if noise > step then
            height = 3
        elseif noise > -step then
            height = 2
        else
            height = 1
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == groundSystem.ground.sand then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 2, rvy * 2)
        local voxel
        if noise > 0.27 then
            height = 4
        elseif noise > -0.27 then
            height = 3
        else
            height = 2
        end
        noise = tknMath.lcgRandom(seed + tknMath.cantorPair(vx, vy)) % 128
        if noise < 2 then
            voxel = voxelConfig.lightRock
            height = 4
        else
            voxel = voxelConfig.sand
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == groundSystem.ground.grass then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 5, rvy * 5)
        local voxel
        if noise > 0.63 then
            voxel = voxelConfig.lightGrass
            height = 2
        elseif noise > 0.6 then
            voxel = voxelConfig.dirt
            height = 2
        elseif noise > 0.57 then
            voxel = voxelConfig.lightRock
            height = 3
        elseif noise > 0.53 then
            voxel = voxelConfig.lightRock
            height = 4
        elseif noise > 0.1 then
            voxel = voxelConfig.darkDirt
            height = 1
        elseif noise > -0.4 then
            voxel = voxelConfig.dirt
            height = 2
        else
            voxel = voxelConfig.dirt
            height = 3
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == groundSystem.ground.water then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 2, rvy * 3)
        local voxel = voxelConfig.water
        if noise > 0 then
            height = 4
        else
            height = 3
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == groundSystem.ground.lava then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 7, rvy * 7)
        local voxel
        if noise > 0.3 then
            voxel = voxelConfig.lightLava
            height = 3
        else
            voxel = voxelConfig.lava
            height = 2
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == groundSystem.ground.volcanic then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 21, rvy * 21)
        local voxel
        if noise > 0.3 then
            voxel = voxelConfig.rock
            height = 4
        elseif noise > -0.3 then
            voxel = voxelConfig.darkRock
            height = 3
        else
            voxel = voxelConfig.lava
            height = 2
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    else
        error("Unsupported ground for base voxel: " .. ground)
    end

end

local function getSurfaceVoxel(temperature, humidity)
    local ground = groundSystem.getGround(temperature, humidity)
    if ground == groundSystem.ground.snow then
        return voxelConfig.snow
    elseif ground == groundSystem.ground.ice then
        return voxelConfig.ice
    elseif ground == groundSystem.ground.sand then
        return voxelConfig.sand
    elseif ground == groundSystem.ground.grass then
        return voxelConfig.grass
    elseif ground == groundSystem.ground.water then
        return voxelConfig.water
    elseif ground == groundSystem.ground.lava then
        return voxelConfig.lava
    elseif ground == groundSystem.ground.volcanic then
        return voxelConfig.volcanic
    end
end

local function calculateNormal(voxelMap, x, y, z)
    local mask = 0
    local neighbors = { -- 6 faces
    {-1, 0, 0}, {1, 0, 0}, {0, -1, 0}, {0, 1, 0}, {0, 0, -1}, {0, 0, 1}, -- 12 edges
    {-1, -1, 0}, {-1, 1, 0}, {1, -1, 0}, {1, 1, 0}, {-1, 0, -1}, {-1, 0, 1}, {1, 0, -1}, {1, 0, 1}, {0, -1, -1}, {0, -1, 1}, {0, 1, -1}, {0, 1, 1}, -- 8 corners
    {-1, -1, -1}, {-1, -1, 1}, {-1, 1, -1}, {-1, 1, 1}, {1, -1, -1}, {1, -1, 1}, {1, 1, -1}, {1, 1, 1}}
    for i, d in ipairs(neighbors) do
        local nx = x + d[1]
        local ny = y + d[2]
        local nz = z + d[3]
        if not (voxelMap[nx] and voxelMap[nx][ny] and voxelMap[nx][ny][nz]) then
            mask = mask | (1 << (i - 1))
        end
    end
    return mask
end

-- groundMap is optional.  When provided it must be a 2-D table [1..length][1..width]
-- whose values are groundSystem.ground constants.  When omitted the groundMap is built
-- from Perlin-noise temperature / humidity as before.
-- Returns a groundMap object containing all generated data.
function groundSystem.createMap(seed, length, width, inputGroundMap)
    local groundMap = {}
    groundMap.seed = seed
    groundMap.temperatureSeed = seed + 1
    groundMap.humiditySeed = seed + 2
    groundMap.length = length
    groundMap.width = width
    groundMap.groundMap = inputGroundMap

    -- Generate voxel groundMap.
    -- Temperature/humidity for each voxel are derived from the 4 surrounding
    -- ground cells via bilinear interpolation + per-ground-type LCG fluctuation.
    local metersPerVoxel = 1 / groundSystem.voxelPerMeter
    local halfVoxelPerMeter = groundSystem.voxelPerMeter / 2
    groundMap.voxelMap = {}
    for x = 1, length do
        for y = 1, width do
            for lvx = 1, groundSystem.voxelPerMeter do
                local vx = (x - 1) * groundSystem.voxelPerMeter + lvx
                if not groundMap.voxelMap[vx] then
                    groundMap.voxelMap[vx] = {}
                end

                for lvy = 1, groundSystem.voxelPerMeter do
                    local vy = (y - 1) * groundSystem.voxelPerMeter + lvy
                    if not groundMap.voxelMap[vx][vy] then
                        groundMap.voxelMap[vx][vy] = {}
                    end
                    -- Real-space position of this voxel in ground-cell coordinates
                    local rvx = x + (lvx - halfVoxelPerMeter - 0.5) * metersPerVoxel
                    local rvy = y + (lvy - halfVoxelPerMeter - 0.5) * metersPerVoxel

                    local voxelTemperature, voxelHumidity = getTemperatureHumidityFromGroundMap(groundMap, rvx, rvy)

                    setBaseVoxel(voxelTemperature, voxelHumidity, groundMap.voxelMap[vx][vy], seed, rvx, rvy, vx, vy)
                end
            end
        end
    end

    return groundMap
end

function groundSystem.destroyMap(groundMap)
    groundMap.seed = nil
    groundMap.temperatureSeed = nil
    groundMap.humiditySeed = nil
    groundMap.length = nil
    groundMap.width = nil
    groundMap.groundMap = nil
    groundMap.voxelMap = nil
end

function groundSystem.createMesh(pTknGfxContext, groundMap)
    local vertices = {
        position = {},
        color = {},
        normal = {},
        pbr = {},
    }
    local voxelPerMeter = groundSystem.voxelPerMeter
    for x = 1, groundMap.length * groundSystem.voxelPerMeter do
        for y = 1, groundMap.width * groundSystem.voxelPerMeter do
            -- print(x, y, groundMap.voxelMap[x], groundMap.voxelMap[x][y])
            for z = 1, #groundMap.voxelMap[x][y], 1 do
                local voxel = groundMap.voxelMap[x][y][z]
                if voxel then
                    table.insert(vertices.position, x)
                    table.insert(vertices.position, y)
                    table.insert(vertices.position, z)
                    table.insert(vertices.color, tknMath.rgbaToAbgr(voxel.color))
                    local normal = calculateNormal(groundMap.voxelMap, x, y, z)
                    table.insert(vertices.normal, normal)
                    local pbr = (voxel.emissive & 0xF) | ((voxel.roughness & 0xF) << 4) | ((voxel.metallic & 0xF) << 8)
                    table.insert(vertices.pbr, pbr)
                end
            end
        end
    end
    local pTknMesh = tkn.tknCreateMeshPtrWithData(pTknGfxContext, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.vertexFormat, vertices, nil, nil)
    local scale = 1.0 / groundSystem.voxelPerMeter
    local pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {
        model = {scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, scale, 0, 0.5, 0.5, scale * -4, 1},
    })
    local pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, pTknMesh, pTknInstance)
    return pTknMesh, pTknInstance, pTknDrawCall
end

function groundSystem.destroyMesh(pTknGfxContext, pTknMesh, pTknInstance, pTknDrawCall)
    tkn.tknDestroyDrawCallPtr(pTknGfxContext, pTknDrawCall)
    tkn.tknDestroyInstancePtr(pTknGfxContext, pTknInstance)
    tkn.tknDestroyMeshPtr(pTknGfxContext, pTknMesh)
end

return groundSystem
