local tknMath = require("tknMath")
local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local voxelConfig = require("game.voxelConfig")
local mapSystem = {}

function mapSystem.setup()
    mapSystem.ground = {
        snow = 1,
        ice = 2,
        sand = 3,
        grass = 4,
        water = 5,
        lava = 6,
        volcanic = 7,
    }
    mapSystem.groundToTemperature = {-1, -1, 0, 0, 0, 1, 1}
    mapSystem.groundToHumidity = {0, 1, -1, 0, 1, -1, 0}

    mapSystem.groundToTemperatureVariance = {0.15, 0.15, 0.18, 0.18, 0.15, 0.15, 0.15}
    mapSystem.groundToHumidityVariance = {0.15, 0.12, 0.15, 0.18, 0.12, 0.12, 0.15}

    mapSystem.temperatureNoiseScale = 0.37
    mapSystem.humidityNoiseScale = 0.37

    mapSystem.temperatureStep = 0.27
    mapSystem.humidityStep = 0.27
end

function mapSystem.teardown()
    mapSystem.temperatureStep = nil
    mapSystem.humidityStep = nil
    mapSystem.temperatureNoiseScale = nil
    mapSystem.humidityNoiseScale = nil

    mapSystem.ground = nil
    mapSystem.groundToTemperature = nil
    mapSystem.groundToHumidity = nil
    mapSystem.groundToTemperatureVariance = nil
    mapSystem.groundToHumidityVariance = nil

    -- Fields set by generateRoom
    mapSystem.seed = nil
    mapSystem.temperatureSeed = nil
    mapSystem.humiditySeed = nil
    mapSystem.length = nil
    mapSystem.width = nil
    mapSystem.groundMap = nil
    mapSystem.voxelMap = nil
    mapSystem.voxelPerMeter = nil
end

function mapSystem.getGround(temperature, humidity)
    local ground
    if temperature < -mapSystem.temperatureStep then
        if humidity < -mapSystem.humidityStep then
            ground = mapSystem.ground.snow
        elseif humidity < mapSystem.humidityStep then
            ground = mapSystem.ground.snow
        else
            ground = mapSystem.ground.ice
        end
    elseif temperature < mapSystem.temperatureStep then
        if humidity < -mapSystem.humidityStep then
            ground = mapSystem.ground.sand
        elseif humidity < mapSystem.humidityStep then
            ground = mapSystem.ground.grass
        else
            ground = mapSystem.ground.water
        end
    else
        if humidity < -mapSystem.humidityStep then
            ground = mapSystem.ground.lava
        elseif humidity < mapSystem.humidityStep then
            ground = mapSystem.ground.volcanic
        else
            ground = mapSystem.ground.volcanic
        end
    end

    return ground
end

function mapSystem.getHumidity(seed, x, y)
    local humidity = tknMath.perlinNoise2D(seed, x * mapSystem.humidityNoiseScale, y * mapSystem.humidityNoiseScale)
    return humidity
end

function mapSystem.getTemperature(seed, x, y)
    local temperature = tknMath.perlinNoise2D(seed, x * mapSystem.temperatureNoiseScale, y * mapSystem.temperatureNoiseScale)
    -- local t = (1.0 * y / mapSystem.width - 0.5)
    -- temperature = temperature * temperature * temperature + t * t * t * 5
    return temperature
end

-- Returns temperature and humidity for a single ground cell at integer coords (gx, gy),
-- with LCG-based fluctuation whose range is determined by the ground type.
local function getGroundTempHumidity(gx, gy)
    gx = math.max(1, math.min(mapSystem.length, math.floor(gx)))
    gy = math.max(1, math.min(mapSystem.width, math.floor(gy)))

    local ground = mapSystem.groundMap[gx][gy]
    local baseTemp = mapSystem.groundToTemperature[ground]
    local baseHumidity = mapSystem.groundToHumidity[ground]
    local tempVariance = mapSystem.groundToTemperatureVariance[ground]
    local humidVariance = mapSystem.groundToHumidityVariance[ground]

    local pairKey = tknMath.cantorPair(gx, gy)
    local tempRand = tknMath.lcgRandom(mapSystem.temperatureSeed + pairKey)
    local humidRand = tknMath.lcgRandom(mapSystem.humiditySeed + pairKey)

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

local function getTemperatureHumidityFromGroundMap(rvx, rvy)
    local gx0 = math.floor(rvx)
    local gy0 = math.floor(rvy)
    local gx1 = gx0 + 1
    local gy1 = gy0 + 1
    -- Apply sharpening so each cell's centre strongly dominates
    local tx = sharpenT(rvx - gx0)
    local ty = sharpenT(rvy - gy0)

    local t00, h00 = getGroundTempHumidity(gx0, gy0)
    local t10, h10 = getGroundTempHumidity(gx1, gy0)
    local t01, h01 = getGroundTempHumidity(gx0, gy1)
    local t11, h11 = getGroundTempHumidity(gx1, gy1)

    local temperature = tknMath.lerp(tknMath.lerp(t00, t10, tx), tknMath.lerp(t01, t11, tx), ty)
    local humidity = tknMath.lerp(tknMath.lerp(h00, h10, tx), tknMath.lerp(h01, h11, tx), ty)
    return temperature, humidity
end

local function setBaseVoxel(temperature, humidity, columnVoxels, seed, rvx, rvy, vx, vy)
    local voxel
    local ground = mapSystem.getGround(temperature, humidity)
    local height
    if ground == mapSystem.ground.snow or ground == mapSystem.ground.ice then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 14, rvy * 14)
        noise = noise * noise * noise
        voxel = voxelConfig.rock
        height = (noise + 1) * 1.5
    elseif ground == mapSystem.ground.sand or ground == mapSystem.ground.grass or ground == mapSystem.ground.water then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 7.77, rvy * 7.77)
        voxel = voxelConfig.dirt
        height = (noise + 1) * 1.5
    elseif ground == mapSystem.ground.lava or ground == mapSystem.ground.volcanic then
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

    if ground == mapSystem.ground.snow then
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
    elseif ground == mapSystem.ground.ice then
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
    elseif ground == mapSystem.ground.sand then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 2, rvy * 2)
        local voxel
        if noise > 0.27 then
            height = 4
        elseif noise > -0.27 then
            height = 3
        else
            height = 2
        end
        noise = tknMath.lcgRandom(seed + tknMath.cantorPair(vx, vy)) % 16
        if noise < 2 then
            voxel = voxelConfig.lightSand
        else
            voxel = voxelConfig.sand
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == mapSystem.ground.grass then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 21, rvy * 21)
        local voxel
        if noise > 0.6 then
            voxel = voxelConfig.darkGrass
            height = 3
        elseif noise > -0.6 then
            voxel = voxelConfig.dirt
            height = 1
        else
            voxel = voxelConfig.lightGrass
            height = 2
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == mapSystem.ground.water then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 1, rvy * 3)
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
    elseif ground == mapSystem.ground.lava then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 2, rvy * 2)
        local voxel = voxelConfig.lava
        if noise > 0 then
            height = 3
        else
            height = 2
        end
        for h = 1, height, 1 do
            if not columnVoxels[h] then
                columnVoxels[h] = voxel
            end
        end
    elseif ground == mapSystem.ground.volcanic then
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
    local ground = mapSystem.getGround(temperature, humidity)
    if ground == mapSystem.ground.snow then
        return voxelConfig.snow
    elseif ground == mapSystem.ground.ice then
        return voxelConfig.ice
    elseif ground == mapSystem.ground.sand then
        return voxelConfig.sand
    elseif ground == mapSystem.ground.grass then
        return voxelConfig.grass
    elseif ground == mapSystem.ground.water then
        return voxelConfig.water
    elseif ground == mapSystem.ground.lava then
        return voxelConfig.lava
    elseif ground == mapSystem.ground.volcanic then
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
-- whose values are mapSystem.ground constants.  When omitted the groundMap is built
-- from Perlin-noise temperature / humidity as before.
function mapSystem.generateRoom(seed, length, width, voxelPerMeter, groundMap)
    mapSystem.seed = seed
    mapSystem.temperatureSeed = seed + 1
    mapSystem.humiditySeed = seed + 2
    mapSystem.length = length
    mapSystem.width = width
    mapSystem.voxelPerMeter = voxelPerMeter
    mapSystem.groundMap = groundMap

    -- Build or adopt the ground map
    if groundMap then
    else
        mapSystem.groundMap = {}
        for x = 1, mapSystem.length do
            mapSystem.groundMap[x] = {}
            for y = 1, mapSystem.width do
                local temperature = mapSystem.getTemperature(mapSystem.temperatureSeed, x, y)
                local humidity = mapSystem.getHumidity(mapSystem.humiditySeed, x, y)
                mapSystem.groundMap[x][y] = mapSystem.getGround(temperature, humidity)
            end
        end
    end

    -- Generate voxel map.
    -- Temperature/humidity for each voxel are derived from the 4 surrounding
    -- ground cells via bilinear interpolation + per-ground-type LCG fluctuation.
    local metersPerVoxel = 1 / voxelPerMeter
    local halfVoxelPerMeter = voxelPerMeter / 2
    mapSystem.voxelMap = {}
    for x = 1, mapSystem.length do
        for y = 1, mapSystem.width do
            for lvx = 1, voxelPerMeter do
                local vx = (x - 1) * voxelPerMeter + lvx
                if not mapSystem.voxelMap[vx] then
                    mapSystem.voxelMap[vx] = {}
                end

                for lvy = 1, voxelPerMeter do
                    local vy = (y - 1) * voxelPerMeter + lvy
                    if not mapSystem.voxelMap[vx][vy] then
                        mapSystem.voxelMap[vx][vy] = {}
                    end
                    -- Real-space position of this voxel in ground-cell coordinates
                    local rvx = x + (lvx - halfVoxelPerMeter - 0.5) * metersPerVoxel
                    local rvy = y + (lvy - halfVoxelPerMeter - 0.5) * metersPerVoxel

                    local voxelTemperature, voxelHumidity = getTemperatureHumidityFromGroundMap(rvx, rvy)

                    setBaseVoxel(voxelTemperature, voxelHumidity, mapSystem.voxelMap[vx][vy], seed, rvx, rvy, vx, vy)
                end
            end
        end
    end
end

function mapSystem.createMesh(pTknGfxContext)
    local vertices = {
        position = {},
        color = {},
        normal = {},
        pbr = {},
    }
    local voxelPerMeter = mapSystem.voxelPerMeter
    for x = 1, mapSystem.length * mapSystem.voxelPerMeter do
        for y = 1, mapSystem.width * mapSystem.voxelPerMeter do
            -- print(x, y, mapSystem.voxelMap[x], mapSystem.voxelMap[x][y])
            for z = 1, #mapSystem.voxelMap[x][y], 1 do
                local voxel = mapSystem.voxelMap[x][y][z]
                if voxel then
                    table.insert(vertices.position, x)
                    table.insert(vertices.position, y)
                    table.insert(vertices.position, z)
                    table.insert(vertices.color, tknMath.rgbaToAbgr(voxel.color))
                    local normal = calculateNormal(mapSystem.voxelMap, x, y, z)
                    table.insert(vertices.normal, normal)
                    local pbr = (voxel.emissive & 0xF) | ((voxel.roughness & 0xF) << 4) | ((voxel.metallic & 0xF) << 8)
                    table.insert(vertices.pbr, pbr)
                end
            end
        end
    end
    local pTknMesh = tkn.tknCreateMeshPtrWithData(pTknGfxContext, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.vertexFormat, vertices, nil, nil)
    local scale = 1.0 / mapSystem.voxelPerMeter
    local pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {
        model = {scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, scale, 0, 0.5, 0.5, scale * -2, 1},
    })
    local pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, pTknMesh, pTknInstance)
    return pTknMesh, pTknInstance, pTknDrawCall
end

function mapSystem.destroyMesh(pTknGfxContext, pTknMesh, pTknInstance, pTknDrawCall)
    tkn.tknDestroyDrawCallPtr(pTknGfxContext, pTknDrawCall)
    tkn.tknDestroyInstancePtr(pTknGfxContext, pTknInstance)
    tkn.tknDestroyMeshPtr(pTknGfxContext, pTknMesh)
end

return mapSystem
