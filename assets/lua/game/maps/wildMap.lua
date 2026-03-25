local groundSystem = require("game.groundSystem")
local structureSystem = require("game.structureSystem")
local tknMath = require("tknMath")
local wildMap = {}

local function getHumidity(seed, x, y)
    local humidityNoiseScale = 0.37
    local humidity = tknMath.perlinNoise2D(seed, x * humidityNoiseScale, y * humidityNoiseScale)
    return humidity
end

local function getTemperature(seed, x, y)
    local temperatureNoiseScale = 0.37
    local temperature = tknMath.perlinNoise2D(seed, x * temperatureNoiseScale, y * temperatureNoiseScale)
    return temperature
end
function wildMap.create(pTknGfxContext, voxelPerMeter)
    groundSystem.voxelPerMeter = voxelPerMeter
    local map = {
        length = 64,
        width = 64,
    }
    local inputGroundMap = {}
    for x = 1, map.length do
        inputGroundMap[x] = {}
        for y = 1, map.width do
            local temperature = getTemperature(map.temperatureSeed, x, y)
            local humidity = getHumidity(map.humiditySeed, x, y)
            inputGroundMap[x][y] = groundSystem.getGround(temperature, humidity)
        end
    end
    map.groundMap = groundSystem.createMap(0, map.length, map.width, inputGroundMap)
    map.structureMap = structureSystem.createMap(map.length, map.width)
    for x = 1, map.length do
        map.structureMap[x] = {}
        for y = 1, map.width do
            local random = tknMath.lcgRandom(tknMath.cantorPair(x, y) + 321312) -- 321312 is just a random number to make the pattern different from the ground noise
            random = random % 100
            if random < 5 then

            else
            end

        end
    end
    return map
end

function wildMap.destroy(map)

    groundSystem.destroyMap(map.groundMap)
    structureSystem.destroyMap(map.structureMap)
end

return wildMap
