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
local GRID_BTN_SIZE = 48
-- Width of each ground-type toggle (standard largeInteractableWidth square)
local TOGGLE_BTN_W = 128

-- Returns the ground name string for a given ground id
local function groundIdToName(id)
    for name, gid in pairs(mapSystem.ground) do
        if gid == id then
            return name
        end
    end
    return "?"
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
    local btnW = GRID_BTN_SIZE
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
            local cx, cy, ci = gx, gy, idx -- closure captures

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
                -- Paint: update the ground map and the button label directly.
                -- No nodes are created/destroyed here, so this is safe inside ui.update.
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

function mapEditorScene.start(game, pTknGfxContext)
    mapSystem.setup()

    -- ── Editor state ────────────────────────────────────────────────────────
    mapEditorScene.editorLength = 8
    mapEditorScene.editorWidth = 8
    mapEditorScene.selectedGround = mapSystem.ground.grass -- default paint brush

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

    -- Three stacked rows (length-input, width-input, generate-button) + trailing sp
    --   sp + row + sp + row + sp + row + sp  =  8+48+8+48+8+48+8 = 176
    local controlH = sp + inputH + sp + inputH + sp + btnH + sp -- 176

    -- Toggle row sits right below: same height as a button row
    local toggleRowH = btnH -- 48

    -- Grid starts after controls + toggle row + one more spacing gap
    local topH = controlH + toggleRowH + sp -- 232
    local bottomH = sp + btnH + sp -- 64

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

    -- ── Length input ─────────────────────────────────────────────────────────
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

    -- ── Width input ──────────────────────────────────────────────────────────
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

    -- ── Generate Grid button ─────────────────────────────────────────────────
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
        local gnd = mapSystem.ground.grass
        mapEditorScene.editGroundMap = {}
        for x = 1, L do
            mapEditorScene.editGroundMap[x] = {}
            for y = 1, W do
                mapEditorScene.editGroundMap[x][y] = gnd
            end
        end
        mapEditorScene.pendingLength = L
        mapEditorScene.pendingWidth = W
        mapEditorScene.pendingGridRebuild = true
    end)
    tknTextNode.add(pTknGfxContext, "generateGridLabel", mapEditorScene.generateGridBtn.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Generate", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)

    -- ── Ground-type toggle row (radio-button style) ──────────────────────────
    -- Collect & sort ground entries
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

    -- Subtle background so the row is visually distinct
    tknImageNode.addNode(pTknGfxContext, "toggleRowBg", mapEditorScene.groundToggleRow, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, tknWidgetConfig.color.semiDarker, false, false)

    mapEditorScene.groundToggles = {}
    mapEditorScene.groundToggleLabels = {}

    for i, entry in ipairs(entries) do
        local name = entry.name
        local id = entry.id
        local ci = i -- capture loop index for closures

        local toggle = tknToggleWidget.add(pTknGfxContext, "groundToggle_" .. name, mapEditorScene.groundToggleRow, i + 1, {
            type = ui.layoutType.anchored,
            anchor = 0,
            pivot = 0,
            length = TOGGLE_BTN_W,
            offset = sp + (i - 1) * (TOGGLE_BTN_W + sp),
        }, {
            type = ui.layoutType.anchored,
            anchor = 0.5,
            pivot = 0.5,
            length = tknWidgetConfig.largeInteractableWidth,
            offset = 0,
        }, 1, function(tog, isOn)
            if isOn then
                -- Radio: select this ground and deselect all others
                mapEditorScene.selectedGround = id
                -- Show dark label (ON), hide white label for this toggle
                local selLbls = mapEditorScene.groundToggleLabels[ci]
                if selLbls then
                    ui.setNodeTransformActive(selLbls.dark, true)
                    ui.setNodeTransformActive(selLbls.white, false)
                end
                for j, other in ipairs(mapEditorScene.groundToggles) do
                    if other ~= tog and other.isOn then
                        other.isOn = false
                        ui.setNodeTransformActive(other.handleNode, false)
                        -- Restore white label (OFF) for deselected toggles
                        local otherLbls = mapEditorScene.groundToggleLabels[j]
                        if otherLbls then
                            ui.setNodeTransformActive(otherLbls.dark, false)
                            ui.setNodeTransformActive(otherLbls.white, true)
                        end
                    end
                end
            else
                -- Prevent deselection: at least one must remain selected
                tog.isOn = true
                ui.setNodeTransformActive(tog.handleNode, true)
            end
        end)

        -- Two stacked labels – white shown when OFF, dark shown when ON.
        -- Using setNodeTransformActive avoids relying on setNodeTransformColor
        -- which does not reliably affect text-node render colour.
        local isInitiallySelected = (id == mapSystem.ground.grass)
        local whiteLbl = tknTextNode.add(pTknGfxContext, "toggleLblWhite_" .. name,
            toggle.backgroundNode, 2,
            tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation,
            tknWidgetConfig.defaultTransform, name, tknWidgetConfig.smallFontSize, 0xFFFFFFFF, 0.5, 0.5)
        local darkLbl = tknTextNode.add(pTknGfxContext, "toggleLblDark_" .. name,
            toggle.backgroundNode, 3,
            tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation,
            tknWidgetConfig.defaultTransform, name, tknWidgetConfig.smallFontSize, tknWidgetConfig.color.darker, 0.5, 0.5)
        -- Show the right label based on initial state
        ui.setNodeTransformActive(whiteLbl, not isInitiallySelected)
        ui.setNodeTransformActive(darkLbl, isInitiallySelected)
        mapEditorScene.groundToggleLabels[ci] = { white = whiteLbl, dark = darkLbl }

        -- Set initial selection to grass
        if isInitiallySelected then
            toggle.isOn = true
            ui.setNodeTransformActive(toggle.handleNode, true)
        end

        table.insert(mapEditorScene.groundToggles, toggle)
    end

    -- ── Grid area (middle – fills between toggle row and generate-mesh button) ─
    mapEditorScene.gridAreaNode = ui.addNode(pTknGfxContext, contentNode, 5, "gridAreaNode", tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = topH,
        maxOffset = -bottomH,
        offset = 0,
    }, tknWidgetConfig.defaultTransform)

    -- ── Generate Mesh button (bottom) ────────────────────────────────────────
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
        offset = -sp,
    }, function()
        mapEditorScene.pendingMeshRebuild = true
    end)
    tknTextNode.add(pTknGfxContext, "generateMeshLabel", mapEditorScene.generateMeshBtn.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Generate Mesh", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)
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
    -- Remove children before parents to keep the UI system consistent.
    clearGrid(pTknGfxContext)

    tknButtonWidget.remove(pTknGfxContext, mapEditorScene.generateMeshBtn)
    mapEditorScene.generateMeshBtn = nil

    ui.removeNode(pTknGfxContext, mapEditorScene.gridAreaNode)
    mapEditorScene.gridAreaNode = nil

    -- Remove toggles before their parent row node
    if mapEditorScene.groundToggles then
        for _, toggle in ipairs(mapEditorScene.groundToggles) do
            tknToggleWidget.remove(pTknGfxContext, toggle)
        end
        mapEditorScene.groundToggles = nil
        mapEditorScene.groundToggleLabels = nil
    end
    ui.removeNode(pTknGfxContext, mapEditorScene.groundToggleRow)
    mapEditorScene.groundToggleRow = nil

    tknButtonWidget.remove(pTknGfxContext, mapEditorScene.generateGridBtn)
    mapEditorScene.generateGridBtn = nil

    tknInputFieldWidget.remove(pTknGfxContext, mapEditorScene.widthInput)
    mapEditorScene.widthInput = nil

    tknInputFieldWidget.remove(pTknGfxContext, mapEditorScene.lengthInput)
    mapEditorScene.lengthInput = nil

    tknWindowWidget.remove(pTknGfxContext, mapEditorScene.window)
    mapEditorScene.window = nil

    if mapEditorScene.pGroundTknDrawCall then
        mapSystem.destroyMesh(pTknGfxContext, mapEditorScene.pGroundTknMesh, mapEditorScene.pGroundTknInstance, mapEditorScene.pGroundTknDrawCall)
    end
    mapEditorScene.pGroundTknMesh = nil
    mapEditorScene.pGroundTknInstance = nil
    mapEditorScene.pGroundTknDrawCall = nil
end

function mapEditorScene.update(game)
    -- No per-frame logic needed in this UI-driven editor.
end

function mapEditorScene.updateGfx(game, pTknGfxContext, width, height)
    -- ── Rebuild grid (deferred from Generate button click) ──────────────────
    if mapEditorScene.pendingGridRebuild then
        local L = mapEditorScene.pendingLength
        local W = mapEditorScene.pendingWidth
        mapEditorScene.editorLength = L
        mapEditorScene.editorWidth = W
        mapEditorScene.pendingGridRebuild = false
        buildGrid(pTknGfxContext, L, W)
    end

    -- ── Rebuild voxel mesh (deferred from Generate Mesh button click) ────────
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
