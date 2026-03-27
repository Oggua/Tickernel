local groundSystem = require("game.groundSystem")
local structureSystem = require("game.structureSystem")
local transformSystem = require("game.transformSystem")
local tknMath = require("tknMath")
local wildMap = {}

local function getHumidity(seed, x, y)
    local humidityNoiseScale = 0.17
    local humidity = tknMath.perlinNoise2D(seed, x * humidityNoiseScale, y * humidityNoiseScale)
    return humidity
end

local function getTemperature(seed, x, y)
    local temperatureNoiseScale = 0.17
    local temperature = tknMath.perlinNoise2D(seed, x * temperatureNoiseScale, y * temperatureNoiseScale)
    return temperature
end

function wildMap.create(pTknGfxContext)
    local map = {
        length = 32,
        width = 32,
        temperatureSeed = 1,
        humiditySeed = 2,
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
    local structureCount = 0
    for x = 1, map.length do
        map.structureMap.spatialMap[x] = {}
        for y = 1, map.width do
            local noise = tknMath.perlinNoise2D(438, x * 0.27, y * 0.27)
            if noise < -0.27 then
                local ground = map.groundMap.groundMap[x][y]
                local structureId
                if ground == groundSystem.ground.snow or ground == groundSystem.ground.ice then
                    structureId = structureSystem.structure.iceWall
                elseif ground == groundSystem.ground.lava or ground == groundSystem.ground.volcanic then
                    structureId = structureSystem.structure.volcanicWall
                else
                    structureId = structureSystem.structure.dirtWall
                end
                local structure = structureSystem.add(pTknGfxContext, map.structureMap, structureId, x, y)
                map.structureMap.spatialMap[x][y] = structure
                structureCount = structureCount + 1

            else

            end
        end
    end
    map.pTknMesh, map.pTknInstance, map.pTknDrawCall = groundSystem.createMesh(pTknGfxContext, map.groundMap)
    -- Compute all structure transforms before updating instances
    transformSystem.update()
    structureSystem.updateInstances(pTknGfxContext, map.structureMap)
    return map
end

function wildMap.destroy(pTknGfxContext, map)
    if map.structureMap and map.structureMap.spatialMap then
        for x = 1, map.length do
            if map.structureMap.spatialMap[x] then
                for y = 1, map.width do
                    local structure = map.structureMap.spatialMap[x][y]
                    if structure then
                        structureSystem.remove(map.structureMap, structure)
                    end
                end
            end
        end
    end
    groundSystem.destroyMesh(pTknGfxContext, map.pTknMesh, map.pTknInstance, map.pTknDrawCall)
    groundSystem.destroyMap(map.groundMap)
    map.structureMap = nil
end

return wildMap
