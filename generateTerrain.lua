#!/usr/bin/env lua

-- Add assets/lua to package path
package.path = package.path .. ";./assets/lua/?.lua"

local tknVox = require("tknVox")

-- Generate terrain with radius 128
print("Generating terrain mesh data...")
local terrainMeshData = tknVox.generateTerrainMeshData(1024, 128)
print("Generated " .. (#terrainMeshData.color) .. " vertices")

-- Save to file
local outputPath = "./assets/models/terrain.tknvox"
print("Writing to " .. outputPath .. "...")
local success, err = tknVox.writeTerrainAsTknVox(outputPath, terrainMeshData)

if success then
    print("Successfully created " .. outputPath)
else
    print("Failed to create terrain: " .. tostring(err))
end
