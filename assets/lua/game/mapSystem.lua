local tknMath = require("tknMath")
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
    mapSystem.terrainToTemperature = {1, 1, 4, 4, 4, 7, 7}
    mapSystem.terrainToHumidity = {4, 7, 1, 4, 7, 1, 4}
    mapSystem.temperatureNoiseScale = 0.07
    mapSystem.humidityNoiseScale = 0.07

    mapSystem.temperatureStep = 0.27
    mapSystem.humidityStep = 0.27
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
            terrain = terrain.snow
        elseif humidity < mapSystem.humidityStep then
            terrain = terrain.snow
        else
            terrain = terrain.ice
        end
    elseif temperature < mapSystem.temperatureStep then
        if humidity < -mapSystem.humidityStep then
            terrain = terrain.sand
        elseif humidity < mapSystem.humidityStep then
            terrain = terrain.grass
        else
            terrain = terrain.water
        end
    else
        if humidity < -mapSystem.humidityStep then
            terrain = terrain.lava
        elseif humidity < mapSystem.humidityStep then
            terrain = terrain.volcanic
        else
            terrain = terrain.volcanic
        end
    end

    return terrain
end

function mapSystem.getHumidity(seed, x, y)
    local level = 2
    local humidity = 0
    for i = 1, level do
        local m = 2 ^ (level - 1)
        humidity = humidity + tknMath.perlinNoise2D(seed, x * mapSystem.humidityNoiseScale * m, y * mapSystem.humidityNoiseScale * m) / m
        seed = tknMath.lcgRandom(seed)
    end
    return humidity
end

function mapSystem.getTemperature(seed, x, y)
    local level = 2
    local temperature = 0
    for i = 1, level do
        local m = 2 ^ (level - 1)
        temperature = temperature + tknMath.perlinNoise2D(seed, x * mapSystem.temperatureNoiseScale * m, y * mapSystem.temperatureNoiseScale * m) / m
        seed = tknMath.lcgRandom(seed)
    end
    temperature = temperature + (x / mapSystem.length - 0.5) * 1.0
    return temperature
end

function mapSystem.generateRoom(seed, length, width)
    mapSystem.seed = seed
    mapSystem.temperatureSeed = seed + 1
    mapSystem.humiditySeed = seed + 2
    mapSystem.length = length
    mapSystem.width = width
    mapSystem.terrainMap = {}
    mapSystem.voxelMap = {}
    for x = 1, mapSystem.length do
        mapSystem.terrainMap[x] = {}
        for y = 1, mapSystem.width do
            local temperature = mapSystem.getTemperature(mapSystem.temperatureSeed, x, y)
            local humidity = mapSystem.getHumidity(mapSystem.humiditySeed, x, y)
            mapSystem.terrainMap[x][y] = mapSystem.getTerrain(temperature, humidity)
        end
    end
    
end

return mapSystem
