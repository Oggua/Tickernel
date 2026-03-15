local voxelConfig = require("game.voxelConfig")

local voxParser = {}

local tkn = nil
local deferredRenderPass = nil

local function ensureRenderDeps()
	if not tkn then
		tkn = require("tkn")
	end
	if not deferredRenderPass then
		deferredRenderPass = require("deferredRenderer.deferredRenderPass")
	end
end

local TVOX_MAGIC = "TVOX"
local TVOX_VERSION = 1
local TVOX_RECORD_SIZE = 17 -- I2 I2 I2 I4 I4 B B B

local neighbors = {
	{-1, 0, 0},
	{1, 0, 0},
	{0, -1, 0},
	{0, 1, 0},
	{0, 0, -1},
	{0, 0, 1},
	{-1, -1, 0},
	{-1, 1, 0},
	{1, -1, 0},
	{1, 1, 0},
	{-1, 0, -1},
	{-1, 0, 1},
	{1, 0, -1},
	{1, 0, 1},
	{0, -1, -1},
	{0, -1, 1},
	{0, 1, -1},
	{0, 1, 1},
	{-1, -1, -1},
	{-1, -1, 1},
	{-1, 1, -1},
	{-1, 1, 1},
	{1, -1, -1},
	{1, -1, 1},
	{1, 1, -1},
	{1, 1, 1},
}

local materialByColor = {}
for _, material in pairs(voxelConfig) do
	if material.color and material.emissive and material.roughness and material.metallic then
		materialByColor[material.color] = material
	end
end

local function asTvoxPath(voxFilePath)
	local replaced = voxFilePath:gsub("%.vox$", ".tvox")
	if replaced == voxFilePath then
		replaced = voxFilePath .. ".tvox"
	end
	return replaced
end

local function writeTvoxFile(tvoxFilePath, sizeX, sizeY, sizeZ, records)
	local out, err = io.open(tvoxFilePath, "wb")
	if not out then
		error("Cannot open file for writing: " .. tvoxFilePath .. " (" .. tostring(err) .. ")")
	end

	out:write(TVOX_MAGIC)
	out:write(string.pack("<I4I4I4I4I4", TVOX_VERSION, sizeX, sizeY, sizeZ, #records))

	for _, record in ipairs(records) do
		if record.x > 0xFFFF or record.y > 0xFFFF or record.z > 0xFFFF then
			out:close()
			error("Voxel coordinate exceeds TVOX uint16 limit: (" .. record.x .. ", " .. record.y .. ", " .. record.z .. ")")
		end

		out:write(string.pack(
			"<I2I2I2I4I4I1I1I1",
			record.x,
			record.y,
			record.z,
			record.color,
			record.normal,
			record.emissive,
			record.roughness,
			record.metallic
		))
	end
	out:close()
end

local function readAllBytes(path)
	local f, err = io.open(path, "rb")
	if not f then
		error("Cannot open file for reading: " .. path .. " (" .. tostring(err) .. ")")
	end
	local data = f:read("*a")
	f:close()
	return data
end

local function createReader(data)
	local reader = {
		data = data,
		pos = 1,
		len = #data,
	}

	function reader:readBytes(n)
		if self.pos + n - 1 > self.len then
			error("Unexpected EOF while reading bytes")
		end
		local chunk = self.data:sub(self.pos, self.pos + n - 1)
		self.pos = self.pos + n
		return chunk
	end

	function reader:readU8()
		local value
		value, self.pos = string.unpack("<I1", self.data, self.pos)
		return value
	end

	function reader:readU32()
		local value
		value, self.pos = string.unpack("<I4", self.data, self.pos)
		return value
	end

	function reader:skip(n)
		self.pos = self.pos + n
		if self.pos - 1 > self.len then
			error("Unexpected EOF while skipping bytes")
		end
	end

	return reader
end

local function abgrToRgba(abgr)
	local a = (abgr >> 24) & 0xFF
	local b = (abgr >> 16) & 0xFF
	local g = (abgr >> 8) & 0xFF
	local r = abgr & 0xFF
	return (r << 24) | (g << 16) | (b << 8) | a
end

local function findExactMaterialByAbgr(abgr)
	local rgba = abgrToRgba(abgr)
	return materialByColor[rgba], rgba
end

local function rgbaLuminance(rgba)
	local r = (rgba >> 24) & 0xFF
	local g = (rgba >> 16) & 0xFF
	local b = (rgba >> 8) & 0xFF
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function mapToRockByShade(rgba)
	local darkRock = voxelConfig.darkRock
	local rock = voxelConfig.rock
	local lightRock = voxelConfig.lightRock
	if not (darkRock and rock and lightRock) then
		return nil
	end

	local y = rgbaLuminance(rgba)
	local yd = rgbaLuminance(darkRock.color)
	local yr = rgbaLuminance(rock.color)
	local yl = rgbaLuminance(lightRock.color)

	local dDark = math.abs(y - yd)
	local dRock = math.abs(y - yr)
	local dLight = math.abs(y - yl)

	if dDark <= dRock and dDark <= dLight then
		return darkRock
	elseif dLight <= dRock and dLight <= dDark then
		return lightRock
	else
		return rock
	end
end

local function toHex32(v)
	return string.format("0x%08X", v & 0xFFFFFFFF)
end

local function occupancyKey(x, y, z)
	return x .. "," .. y .. "," .. z
end

local function calculateNormalMask(occupancy, x, y, z)
	local mask = 0
	for i, d in ipairs(neighbors) do
		local nx = x + d[1]
		local ny = y + d[2]
		local nz = z + d[3]
		if not occupancy[occupancyKey(nx, ny, nz)] then
			mask = mask | (1 << (i - 1))
		end
	end
	return mask
end

local function parseVoxFile(voxFilePath)
	local data = readAllBytes(voxFilePath)
	local reader = createReader(data)

	local id = reader:readBytes(4)
	if id ~= "VOX " then
		error("Invalid .vox file: missing VOX header")
	end

	local version = reader:readU32()
	if version < 150 then
		error("Unsupported .vox version: " .. tostring(version))
	end

	local mainId = reader:readBytes(4)
	if mainId ~= "MAIN" then
		error("Invalid .vox file: missing MAIN chunk")
	end

	local mainContentSize = reader:readU32()
	local mainChildrenSize = reader:readU32()
	reader:skip(mainContentSize)

	local mainEndPos = reader.pos + mainChildrenSize - 1

	local currentSize = nil
	local firstModel = nil
	local palette = {}
	local hasRgba = false

	while reader.pos <= mainEndPos do
		local chunkId = reader:readBytes(4)
		local chunkContentSize = reader:readU32()
		local chunkChildrenSize = reader:readU32()

		if chunkId == "SIZE" then
			local sx = reader:readU32()
			local sy = reader:readU32()
			local sz = reader:readU32()
			currentSize = {
				x = sx,
				y = sy,
				z = sz,
			}
			local remain = chunkContentSize - 12
			if remain > 0 then
				reader:skip(remain)
			end
		elseif chunkId == "XYZI" then
			local numVoxels = reader:readU32()
			local voxels = {}
			for i = 1, numVoxels do
				local x = reader:readU8()
				local y = reader:readU8()
				local z = reader:readU8()
				local colorIndex = reader:readU8()
				voxels[i] = {
					x = x,
					y = y,
					z = z,
					colorIndex = colorIndex,
				}
			end
			local remain = chunkContentSize - (4 + numVoxels * 4)
			if remain > 0 then
				reader:skip(remain)
			end
			if not firstModel then
				if not currentSize then
					error("Invalid .vox file: XYZI chunk appears before SIZE")
				end
				firstModel = {
					size = currentSize,
					voxels = voxels,
				}
			end
		elseif chunkId == "RGBA" then
			-- Palette mapping follows MagicaVoxel spec: read[0..254] maps to palette[1..255].
			local raw = {}
			for i = 1, 256 do
				raw[i] = reader:readU32()
			end
			hasRgba = true
			palette[1] = 0x00000000
			for i = 0, 254 do
				palette[i + 2] = raw[i + 1]
			end
			local remain = chunkContentSize - 1024
			if remain > 0 then
				reader:skip(remain)
			end
		else
			reader:skip(chunkContentSize)
		end

		if chunkChildrenSize > 0 then
			reader:skip(chunkChildrenSize)
		end
	end

	if not firstModel then
		error("No model data found in .vox file")
	end

	if not hasRgba then
		error("VOX file missing RGBA chunk: no defaultPalette fallback is used")
	end

	return firstModel, palette
end

local function buildPackedVoxelRecords(model, palette)
	local occupancy = {}
	local records = {}
	local shadeMappedColorSet = {}

	for i, voxel in ipairs(model.voxels) do
		local x = voxel.x + 1
		local y = voxel.y + 1
		local z = voxel.z + 1
		records[i] = {
			x = x,
			y = y,
			z = z,
			colorIndex = voxel.colorIndex,
		}
		occupancy[occupancyKey(x, y, z)] = true
	end

	for _, record in ipairs(records) do
		local paletteIdx = record.colorIndex + 1
		local colorAbgr = palette[paletteIdx]
		if not colorAbgr then
			error("Palette index out of range in VOX: " .. tostring(record.colorIndex))
		end
		local material, rgba = findExactMaterialByAbgr(colorAbgr)
		if not material then
			material = mapToRockByShade(rgba)
			if not material then
				error("VOX color not found and rock shade mapping unavailable: " .. toHex32(rgba))
			end
			shadeMappedColorSet[rgba] = material.name
		end
		record.color = colorAbgr
		record.normal = calculateNormalMask(occupancy, record.x, record.y, record.z)
		record.emissive = material and (material.emissive & 0xFF) or 0
		record.roughness = material and (material.roughness & 0xFF) or 0
		record.metallic = material and (material.metallic & 0xFF) or 0
	end

	if next(shadeMappedColorSet) then
		local mappedColors = {}
		for rgba, name in pairs(shadeMappedColorSet) do
			table.insert(mappedColors, toHex32(rgba) .. "->" .. name)
		end
		table.sort(mappedColors)
		local msg = "VOX color(s) mapped by shade to rock materials: " .. table.concat(mappedColors, ", ")
		print(msg)
	end

	return records
end

local function normalizeAndFinalizeRecords(records, options)
	local occupancy = {}
	local finalized = {}
	local autoNormal = not options or options.autoNormal ~= false

	for i, record in ipairs(records) do
		if not record.x or not record.y or not record.z then
			error("Record missing position fields x/y/z at index " .. tostring(i))
		end
		if not record.color then
			error("Record missing color field at index " .. tostring(i))
		end

		local finalizedRecord = {
			x = record.x,
			y = record.y,
			z = record.z,
			color = record.color,
			normal = record.normal or 0,
			emissive = record.emissive or 0,
			roughness = record.roughness or 0,
			metallic = record.metallic or 0,
		}
		finalized[i] = finalizedRecord
		occupancy[occupancyKey(finalizedRecord.x, finalizedRecord.y, finalizedRecord.z)] = true
	end

	if autoNormal then
		for _, record in ipairs(finalized) do
			record.normal = calculateNormalMask(occupancy, record.x, record.y, record.z)
		end
	end

	return finalized
end

function voxParser.writeTvox(voxFilePath)
	local model, palette = parseVoxFile(voxFilePath)
	local records = buildPackedVoxelRecords(model, palette)
	local tvoxFilePath = asTvoxPath(voxFilePath)
	writeTvoxFile(tvoxFilePath, model.size.x, model.size.y, model.size.z, records)

	return tvoxFilePath, #records
end

function voxParser.writeTvoxRecords(tvoxFilePath, sizeX, sizeY, sizeZ, records, options)
	local finalizedRecords = normalizeAndFinalizeRecords(records, options)
	writeTvoxFile(tvoxFilePath, sizeX, sizeY, sizeZ, finalizedRecords)
	return tvoxFilePath, #finalizedRecords
end

local function readTvoxRaw(tvoxFilePath)
	local data = readAllBytes(tvoxFilePath)
	local reader = createReader(data)

	local magic = reader:readBytes(4)
	if magic ~= TVOX_MAGIC then
		error("Invalid .tvox file: missing TVOX header")
	end

	local version = reader:readU32()
	if version ~= TVOX_VERSION then
		error("Unsupported .tvox version: " .. tostring(version))
	end

	local sizeX = reader:readU32()
	local sizeY = reader:readU32()
	local sizeZ = reader:readU32()
	local voxelCount = reader:readU32()

	local expectedBytes = voxelCount * TVOX_RECORD_SIZE
	local remain = reader.len - reader.pos + 1
	if remain < expectedBytes then
		error("Invalid .tvox file: truncated voxel records")
	end

	local records = {}
	for i = 1, voxelCount do
		local x, y, z, color, normal, emissive, roughness, metallic
		x, y, z, color, normal, emissive, roughness, metallic, reader.pos = string.unpack("<I2I2I2I4I4I1I1I1", reader.data, reader.pos)
		records[i] = {
			x = x,
			y = y,
			z = z,
			color = color,
			normal = normal,
			emissive = emissive,
			roughness = roughness,
			metallic = metallic,
		}
	end

	return {
		sizeX = sizeX,
		sizeY = sizeY,
		sizeZ = sizeZ,
		voxelCount = voxelCount,
		records = records,
	}
end

function voxParser.readTvox(tvoxFilePath, pTknGfxContext)
	ensureRenderDeps()
	local tvox = readTvoxRaw(tvoxFilePath)

	local vertices = {
		position = {},
		color = {},
		normal = {},
		pbr = {},
	}

	for _, record in ipairs(tvox.records) do
		table.insert(vertices.position, record.x)
		table.insert(vertices.position, record.y)
		table.insert(vertices.position, record.z)
		table.insert(vertices.color, record.color)
		table.insert(vertices.normal, record.normal)
		local pbr = (record.emissive & 0xF) | ((record.roughness & 0xF) << 4) | ((record.metallic & 0xF) << 8)
		table.insert(vertices.pbr, pbr)
	end

	local pTknMesh = tkn.tknCreateMeshPtrWithData(
		pTknGfxContext,
		deferredRenderPass.pVoxelVertexInputLayout,
		deferredRenderPass.vertexFormat,
		vertices,
		nil,
		nil
	)

	return pTknMesh, tvox
end


function voxParser.destroyMesh(pTknGfxContext, pTknMesh)
	ensureRenderDeps()
	tkn.tknDestroyMeshPtr(pTknGfxContext, pTknMesh)
end

return voxParser
