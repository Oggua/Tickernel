local mapEditorScene = {}
local ui = require("ui.ui")
local mapSystem = require("game.mapSystem")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknInputFieldWidget = require("engine.widgets.tknInputFieldWidget")
local tknScrollViewWidget = require("engine.widgets.tknScrollViewWidget")
local tknWindowWidget = require("engine.widgets.tknWindowWidget")
local tkn = require("tkn")

-- Visual width/height of each grid-cell button (pixels)
local gridBtnSize = 48
-- Width of each ground-type toggle (standard largeInteractableWidth square)
local toggleBtnW = 128
-- Width of the Save button on the name row
local saveBtnW = 200

-- ─────────────────────────────────────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Returns the ground name string for a given ground id
local function groundIdToName(id)
    for name, gid in pairs(mapSystem.ground) do
        if gid == id then
            return name
        end
    end
    return "?"
end

-- Given the (possibly bundled) assetsPath, return the writable source maps dir.
-- Bundle path:  .../Tickernel/build/Debug/osx.app/Contents/Resources/assets
-- Source path:  .../Tickernel/assets/lua/game/maps
local function getMapsDir(assetsPath)
    local projectRoot = assetsPath:match("^(.-)/build/")
    if projectRoot then
        return projectRoot .. "/assets/lua/game/maps"
    end
    -- Already pointing at the source directory (or unknown layout)
    return assetsPath .. "/lua/game/maps"
end

-- Serialises the current map to assets/lua/game/maps/<name>.lua
local function saveMap(assetsPath, mapName, length, width, groundMap)
    if not mapName or mapName == "" then
        print("[MapEditor] No map name – nothing saved.")
        return
    end
    -- Sanitise: keep only word chars and hyphens
    local safeName = mapName:gsub("[^%w%-_]", "_")
    local dir = getMapsDir(assetsPath)
    -- Ensure the directory exists (macOS / Linux)
    os.execute("mkdir -p \"" .. dir .. "\"")
    local path = dir .. "/" .. safeName .. ".lua"
    local f = io.open(path, "w")
    if not f then
        print("[MapEditor] Cannot write: " .. path)
        return
    end
    f:write("-- Auto-generated map file. Do not edit manually.\n")
    f:write("local map = {}\n")
    f:write("map.name   = \"" .. safeName .. "\"\n")
    f:write("map.length = " .. length .. "\n")
    f:write("map.width  = " .. width .. "\n")
    f:write("map.groundMap = {\n")
    for x = 1, length do
        f:write("    [" .. x .. "] = {\n")
        for y = 1, width do
            f:write("        [" .. y .. "] = " .. groundMap[x][y] .. ",\n")
        end
        f:write("    },\n")
    end
    f:write("}\n")
    f:write("return map\n")
    f:close()
    print("[MapEditor] Saved: " .. path)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Grid management
-- ─────────────────────────────────────────────────────────────────────────────

local function clearGrid(pGfx)
    if mapEditorScene.gridBtns then
        for _, btn in ipairs(mapEditorScene.gridBtns) do
            tknButtonWidget.remove(pGfx, btn)
        end
        mapEditorScene.gridBtns = nil
        mapEditorScene.gridBtnLabels = nil
    end
    if mapEditorScene.gridScrollView then
        tknScrollViewWidget.remove(pGfx, mapEditorScene.gridScrollView)
        mapEditorScene.gridScrollView = nil
    end
end

local function buildGrid(pGfx, length, width)
    clearGrid(pGfx)

    local sp = tknWidgetConfig.defaultSpacing
    local btnH = tknWidgetConfig.largeInteractableWidth
    local btnW = gridBtnSize
    local sliderW = tknWidgetConfig.smallInteractableWidth

    local totalW = length * (btnW + sp) + sp + sliderW
    local totalH = width * (btnH + sp) + sp + sliderW

    mapEditorScene.gridScrollView = tknScrollViewWidget.add(pGfx, "editorGridScrollView", mapEditorScene.gridAreaNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = totalW,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = totalH,
        offset = 0,
    })

    mapEditorScene.gridBtns = {}
    mapEditorScene.gridBtnLabels = {}

    for gy = 1, width do
        for gx = 1, length do
            local idx = (gy - 1) * length + gx
            local groundId = mapEditorScene.editGroundMap[gx][gy]
            local groundName = groundIdToName(groundId)
            local cx, cy, ci = gx, gy, idx

            local btn = tknButtonWidget.add(pGfx, "gridBtn_" .. idx, mapEditorScene.gridScrollView.contentNode, idx, {
                type = ui.layoutType.anchored,
                anchor = 0,
                pivot = 0,
                length = btnW,
                offset = sp + (gx - 1) * (btnW + sp),
            }, {
                type = ui.layoutType.anchored,
                anchor = 0,
                pivot = 0,
                length = btnH,
                offset = sp + (gy - 1) * (btnH + sp),
            }, function()
                local selId = mapEditorScene.selectedGround
                local selName = groundIdToName(selId)
                mapEditorScene.editGroundMap[cx][cy] = selId
                if mapEditorScene.gridBtnLabels and mapEditorScene.gridBtnLabels[ci] then
                    ui.setTextContent(mapEditorScene.gridBtnLabels[ci], selName)
                end
            end)

            local label = tknTextNode.add(pGfx, "gridBtnLbl_" .. idx, btn.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, groundName, tknWidgetConfig.smallFontSize, 0xFFFFFFFF, 0.5, 0.5)

            mapEditorScene.gridBtns[idx] = btn
            mapEditorScene.gridBtnLabels[idx] = label
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Scene lifecycle
-- ─────────────────────────────────────────────────────────────────────────────

function mapEditorScene.start(pTknGfxContext, game)
    mapSystem.setup()

    -- ── Editor state ────────────────────────────────────────────────────────
    mapEditorScene.editorLength = 8
    mapEditorScene.editorWidth = 8
    mapEditorScene.selectedGround = mapSystem.ground.grass

    local defaultGround = mapSystem.ground.grass
    mapEditorScene.editGroundMap = {}
    for x = 1, 64 do
        mapEditorScene.editGroundMap[x] = {}
        for y = 1, 64 do
            mapEditorScene.editGroundMap[x][y] = defaultGround
        end
    end

    mapEditorScene.pGroundTknMesh = nil
    mapEditorScene.pGroundTknInstance = nil
    mapEditorScene.pGroundTknDrawCall = nil
    mapEditorScene.pendingGridRebuild = false
    mapEditorScene.pendingLength = 8
    mapEditorScene.pendingWidth = 8
    mapEditorScene.pendingMeshRebuild = false

    -- ── Layout constants ────────────────────────────────────────────────────
    local sp = tknWidgetConfig.defaultSpacing -- 8
    local btnH = tknWidgetConfig.largeInteractableWidth -- 48
    local inputH = btnH

    -- Control strip (3 rows) at the top
    --   sp+row+sp+row+sp+row+sp = 8+48+8+48+8+48+8 = 176
    local controlH = sp + inputH + sp + inputH + sp + btnH + sp -- 176

    -- Toggle row right below controls
    local toggleRowH = btnH -- 48

    -- Bottom strip: 3 rows (Generate Mesh | Name+Save | Back)
    --   sp+row+sp+row+sp+row+sp = 176
    local bottomH = sp + btnH + sp + btnH + sp + btnH + sp -- 176

    -- Grid fills what's left in the middle
    local topH = controlH + toggleRowH + sp -- 232

    -- ── Main window ─────────────────────────────────────────────────────────
    mapEditorScene.window = tknWindowWidget.add(pTknGfxContext, "mapEditorWindow", game.rootUINode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1024,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1024,
        offset = 0,
    }, "Map Editor")
    local contentNode = mapEditorScene.window.contentNode

    -- ── 1. Length input ──────────────────────────────────────────────────────
    mapEditorScene.lengthInput = tknInputFieldWidget.add(pTknGfxContext, "lengthInput", contentNode, 1, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = sp,
        maxOffset = -sp,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = inputH,
        offset = sp,
    }, "Length")
    tknInputFieldWidget.setText(mapEditorScene.lengthInput, "8")

    -- ── 2. Width input ───────────────────────────────────────────────────────
    mapEditorScene.widthInput = tknInputFieldWidget.add(pTknGfxContext, "widthInput", contentNode, 2, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = sp,
        maxOffset = -sp,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = inputH,
        offset = sp + inputH + sp,
    }, "Width")
    tknInputFieldWidget.setText(mapEditorScene.widthInput, "8")

    -- ── 3. Generate Grid button ──────────────────────────────────────────────
    mapEditorScene.generateGridBtn = tknButtonWidget.add(pTknGfxContext, "generateGridBtn", contentNode, 3, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = sp,
        maxOffset = -sp,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = btnH,
        offset = sp + inputH + sp + inputH + sp,
    }, function()
        local L = math.max(1, math.min(64, math.floor(tonumber(mapEditorScene.lengthInput.text) or 8)))
        local W = math.max(1, math.min(64, math.floor(tonumber(mapEditorScene.widthInput.text) or 8)))
        mapEditorScene.editGroundMap = {}
        for x = 1, L do
            mapEditorScene.editGroundMap[x] = {}
            for y = 1, W do
                mapEditorScene.editGroundMap[x][y] = mapSystem.ground.grass
            end
        end
        mapEditorScene.pendingLength = L
        mapEditorScene.pendingWidth = W
        mapEditorScene.pendingGridRebuild = true
    end)
    tknTextNode.add(pTknGfxContext, "generateGridLabel", mapEditorScene.generateGridBtn.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Generate", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)

    -- ── 4. Ground-type toggle row ────────────────────────────────────────────
    local entries = {}
    for name, id in pairs(mapSystem.ground) do
        table.insert(entries, {
            name = name,
            id = id,
        })
    end
    table.sort(entries, function(a, b)
        return a.id < b.id
    end)

    mapEditorScene.groundToggleRow = ui.addNode(pTknGfxContext, contentNode, 4, "groundToggleRow", tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = toggleRowH,
        offset = controlH,
    }, tknWidgetConfig.defaultTransform)
    tknImageNode.addNode(pTknGfxContext, "toggleRowBg", mapEditorScene.groundToggleRow, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, tknWidgetConfig.color.semiDarker, false, false)

    mapEditorScene.groundToggles = {}
    mapEditorScene.groundToggleLabels = {}

    for i, entry in ipairs(entries) do
        local name = entry.name
        local id = entry.id
        local ci = i

        local toggle = tknToggleWidget.add(pTknGfxContext, "groundToggle_" .. name, mapEditorScene.groundToggleRow, i + 1, {
            type = ui.layoutType.anchored,
            anchor = 0,
            pivot = 0,
            length = toggleBtnW,
            offset = sp + (i - 1) * (toggleBtnW + sp),
        }, {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = tknWidgetConfig.largeInteractableWidth,
            offset = 0,
        }, 1, function(tog, isOn)
            if isOn then
                mapEditorScene.selectedGround = id
                local selLbls = mapEditorScene.groundToggleLabels[ci]
                if selLbls then
                    ui.setNodeTransformActive(selLbls.dark, true)
                    ui.setNodeTransformActive(selLbls.white, false)
                end
                for j, other in ipairs(mapEditorScene.groundToggles) do
                    if other ~= tog and other.isOn then
                        other.isOn = false
                        ui.setNodeTransformActive(other.handleNode, false)
                        local otherLbls = mapEditorScene.groundToggleLabels[j]
                        if otherLbls then
                            ui.setNodeTransformActive(otherLbls.dark, false)
                            ui.setNodeTransformActive(otherLbls.white, true)
                        end
                    end
                end
            else
                tog.isOn = true
                ui.setNodeTransformActive(tog.handleNode, true)
            end
        end)

        local isInitiallySelected = (id == mapSystem.ground.grass)
        local whiteLbl = tknTextNode.add(pTknGfxContext, "toggleLblWhite_" .. name, toggle.backgroundNode, 2, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, name, tknWidgetConfig.smallFontSize, 0xFFFFFFFF, 0.5, 0.5)
        local darkLbl = tknTextNode.add(pTknGfxContext, "toggleLblDark_" .. name, toggle.backgroundNode, 3, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, name, tknWidgetConfig.smallFontSize, tknWidgetConfig.color.darker, 0.5, 0.5)
        ui.setNodeTransformActive(whiteLbl, not isInitiallySelected)
        ui.setNodeTransformActive(darkLbl, isInitiallySelected)
        mapEditorScene.groundToggleLabels[ci] = {
            white = whiteLbl,
            dark = darkLbl,
        }

        if isInitiallySelected then
            toggle.isOn = true
            ui.setNodeTransformActive(toggle.handleNode, true)
        end
        table.insert(mapEditorScene.groundToggles, toggle)
    end

    -- ── 5. Grid area (middle) ────────────────────────────────────────────────
    mapEditorScene.gridAreaNode = ui.addNode(pTknGfxContext, contentNode, 5, "gridAreaNode", tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = topH,
        maxOffset = -bottomH,
        offset = 0,
    }, tknWidgetConfig.defaultTransform)

    -- ── 6. Generate Mesh button (3rd row from bottom) ────────────────────────
    -- vertical: anchor=1 (bottom), pivot=1, offset = -(sp + btnH + sp + btnH + sp) = -120
    local genMeshOffsetY = -(sp + btnH + sp + btnH + sp)
    mapEditorScene.generateMeshBtn = tknButtonWidget.add(pTknGfxContext, "generateMeshBtn", contentNode, 6, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = sp,
        maxOffset = -sp,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = btnH,
        offset = genMeshOffsetY,
    }, function()
        mapEditorScene.pendingMeshRebuild = true
    end)
    tknTextNode.add(pTknGfxContext, "generateMeshLabel", mapEditorScene.generateMeshBtn.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Generate Mesh", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)

    -- ── 7. Map name input (2nd row from bottom, left side) ───────────────────
    -- vertical: anchor=1, pivot=1, offset = -(sp + btnH + sp) = -64
    local nameRowOffsetY = -(sp + btnH + sp)
    mapEditorScene.mapNameInput = tknInputFieldWidget.add(pTknGfxContext, "mapNameInput", contentNode, 7, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = sp,
        maxOffset = -(saveBtnW + 2 * sp),
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = btnH,
        offset = nameRowOffsetY,
    }, "Map Name")

    -- ── 8. Save button (2nd row from bottom, right side) ────────────────────
    mapEditorScene.saveBtn = tknButtonWidget.add(pTknGfxContext, "saveBtn", contentNode, 8, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = saveBtnW,
        offset = -sp,
    }, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = btnH,
        offset = nameRowOffsetY,
    }, function()
        saveMap(game.assetsPath, mapEditorScene.mapNameInput.text, mapEditorScene.editorLength, mapEditorScene.editorWidth, mapEditorScene.editGroundMap)
    end)
    tknTextNode.add(pTknGfxContext, "saveBtnLabel", mapEditorScene.saveBtn.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Save", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)

    -- ── 9. Back button (bottom row) ──────────────────────────────────────────
    mapEditorScene.backBtn = tknButtonWidget.add(pTknGfxContext, "backBtn", contentNode, 9, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = sp,
        maxOffset = -sp,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = btnH,
        offset = -sp,
    }, function()
        game.switchScene(require("game.mainScene"))
    end)
    tknTextNode.add(pTknGfxContext, "backBtnLabel", mapEditorScene.backBtn.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Back", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)
end

function mapEditorScene.stop(game)
    game.sharedGroundMap = mapEditorScene.editGroundMap
    game.sharedSeed = 321312
    game.sharedLength = mapEditorScene.editorLength
    game.sharedWidth = mapEditorScene.editorWidth
    mapSystem.teardown()
    mapEditorScene.editGroundMap = nil
end

function mapEditorScene.stopGfx(game, pTknGfxContext)
    clearGrid(pTknGfxContext)

    -- Bottom buttons (reverse order: children before parents)
    tknButtonWidget.remove(pTknGfxContext, mapEditorScene.backBtn)
    mapEditorScene.backBtn = nil

    tknButtonWidget.remove(pTknGfxContext, mapEditorScene.saveBtn)
    mapEditorScene.saveBtn = nil

    tknInputFieldWidget.remove(pTknGfxContext, mapEditorScene.mapNameInput)
    mapEditorScene.mapNameInput = nil

    tknButtonWidget.remove(pTknGfxContext, mapEditorScene.generateMeshBtn)
    mapEditorScene.generateMeshBtn = nil

    ui.removeNode(pTknGfxContext, mapEditorScene.gridAreaNode)
    mapEditorScene.gridAreaNode = nil

    -- Toggle row
    if mapEditorScene.groundToggles then
        for _, toggle in ipairs(mapEditorScene.groundToggles) do
            tknToggleWidget.remove(pTknGfxContext, toggle)
        end
        mapEditorScene.groundToggles = nil
        mapEditorScene.groundToggleLabels = nil
    end
    ui.removeNode(pTknGfxContext, mapEditorScene.groundToggleRow)
    mapEditorScene.groundToggleRow = nil

    -- Control strip
    tknButtonWidget.remove(pTknGfxContext, mapEditorScene.generateGridBtn)
    mapEditorScene.generateGridBtn = nil

    tknInputFieldWidget.remove(pTknGfxContext, mapEditorScene.widthInput)
    mapEditorScene.widthInput = nil

    tknInputFieldWidget.remove(pTknGfxContext, mapEditorScene.lengthInput)
    mapEditorScene.lengthInput = nil

    tknWindowWidget.remove(pTknGfxContext, mapEditorScene.window)
    mapEditorScene.window = nil

    -- Mesh
    if mapEditorScene.pGroundTknDrawCall then
        mapSystem.destroyMesh(pTknGfxContext, mapEditorScene.pGroundTknMesh, mapEditorScene.pGroundTknInstance, mapEditorScene.pGroundTknDrawCall)
    end
    mapEditorScene.pGroundTknMesh = nil
    mapEditorScene.pGroundTknInstance = nil
    mapEditorScene.pGroundTknDrawCall = nil
end

function mapEditorScene.update(game)
end

function mapEditorScene.updateGfx(game, pTknGfxContext, width, height)
    -- Rebuild grid (deferred from Generate button)
    if mapEditorScene.pendingGridRebuild then
        local L = mapEditorScene.pendingLength
        local W = mapEditorScene.pendingWidth
        mapEditorScene.editorLength = L
        mapEditorScene.editorWidth = W
        mapEditorScene.pendingGridRebuild = false
        buildGrid(pTknGfxContext, L, W)
    end

    -- Rebuild voxel mesh (deferred from Generate Mesh button)
    if mapEditorScene.pendingMeshRebuild then
        mapEditorScene.pendingMeshRebuild = false

        if mapEditorScene.pGroundTknDrawCall then
            mapSystem.destroyMesh(pTknGfxContext, mapEditorScene.pGroundTknMesh, mapEditorScene.pGroundTknInstance, mapEditorScene.pGroundTknDrawCall)
            mapEditorScene.pGroundTknMesh = nil
            mapEditorScene.pGroundTknInstance = nil
            mapEditorScene.pGroundTknDrawCall = nil
        end

        mapSystem.generateRoom(321312, mapEditorScene.editorLength, mapEditorScene.editorWidth, game.voxelPerMeter, mapEditorScene.editGroundMap)
        mapEditorScene.pGroundTknMesh, mapEditorScene.pGroundTknInstance, mapEditorScene.pGroundTknDrawCall = mapSystem.createMesh(pTknGfxContext)
    end
end

function mapEditorScene.recordFrame(game, pTknGfxContext, pTknFrame)
    if mapEditorScene.pGroundTknDrawCall then
        tkn.tknRecordDrawCallPtr(pTknGfxContext, pTknFrame, mapEditorScene.pGroundTknDrawCall)
    end
end

return mapEditorScene
