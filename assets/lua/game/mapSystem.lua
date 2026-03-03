local tknMath = require("tknMath")
local tkn = require("tkn")
local deferredRenderPass = require("deferredRenderer.deferredRenderPass")
local mapSystem = {}

function mapSystem.setup()
    mapSystem.terrain = {
        snow = 1,
        ice = 2,
        sand = 3,
        grass = 4,
        water = 5,
        lava = 6,
        volcanic = 7,
    }
    mapSystem.terrainToTemperature = {-1, -1, 0, 0, 0, 1, 1}
    mapSystem.terrainToHumidity = {0, 1, -1, 0, 1, -1, 0}
    mapSystem.temperatureNoiseScale = 0.37
    mapSystem.humidityNoiseScale = 0.37

    mapSystem.temperatureStep = 0.27
    mapSystem.humidityStep = 0.27

    mapSystem.voxel = {
        baseRock = {
            name = "baseRock",
            color = tknMath.rgbaToAbgr(0x080808FF),
            emissive = 0,
            roughness = 14, -- 地底岩石，极粗糙
            metallic = 0,
        },
        darkDirt = {
            name = "darkDirt",
            color = tknMath.rgbaToAbgr(0x654321FF),
            emissive = 0,
            roughness = 14, -- 湿润泥土，极粗糙
            metallic = 0,
        },
        dirt = {
            name = "dirt",
            color = tknMath.rgbaToAbgr(0x8B4513FF),
            emissive = 0,
            roughness = 13, -- 普通泥土
            metallic = 0,
        },
        lightDirt = {
            name = "lightDirt",
            color = tknMath.rgbaToAbgr(0xA0522DFF),
            emissive = 0,
            roughness = 12, -- 干燥表层土
            metallic = 0,
        },
        darkRock = {
            name = "darkRock",
            color = tknMath.rgbaToAbgr(0x111111FF),
            emissive = 0,
            roughness = 13, -- 粗糙深色岩石
            metallic = 0,
        },
        rock = {
            name = "rock",
            color = tknMath.rgbaToAbgr(0x171717FF),
            emissive = 0,
            roughness = 12, -- 普通岩石
            metallic = 0,
        },
        lightRock = {
            name = "lightRock",
            color = tknMath.rgbaToAbgr(0x212121FF),
            emissive = 0,
            roughness = 10, -- 较光滑的浅色岩石
            metallic = 0,
        },
        darkGrass = {
            name = "darkGrass",
            color = tknMath.rgbaToAbgr(0x6B8E23FF),
            emissive = 0,
            roughness = 13, -- 草叶漫反射，很粗糙
            metallic = 0,
        },
        grass = {
            name = "grass",
            color = tknMath.rgbaToAbgr(0x9ACD32FF),
            emissive = 0,
            roughness = 12, -- 普通草地
            metallic = 0,
        },
        lightGrass = {
            name = "lightGrass",
            color = tknMath.rgbaToAbgr(0xBDB76BFF),
            emissive = 0,
            roughness = 11, -- 浅草/枯草稍光滑
            metallic = 0,
        },
        sand = {
            name = "sand",
            color = tknMath.rgbaToAbgr(0xD4B368FF),
            emissive = 0,
            roughness = 11, -- 沙粒细腻，比岩石光滑
            metallic = 0,
        },
        lightSand = {
            name = "lightSand",
            color = tknMath.rgbaToAbgr(0xD4B388FF),
            emissive = 0,
            roughness = 9, -- 浅色沙，更细腻
            metallic = 0,
        },
        water = {
            name = "water",
            color = tknMath.rgbaToAbgr(0x41A5FFFF),
            emissive = 0,
            roughness = 0, -- 水面接近镜面
            metallic = 1, -- 半金属：产生镜面反射带蓝色调
        },
        lava = {
            name = "lava",
            color = tknMath.rgbaToAbgr(0xEE1F00FF),
            emissive = 8,
            roughness = 8, -- 流动熔岩有橘色高光
            metallic = 0,
        },
        ice = {
            name = "ice",
            color = tknMath.rgbaToAbgr(0xADD8E6FF),
            emissive = 0,
            roughness = 1, -- 冰面极光滑
            metallic = 1, -- 轻微镜面反射感
        },
        snow = {
            name = "snow",
            color = tknMath.rgbaToAbgr(0xFFFFFF80),
            emissive = 0,
            roughness = 14, -- 雪花结构，极强漫反射
            metallic = 0,
        },
    }
end

function mapSystem.teardown()
    mapSystem.temperatureStep = nil
    mapSystem.humidityStep = nil

    mapSystem.terrain = nil
    mapSystem.terrainToTemperature = nil
    mapSystem.terrainToHumidity = nil
end

function mapSystem.getTerrain(temperature, humidity)
    local terrain
    if temperature < -mapSystem.temperatureStep then
        if humidity < -mapSystem.humidityStep then
            terrain = mapSystem.terrain.snow
        elseif humidity < mapSystem.humidityStep then
            terrain = mapSystem.terrain.snow
        else
            terrain = mapSystem.terrain.ice
        end
    elseif temperature < mapSystem.temperatureStep then
        if humidity < -mapSystem.humidityStep then
            terrain = mapSystem.terrain.sand
        elseif humidity < mapSystem.humidityStep then
            terrain = mapSystem.terrain.grass
        else
            terrain = mapSystem.terrain.water
        end
    else
        if humidity < -mapSystem.humidityStep then
            terrain = mapSystem.terrain.lava
        elseif humidity < mapSystem.humidityStep then
            terrain = mapSystem.terrain.volcanic
        else
            terrain = mapSystem.terrain.volcanic
        end
    end

    return terrain
end

function mapSystem.getHumidity(seed, x, y)
    local level = 2
    local humidity = tknMath.perlinNoise2D(seed, x * mapSystem.humidityNoiseScale, y * mapSystem.humidityNoiseScale)
    return humidity
end

function mapSystem.getTemperature(seed, x, y)
    local level = 2
    local temperature = tknMath.perlinNoise2D(seed, x * mapSystem.temperatureNoiseScale, y * mapSystem.temperatureNoiseScale)
    local t = (1.0 * y / mapSystem.width - 0.5)
    temperature = temperature * temperature * temperature + t * t * t * 5
    return temperature
end

local function setBaseVoxel(temperature, humidity, columnVoxels, seed, rvx, rvy, vx, vy)
    local voxel
    local terrain = mapSystem.getTerrain(temperature, humidity)
    local height
    if terrain == mapSystem.terrain.snow or terrain == mapSystem.terrain.ice then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 14, rvy * 14)
        noise = noise * noise * noise
        voxel = mapSystem.voxel.rock
        height = (noise + 1) * 0.5 * 5
    elseif terrain == mapSystem.terrain.sand or terrain == mapSystem.terrain.grass or terrain == mapSystem.terrain.water then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 7.77, rvy * 7.77)
        local step = 0.2
        voxel = mapSystem.voxel.dirt
        height = (noise + 1) * 0.5 * 5
    elseif terrain == mapSystem.terrain.lava or terrain == mapSystem.terrain.volcanic then
        local noise = tknMath.perlinNoise2D(seed + 54213, rvx * 17, rvy * 17)
        noise = noise * noise * noise
        voxel = mapSystem.voxel.darkRock
        height = (noise + 1) * 0.5 * 6
    else
        error("Unsupported terrain for base voxel: " .. terrain)
    end

    for h = 1, height, 1 do
        -- columnVoxels[1 + h] = voxels[tknMath.lcgRandom(seed + vx + vy + h) % #voxels + 1]
        columnVoxels[1 + h] = voxel
    end

    if terrain == mapSystem.terrain.snow then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 4, rvy * 4)
        local voxel = mapSystem.voxel.snow
        local step = 0.2
        if noise > step then
            height = 5
        elseif noise > -step then
            height = 4
        else
            height = 3
        end
        for h = 1, height, 1 do
            if not columnVoxels[1 + h] then
                columnVoxels[1 + h] = voxel
            end
        end
    elseif terrain == mapSystem.terrain.ice then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 4, rvy * 4)
        local voxel = mapSystem.voxel.ice
        local step = 0.4
        if noise > step then
            height = 4
        elseif noise > -step then
            height = 3
        else
            height = 2
        end
        for h = 1, height, 1 do
            if not columnVoxels[1 + h] then
                columnVoxels[1 + h] = voxel
            end
        end
    elseif terrain == mapSystem.terrain.sand then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 2, rvy * 2)
        local voxel
        if noise > 0.27 then
            height = 5
        elseif noise > -0.27 then
            height = 4
        else
            height = 3
        end
        noise = tknMath.lcgRandom(seed + tknMath.cantorPair(vx, vy)) % 16
        if noise < 2 then
            voxel = mapSystem.voxel.lightSand
        else
            voxel = mapSystem.voxel.sand
        end
        for h = 1, height, 1 do
            if not columnVoxels[1 + h] then
                columnVoxels[1 + h] = voxel
            end
        end
    elseif terrain == mapSystem.terrain.grass then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 21, rvy * 21)
        local voxel
        if noise > 0.5 then
            voxel = mapSystem.voxel.darkGrass
            height = 5
        elseif noise > -0.5 then
            voxel = mapSystem.voxel.dirt
            height = 2
        else
            voxel = mapSystem.voxel.lightGrass
            height = 4
        end
        for h = 1, height, 1 do
            if not columnVoxels[1 + h] then
                columnVoxels[1 + h] = voxel
            end
        end
    elseif terrain == mapSystem.terrain.water then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 1, rvy * 3)
        local voxel = mapSystem.voxel.water
        if noise > 0 then
            height = 5
        else
            height = 4
        end
        for h = 1, height, 1 do
            if not columnVoxels[1 + h] then
                columnVoxels[1 + h] = voxel
            end
        end
    elseif terrain == mapSystem.terrain.lava then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 2, rvy * 2)
        local voxel = mapSystem.voxel.lava
        if noise > 0 then
            height = 4
        else
            height = 3
        end
        for h = 1, height, 1 do
            if not columnVoxels[1 + h] then
                columnVoxels[1 + h] = voxel
            end
        end
    elseif terrain == mapSystem.terrain.volcanic then
        local noise = tknMath.perlinNoise2D(seed + 21, rvx * 21, rvy * 21)
        local voxel
        if noise > 0.3 then
            voxel = mapSystem.voxel.rock
            height = 5
        elseif noise > -0.3 then
            voxel = mapSystem.voxel.lightRock
            height = 4
        else
            voxel = mapSystem.voxel.lava
            height = 3
        end
        for h = 1, height, 1 do
            if not columnVoxels[1 + h] then
                columnVoxels[1 + h] = voxel
            end
        end
    else
        error("Unsupported terrain for base voxel: " .. terrain)
    end

end

local function getSurfaceVoxel(temperature, humidity)
    local terrain = mapSystem.getTerrain(temperature, humidity)
    if terrain == mapSystem.terrain.snow then
        return mapSystem.voxel.snow
    elseif terrain == mapSystem.terrain.ice then
        return mapSystem.voxel.ice
    elseif terrain == mapSystem.terrain.sand then
        return mapSystem.voxel.sand
    elseif terrain == mapSystem.terrain.grass then
        return mapSystem.voxel.grass
    elseif terrain == mapSystem.terrain.water then
        return mapSystem.voxel.water
    elseif terrain == mapSystem.terrain.lava then
        return mapSystem.voxel.lava
    elseif terrain == mapSystem.terrain.volcanic then
        return mapSystem.voxel.volcanic
    end
end

function mapSystem.generateRoom(seed, length, width, voxelPerMeter)
    mapSystem.seed = seed
    mapSystem.temperatureSeed = seed + 1
    mapSystem.humiditySeed = seed + 2
    mapSystem.length = length
    mapSystem.width = width
    mapSystem.terrainMap = {}
    mapSystem.voxelPerMeter = voxelPerMeter
    for x = 1, mapSystem.length do
        mapSystem.terrainMap[x] = {}
        for y = 1, mapSystem.width do
            local temperature = mapSystem.getTemperature(mapSystem.temperatureSeed, x, y)
            local humidity = mapSystem.getHumidity(mapSystem.humiditySeed, x, y)
            mapSystem.terrainMap[x][y] = mapSystem.getTerrain(temperature, humidity)
        end
    end

    -- Generate voxel map based on terrain map
    local metersPerVoxel = 1 / voxelPerMeter
    local halfVoxelPerMeter = voxelPerMeter / 2
    mapSystem.voxelMap = {}
    for x = 1, mapSystem.length do
        for y = 1, mapSystem.width do
            local terrain = mapSystem.terrainMap[x][y]
            local temperature = mapSystem.terrainToTemperature[terrain]
            local humidity = mapSystem.terrainToHumidity[terrain]
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
                    local rvx = (x + (lvx - halfVoxelPerMeter - 0.5) * metersPerVoxel)
                    local rvy = (y + (lvy - halfVoxelPerMeter - 0.5) * metersPerVoxel)
                    local voxelTemperature = mapSystem.getTemperature(mapSystem.temperatureSeed, rvx * mapSystem.temperatureNoiseScale, rvy * mapSystem.temperatureNoiseScale)
                    local voxelHumidity = mapSystem.getHumidity(mapSystem.humiditySeed, rvx * mapSystem.humidityNoiseScale, rvy * mapSystem.humidityNoiseScale)
                    local t = (math.abs(halfVoxelPerMeter - 0.5 - lvx) + math.abs(halfVoxelPerMeter - 0.5 - lvy)) / (voxelPerMeter - 1)
                    t = t * t * t

                    voxelTemperature = tknMath.lerp(temperature, voxelTemperature, t)
                    voxelHumidity = tknMath.lerp(humidity, voxelHumidity, t)
                    mapSystem.voxelMap[vx][vy][1] = mapSystem.voxel.baseRock
                    setBaseVoxel(voxelTemperature, voxelHumidity, mapSystem.voxelMap[vx][vy], seed, rvx, rvy, vx, vy)
                end
            end
        end
    end
end

local function calculateNormal(voxelMap, x, y, z)
    local mask = 0
    -- 必须与 opaqueGeometry.vert 中 normalTable[26] 顺序完全一致
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
                    table.insert(vertices.color, voxel.color)
                    local normal = calculateNormal(mapSystem.voxelMap, x, y, z)
                    table.insert(vertices.normal, normal)
                    -- bits[0-3]=emissive, bits[4-7]=roughness, bits[8-11]=metallic
                    -- clamp to 0-15 to fit in 4 bits each
                    local pbr = (voxel.emissive & 0xF) | ((voxel.roughness & 0xF) << 4) | ((voxel.metallic & 0xF) << 8)
                    table.insert(vertices.pbr, pbr)
                end
            end
        end
    end
    print(tknMath.minN, tknMath.maxN, "!@!#!")
    local pTknMesh = tkn.tknCreateMeshPtrWithData(pTknGfxContext, deferredRenderPass.pVoxelVertexInputLayout, deferredRenderPass.vertexFormat, vertices, nil, nil)

    local scale = 1.0 / mapSystem.voxelPerMeter
    local pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, deferredRenderPass.pInstanceVertexInputLayout, deferredRenderPass.instanceFormat, {
        model = {scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1},
    })
    local pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, deferredRenderPass.pGeometryPipeline, deferredRenderPass.pGeometryMaterial, pTknMesh, pTknInstance)
    return pTknMesh, pTknInstance, pTknDrawCall
end

function mapSystem.destroyMesh(pTknMesh, pTknInstance, pTknDrawCall)
    tkn.tknDestroyDrawCallPtr(pTknDrawCall)
    tkn.tknDestroyInstancePtr(pTknInstance)
    tkn.tknDestroyMeshPtr(pTknMesh)
end

return mapSystem
