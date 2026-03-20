package.path = package.path .. ";./assets/lua/?.lua;./assets/lua/?/init.lua;./assets/lua/game/?.lua"

local tknVoxel = require("game.tknVoxel")

local function ensureDir(path)
    os.execute("mkdir -p '" .. path .. "'")
end

local function parentDir(path)
    return path:match("(.*/)") or "."
end

local function convertAll(srcRoot, dstRoot)
    ensureDir(dstRoot)
    local cmd = "find '" .. srcRoot .. "' -type f -name '*.vox'"
    local p = io.popen(cmd)
    if not p then
        error("无法列出目录: " .. srcRoot)
    end

    for voxPath in p:lines() do
        local subPath = voxPath:sub(#srcRoot + 2) -- 去掉 srcRoot + '/'
        local dstSubPath = dstRoot .. "/" .. subPath:gsub("%.vox$", ".tvox")
        local dstSubDir = parentDir(dstSubPath)
        ensureDir(dstSubDir)

        local outPath, count = tknVoxel.writeTvox(voxPath, dstSubDir)
        if not outPath then
            io.stderr:write("转换失败: " .. voxPath .. "\n")
        else
            print(string.format("已生成并移动[%d]: %s -> %s", count, voxPath, outPath))
        end
    end

    p:close()
end

local src = "res/vox"
local dst = "assets/models"
convertAll(src, dst)
print("完成: 所有 .vox 已转换为 .tvox 并移动到 " .. dst)
