local tknMath = require("tknMath")

-- Floor types enumeration
local floor = {
    snow = 0,
    ice = 1,
    sand = 2,
    grass = 3,
    water = 4,
    lava = 5,
    volcanic = 6,
}

local game = {
    seed = 0,
    temperatureSeed = 0,
    humiditySeed = 0,
    length = 0,
    width = 0,
    floorMap = nil,
    blockMap = nil,
    humidityStep = 0.21,
    temperatureStep = 0.27,
}

local temperatureNoiseScale = 0.07
local humidityNoiseScale = 0.07

function game.getFloor(temperature, humidity)
    local floor
    if temperature < -game.temperatureStep then
        if humidity < -game.humidityStep then
            floor = floor.snow
        elseif humidity < game.humidityStep then
            floor = floor.snow
        else
            floor = floor.ice
        end
    elseif temperature < game.temperatureStep then
        if humidity < -game.humidityStep then
            floor = floor.sand
        elseif humidity < game.humidityStep then
            floor = floor.grass
        else
            floor = floor.water
        end
    else
        if humidity < -game.humidityStep then
            floor = floor.lava
        elseif humidity < game.humidityStep then
            floor = floor.volcanic
        else
            floor = floor.volcanic
        end
    end

    return floor
end

function game.getHumidity(seed, x, y)
    local level = 2
    local humidity = 0
    for i = 1, level do
        local m = 2 ^ (level - 1)
        humidity = humidity + tknMath.perlinNoise2D(seed, x * humidityNoiseScale * m, y * humidityNoiseScale * m) / m
        seed = tknMath.lcgRandom(seed)
    end
    return humidity
end

function game.getTemperature(seed, x, y)
    local level = 2
    local temperature = 0
    for i = 1, level do
        local m = 2 ^ (level - 1)
        temperature = temperature + tknMath.perlinNoise2D(seed, x * temperatureNoiseScale * m, y * temperatureNoiseScale * m) / m
        seed = tknMath.lcgRandom(seed)
    end
    -- temperature = temperature + (x - (game.length - 1) / 2) / game.length
    return temperature
end

function game.generateWorld(seed, length, width)
    game.seed = seed
    game.temperatureSeed = seed + 1
    game.humiditySeed = seed + 2
    game.length = length
    game.width = width
    local floorMap = {}
    game.blockMap = {}
    for x = 1, game.length do
        floorMap[x] = {}
        for y = 1, game.width do
            local temperature = game.getTemperature(game.temperatureSeed, x, y)
            local humidity = game.getHumidity(game.humiditySeed, x, y)
            floorMap[x][y] = game.getFloor(temperature, humidity)
        end
    end
end
