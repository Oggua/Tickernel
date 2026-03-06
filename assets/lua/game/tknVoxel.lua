local tknVoxel = {}

local tknVoxelType = {
    int8 = 0,
    uint8 = 1,
    int16 = 2,
    uint16 = 3,
    int32 = 4,
    uint32 = 5,
    float32 = 6,
}

local tknVoxelTypeToLuaUnpack = {
    [0] = "<i1", -- TKN_VOXEL_INT8
    [1] = "<I1", -- TKN_VOXEL_UINT8
    [2] = "<i2", -- TKN_VOXEL_INT16
    [3] = "<I2", -- TKN_VOXEL_UINT16
    [4] = "<i4", -- TKN_VOXEL_INT32
    [5] = "<I4", -- TKN_VOXEL_UINT32
    [6] = "<f", -- TKN_VOXEL_FLOAT32
}

local function swizzleColorToPacked(hex)
    -- Convert human 0xRRGGBBAA to stored uint where little-endian bytes are R,G,B,A
    local r = (hex >> 24) & 0xFF
    local g = (hex >> 16) & 0xFF
    local b = (hex >> 8) & 0xFF
    local a = hex & 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r
end

local function getPropertyValue(pTickernelVoxel, propertyIndex, vertexIndex, defaultValue)
    local propertyColumn = pTickernelVoxel.indexToProperties[propertyIndex]
    if not propertyColumn then
        return defaultValue
    end

    local value = propertyColumn[vertexIndex]
    if value == nil then
        return defaultValue
    end

    return value
end

local function deserializeTickernelVoxel(path)
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

function tknVoxel.loadVoxFile(filePath)
    local pTickernelVoxel, deserializeError = deserializeTickernelVoxel(filePath)
    if not pTickernelVoxel then
        print("tknVoxel.loadVoxFile: " .. deserializeError)
        return nil
    end

    local vertices = {
        position = {},
        color = {},
        normal = {},
        pbr = {},
    }

    -- Format: px (int16), py (int16), pz (int16), color (uint32), normal (uint32), pbr (uint32)
    for i = 1, pTickernelVoxel.vertexCount do
        local px = getPropertyValue(pTickernelVoxel, 1, i, 0)
        local py = getPropertyValue(pTickernelVoxel, 2, i, 0)
        local pz = getPropertyValue(pTickernelVoxel, 3, i, 0)
        local color = getPropertyValue(pTickernelVoxel, 4, i, 0)
        local normal = getPropertyValue(pTickernelVoxel, 5, i, 0)
        local pbr = getPropertyValue(pTickernelVoxel, 6, i, 0)
        local positionBase = (i - 1) * 3
        vertices.position[positionBase + 1] = px
        vertices.position[positionBase + 2] = py
        vertices.position[positionBase + 3] = pz
        vertices.color[i] = color
        vertices.normal[i] = normal
        vertices.pbr[i] = pbr
    end
    return vertices
end

function tknVoxel.writeMeshAsTknVox(filePath, meshData)
    local position = meshData.position or {}
    local color = meshData.color or {}
    local normal = meshData.normal or {}
    local pbr = meshData.pbr or {}

    local vertexCount = #color
    if vertexCount == 0 then
        return false, "No mesh vertices to write"
    end

    local propertyCount = 6
    local names = {"px", "py", "pz", "color", "normal", "pbr"}
    local types = {tknVoxelType.int16, tknVoxelType.int16, tknVoxelType.int16, tknVoxelType.uint32, tknVoxelType.uint32, tknVoxelType.uint32}

    local propertyColumns = {}
    for i = 1, propertyCount do
        propertyColumns[i] = {}
    end

    -- Extract position data from flattened array (3 floats per vertex)
    for i = 1, vertexCount do
        local posBase = (i - 1) * 3
        local x = math.floor(position[posBase + 1] or 0)
        local y = math.floor(position[posBase + 2] or 0)
        local z = math.floor(position[posBase + 3] or 0)

        propertyColumns[1][i] = x
        propertyColumns[2][i] = y
        propertyColumns[3][i] = z
        -- Ensure color is packed with low byte = R, next = G, B, A (matches shader unpackUnorm4x8)
        local col = color[i] or 0
        propertyColumns[4][i] = swizzleColorToPacked(col)
        propertyColumns[5][i] = normal[i] or 0
        propertyColumns[6][i] = pbr[i] or 0
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

return tknVoxel
