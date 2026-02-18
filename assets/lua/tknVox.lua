local tknMath = require("tknMath")
local tknVox = {}

local tknVoxelType = {
    int8 = 0,
    uint8 = 1,
    int16 = 2,
    uint16 = 3,
    int32 = 4,
    uint32 = 5,
    float32 = 6,
}

-- Maps Tickernel voxel types to Lua string.unpack format
local tknVoxelTypeToLuaUnpack = {
    [0] = "<i1", -- TKN_VOXEL_INT8
    [1] = "<I1", -- TKN_VOXEL_UINT8
    [2] = "<i2", -- TKN_VOXEL_INT16
    [3] = "<I2", -- TKN_VOXEL_UINT16
    [4] = "<i4", -- TKN_VOXEL_INT32
    [5] = "<I4", -- TKN_VOXEL_UINT32
    [6] = "<f", -- TKN_VOXEL_FLOAT32
}

-- Maps Tickernel voxel types to tkn type constants
local tknVoxelTypeToTknType = {
    [0] = 4, -- tkn.type.int8
    [1] = 0, -- tkn.type.uint8
    [2] = 2, -- tkn.type.int16
    [3] = 1, -- tkn.type.uint16
    [4] = 6, -- tkn.type.int32
    [5] = 2, -- tkn.type.uint32
    [6] = 8, -- tkn.type.float
}

local nodeType = {
    air = 0,
    stone = 1,
    water = 2,
    snow = 3,
    ice = 4,
    dirt = 5,
    grass = 6,
    lava = 7,
}

local nodeTypeToColor = {
    [nodeType.air] = 0x00000000, -- 透明
    [nodeType.stone] = 0xA6A28BFF, -- 柔和岩石灰（温暖灰褐色）
    [nodeType.water] = 0x6DB7DFFF, -- 柔和湖蓝色
    [nodeType.snow] = 0xF6F1E7FF, -- 柔和米白色
    [nodeType.ice] = 0xBEE3E9FF, -- 冰蓝青色
    [nodeType.dirt] = 0xB89B72FF, -- 柔和土黄色
    [nodeType.grass] = 0xA8C97FFF, -- 柔和草绿色
    [nodeType.lava] = 0xF7A072FF, -- 柔和橙红色
}

local biome = {
    
}

local function swizzle_color_to_packed(hex)
    -- Convert human 0xRRGGBBAA to stored uint where little-endian bytes are R,G,B,A
    local r = (hex >> 24) & 0xFF
    local g = (hex >> 16) & 0xFF
    local b = (hex >> 8) & 0xFF
    local a = hex & 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r
end

-- ============================================================================
-- TickernelVoxel Deserialization (moved from tkn.lua)
-- ============================================================================

function tknVox.deserializeTickernelVoxel(path)
    local file = io.open(path, "rb")
    if not file then
        return nil, "Failed to open file: " .. tostring(path)
    end

    local content = file:read("*all")
    file:close()

    if not content or #content == 0 then
        return nil, "Empty file: " .. tostring(path)
    end

    local offset = 1

    local function unpackOne(fmt)
        if offset > #content then
            return nil, "Unexpected EOF while reading " .. fmt
        end
        local value
        value, offset = string.unpack(fmt, content, offset)
        return value
    end

    local propertyCount = unpackOne("<I4")
    if propertyCount == nil then
        return nil, "Failed to read propertyCount"
    end

    local names = {}
    for i = 1, propertyCount do
        local length = unpackOne("<I4")
        if length == nil then
            return nil, "Failed to read name length at index " .. i
        end
        if length == 0 then
            names[i] = ""
        else
            local nameRaw = content:sub(offset, offset + length - 1)
            if #nameRaw ~= length then
                return nil, "Unexpected EOF while reading name at index " .. i
            end
            offset = offset + length
            names[i] = nameRaw:gsub("\0+$", "")
        end
    end

    local types = {}
    for i = 1, propertyCount do
        local value = unpackOne("<I4")
        if value == nil then
            return nil, "Failed to read property type at index " .. i
        end
        types[i] = value
    end

    local vertexCount = unpackOne("<I4")
    if vertexCount == nil then
        return nil, "Failed to read vertexCount"
    end

    local indexToProperties = {}
    for i = 1, propertyCount do
        local voxelType = types[i]
        local unpackFmt = tknVoxelTypeToLuaUnpack[voxelType]
        if not unpackFmt then
            return nil, "Unknown voxel type at index " .. i .. ": " .. tostring(voxelType)
        end

        local propertyValues = {}
        for j = 1, vertexCount do
            local value = unpackOne(unpackFmt)
            if value == nil then
                return nil, "Failed to read property data at property " .. i .. ", vertex " .. j
            end
            propertyValues[j] = value
        end
        indexToProperties[i] = propertyValues
    end

    return {
        propertyCount = propertyCount,
        names = names,
        types = types,
        vertexCount = vertexCount,
        indexToProperties = indexToProperties,
    }
end

function tknVox.buildFormatFromTickernelVoxel(pTickernelVoxel)
    local format = {}
    for i = 1, pTickernelVoxel.propertyCount do
        local name = pTickernelVoxel.names[i]
        local voxelType = pTickernelVoxel.types[i]
        local tknType = tknVoxelTypeToTknType[voxelType]
        if not tknType then
            return nil, "Unsupported voxel property type at index " .. i .. ": " .. tostring(voxelType)
        end
        format[i] = {
            name = name,
            type = tknType,
            count = 1,
        }
    end
    return format
end

-- ============================================================================
-- Load .tknvox file and convert to mesh data format
-- ============================================================================

function tknVox.loadVoxFile(filePath)
    local pTickernelVoxel, deserializeError = tknVox.deserializeTickernelVoxel(filePath)
    if not pTickernelVoxel then
        print("tknVox.loadVoxFile: " .. deserializeError)
        return nil
    end

    local vertices = {
        position = {},
        color = {},
        normal = {},
    }

    -- Format: px (int16), py (int16), pz (int16), color (uint32), normal (uint32)
    for i = 1, pTickernelVoxel.vertexCount do
        local px = pTickernelVoxel.indexToProperties[1][i]
        local py = pTickernelVoxel.indexToProperties[2][i]
        local pz = pTickernelVoxel.indexToProperties[3][i]
        local color = pTickernelVoxel.indexToProperties[4][i]
        local normal = pTickernelVoxel.indexToProperties[5][i]

        local positionBase = (i - 1) * 3
        vertices.position[positionBase + 1] = px
        vertices.position[positionBase + 2] = py
        vertices.position[positionBase + 3] = pz
        vertices.color[i] = color
        vertices.normal[i] = normal
    end

    return vertices
end


-- ============================================================================
-- Terrain Generation
-- ============================================================================

local function buildTerrain(length, height)
    -- X,Y = 水平面, Z = 高度
    local terrain = {}
    local tempMin, tempMax = math.huge, -math.huge
    for x = 0, length do
        terrain[x] = {}
        for y = 0, length do
            terrain[x][y] = {}
            local heightNoise = (tknMath.perlinNoise2D(2313, x * 0.007, y * 0.007) * 0.5 + tknMath.perlinNoise2D(2313, x * 0.047, y * 0.047) * 0.25 + tknMath.perlinNoise2D(2313, x * 0.11, y * 0.11) * 0.125 + 1) * 0.5
            local temperatrueNoise = tknMath.perlinNoise2D(654, x * 0.017, y * 0.017)
            if temperatrueNoise < tempMin then
                tempMin = temperatrueNoise
            end
            if temperatrueNoise > tempMax then
                tempMax = temperatrueNoise
            end

            local humidityNoise = tknMath.perlinNoise2D(5489, x * 0.017, y * 0.017)
            local finalHeight = math.floor(tknMath.clamp(heightNoise * height, 0, height))
            for z = 0, height do
                if z <= finalHeight then
                    if temperatrueNoise > 0.3 and humidityNoise > 0.3 then
                        terrain[x][y][z] = nodeType.grass
                    elseif temperatrueNoise > 0.3 and humidityNoise <= 0.3 then
                        terrain[x][y][z] = nodeType.dirt
                    elseif temperatrueNoise <= -0.3 and humidityNoise > 0.3 then
                        terrain[x][y][z] = nodeType.ice
                    elseif temperatrueNoise <= -0.3 then
                        terrain[x][y][z] = nodeType.snow
                    else
                        terrain[x][y][z] = nodeType.stone
                    end
                else
                    terrain[x][y][z] = nodeType.air
                end
            end
        end
    end
    print(string.format("temperatrueNoise min: %.6f, max: %.6f", tempMin, tempMax))
    return terrain
end

function tknVox.generateTerrainMeshData(length, height)
    local terrain = buildTerrain(length, height)

    -- Mesh format: position (3x float per vertex), color (uint32), normal (uint32)
    local terrainMeshData = {
        position = {},
        color = {},
        normal = {},
    }

    -- 26 directions: 6 faces + 12 edges + 8 corners
    local directions26 = { -- 6 faces (bits 0-5)
    {-1, 0, 0}, {1, 0, 0}, {0, -1, 0}, {0, 1, 0}, {0, 0, -1}, {0, 0, 1}, -- 12 edges (bits 6-17)
    {-1, -1, 0}, {-1, 1, 0}, {1, -1, 0}, {1, 1, 0}, {-1, 0, -1}, {-1, 0, 1}, {1, 0, -1}, {1, 0, 1}, {0, -1, -1}, {0, -1, 1}, {0, 1, -1}, {0, 1, 1}, -- 8 corners (bits 18-25)
    {-1, -1, -1}, {-1, -1, 1}, {-1, 1, -1}, {-1, 1, 1}, {1, -1, -1}, {1, -1, 1}, {1, 1, -1}, {1, 1, 1}}

    for x = 0, length do
        for y = 0, length do
            for z = 0, height do
                local node = terrain[x][y][z]
                if node and node ~= nodeType.air then
                    local color = nodeTypeToColor[node]
                    local normalMask = 0x3FFFFFF -- 26 bits

                    for bit, dir in ipairs(directions26) do
                        local nx, ny, nz = x + dir[1], y + dir[2], z + dir[3]
                        if terrain[nx] and terrain[nx][ny] and terrain[nx][ny][nz] and terrain[nx][ny][nz] ~= nodeType.air then
                            normalMask = normalMask & ~(1 << (bit - 1))
                        end
                    end

                    if normalMask ~= 0 then
                        table.insert(terrainMeshData.position, x)
                        table.insert(terrainMeshData.position, y)
                        table.insert(terrainMeshData.position, z)
                        table.insert(terrainMeshData.color, color)
                        table.insert(terrainMeshData.normal, normalMask)
                    end
                end
            end
        end
    end

    return terrainMeshData
end

local function writeValue(file, propertyType, value)
    if propertyType == tknVoxelType.int8 then
        file:write(string.pack("<i1", value))
    elseif propertyType == tknVoxelType.uint8 then
        file:write(string.pack("<I1", value))
    elseif propertyType == tknVoxelType.int16 then
        file:write(string.pack("<i2", value))
    elseif propertyType == tknVoxelType.uint16 then
        file:write(string.pack("<I2", value))
    elseif propertyType == tknVoxelType.int32 then
        file:write(string.pack("<i4", value))
    elseif propertyType == tknVoxelType.uint32 then
        file:write(string.pack("<I4", value))
    elseif propertyType == tknVoxelType.float32 then
        file:write(string.pack("<f", value))
    else
        error("Unsupported Tickernel voxel property type: " .. tostring(propertyType))
    end
end

function tknVox.writeTerrainAsTknVox(filePath, terrainMeshData)
    local vertexCount = #terrainMeshData.color
    if vertexCount == 0 then
        return false, "No terrain vertices to write"
    end

    local propertyCount = 5
    local names = {"px", "py", "pz", "color", "normal"}
    local types = {tknVoxelType.int16, tknVoxelType.int16, tknVoxelType.int16, tknVoxelType.uint32, tknVoxelType.uint32}

    local propertyColumns = {}
    for i = 1, propertyCount do
        propertyColumns[i] = {}
    end

    -- Extract position data from flattened array (3 floats per vertex)
    for i = 1, vertexCount do
        local posBase = (i - 1) * 3
        local x = math.floor(terrainMeshData.position[posBase + 1])
        local y = math.floor(terrainMeshData.position[posBase + 2])
        local z = math.floor(terrainMeshData.position[posBase + 3])

        propertyColumns[1][i] = x
        propertyColumns[2][i] = y
        propertyColumns[3][i] = z
        -- Ensure color is packed with low byte = R, next = G, B, A (matches shader unpackUnorm4x8)
        local col = terrainMeshData.color[i] or 0
        propertyColumns[4][i] = swizzle_color_to_packed(col)
        propertyColumns[5][i] = terrainMeshData.normal[i]
    end

    local file, openErr = io.open(filePath, "wb")
    if not file then
        return false, "Failed to open output file: " .. tostring(openErr)
    end

    file:write(string.pack("<I4", propertyCount))

    for i = 1, propertyCount do
        local name = names[i]
        local length = #name + 1
        file:write(string.pack("<I4", length))
        file:write(name)
        file:write("\0")
    end

    for i = 1, propertyCount do
        file:write(string.pack("<I4", types[i]))
    end

    file:write(string.pack("<I4", vertexCount))

    for i = 1, propertyCount do
        for j = 1, vertexCount do
            writeValue(file, types[i], propertyColumns[i][j])
        end
    end

    file:close()
    return true, nil
end

return tknVox
