local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local colorPreset = require("ui.colorPreset")
local editorTopBarPanel = {}

function editorTopBarPanel.create(pTknGfxContext, editorRootNode, editorTopBarNode)
    local editorDragHorizontal = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 256,
        offset = 0,
    }
    local editorDragVertical = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 64,
        offset = 0,
    }
    editorTopBarPanel.editorDragWidget = tknWidgetConfig.addDragWidget(pTknGfxContext, "editorDrag", editorTopBarNode, 1, editorDragHorizontal, editorDragVertical)

    local editorToggleHorizontal = {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 32,
        offset = 8,
    }
    local editorToggleVertical = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 32,
        offset = 0,
    }
    editorTopBarPanel.editorToggleWidget = tknWidgetConfig.addToggleWidget(pTknGfxContext, "editorToggle", editorTopBarPanel.editorDragWidget.backgroundNode, 1, editorToggleHorizontal, editorToggleVertical, function(isToggled)
        ui.setNodeTransformActive(editorRootNode, isToggled)
        ui.setTextContent(editorTopBarPanel.editorToggleTextNode, "" .. (isToggled and "Hide" or "Show") .. " Editor \xEE\xB1\xA0")
    end)

    editorTopBarPanel.editorToggleTextNode = ui.addTextNode(pTknGfxContext, editorTopBarPanel.editorDragWidget.backgroundNode, 2, "editorToggleText", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 40,
        maxOffset = 0,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }, "Show Editor \xEE\xB1\xA0", tknWidgetConfig.font, tknWidgetConfig.normalFontSize, colorPreset.semiLighter, 0, 0.5, 0.5, false)
    return editorTopBarPanel
end

function editorTopBarPanel.destroy(pTknGfxContext)
    tknWidgetConfig.removeToggleWidget(pTknGfxContext, editorTopBarPanel.editorToggleWidget)
    tknWidgetConfig.removeDragWidget(pTknGfxContext, editorTopBarPanel.editorDragWidget)

end

return editorTopBarPanel
