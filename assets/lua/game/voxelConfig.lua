-- IDs are stable; append new materials at the end, never reorder or reuse IDs.
local voxelConfig = {
    [1] = {
        name = "default",
        color = 0x000000FF,
        emissive = 0,
        roughness = 14,
        metallic = 0,
    },
    [2] = {
        name = "darkDirt",
        color = 0x3C2C1DFF,
        emissive = 0,
        roughness = 14,
        metallic = 0,
    },
    [3] = {
        name = "dirt",
        color = 0x8B5E3EFF,
        emissive = 0,
        roughness = 13,
        metallic = 0,
    },
    [4] = {
        name = "lightDirt",
        color = 0xE19757FF,
        emissive = 0,
        roughness = 12,
        metallic = 0,
    },
    [5] = {
        name = "darkRock",
        color = 0x383533FF,
        emissive = 0,
        roughness = 13,
        metallic = 2,
    },
    [6] = {
        name = "rock",
        color = 0x605752FF,
        emissive = 0,
        roughness = 12,
        metallic = 1,
    },
    [7] = {
        name = "lightRock",
        color = 0x716B60FF,
        emissive = 0,
        roughness = 10,
        metallic = 0,
    },
    [8] = {
        name = "darkGrass",
        color = 0x2E711BFF,
        emissive = 0,
        roughness = 13,
        metallic = 0,
    },
    [9] = {
        name = "grass",
        color = 0x6E9424FF,
        emissive = 0,
        roughness = 12,
        metallic = 0,
    },
    [10] = {
        name = "lightGrass",
        color = 0xB4A539FF,
        emissive = 0,
        roughness = 11,
        metallic = 0,
    },
    [11] = {
        name = "sand",
        color = 0xD4B368FF,
        emissive = 0,
        roughness = 11,
        metallic = 0,
    },
    [12] = {
        name = "lightSand",
        color = 0xE4C388FF,
        emissive = 0,
        roughness = 9,
        metallic = 0,
    },
    [13] = {
        name = "water",
        color = 0x41A5FFFF,
        emissive = 0,
        roughness = 0,
        metallic = 1,
    },
    [14] = {
        name = "lava",
        color = 0xFF0800FF,
        emissive = 15,
        roughness = 8,
        metallic = 0,
    },
    [15] = {
        name = "lightLava",
        color = 0xFF2800FF,
        emissive = 15,
        roughness = 8,
        metallic = 0,
    },
    [16] = {
        name = "ice",
        color = 0xC1FAFFFF,
        emissive = 0,
        roughness = 1,
        metallic = 1,
    },
    [17] = {
        name = "snow",
        color = 0xFFFFFFFF,
        emissive = 0,
        roughness = 14,
        metallic = 0,
    },
    [18] = {
        name = "whiteMushroom",
        color = 0xAC9A85FF,
        emissive = 0,
        roughness = 12,
        metallic = 0,
    },
    [19] = {
        name = "redMushroom",
        color = 0x7B2F27FF,
        emissive = 0,
        roughness = 12,
        metallic = 0,
    },
    [20] = {
        name = "darkWood",
        color = 0x653200FF,
        emissive = 0,
        roughness = 15,
        metallic = 0,
    },
    [21] = {
        name = "wood",
        color = 0xB65400FF,
        emissive = 0,
        roughness = 15,
        metallic = 0,
    },
    [22] = {
        name = "lightWood",
        color = 0xDA7700FF,
        emissive = 0,
        roughness = 15,
        metallic = 0,
    },
}

-- Name-based aliases: voxelConfig.dirt == voxelConfig[4], etc.
for id, mat in ipairs(voxelConfig) do
    mat.id = id
    voxelConfig[mat.name] = mat
end

return voxelConfig
