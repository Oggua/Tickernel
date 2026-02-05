local ui = require("ui.ui")
local input = require("input")
local widget = require("engine.widgets.widget")
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
        anchor = 0,
        pivot = 0.5,
        length = 64,
        offset = 0,
    }
    editorTopBarPanel.editorDragWidget = widget.addDragWidget(pTknGfxContext, "editorDrag", editorTopBarNode, 1, editorDragHorizontal, editorDragVertical)

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
    editorTopBarPanel.editorToggleWidget = widget.addToggleWidget(pTknGfxContext, "editorToggle", editorTopBarPanel.editorDragWidget.backgroundNode, 1, editorToggleHorizontal, editorToggleVertical, function(isToggled)
        ui.setNodeTransformActive(editorRootNode, isToggled)
    end)

    ui.addTextNode(pTknGfxContext, editorTopBarPanel.editorDragWidget.backgroundNode, 2, "editorToggleText", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 48,
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
    }, "Editor", widget.font, widget.normalFontSize, widget.color.foreground, 0, 0, 0.5, false)

    ui.addTextNode(pTknGfxContext, editorTopBarPanel.editorDragWidget.backgroundNode, 2, "editorToggleText", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 48,
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
    }, "\xEE\xB1\x9F", widget.font, widget.normalFontSize, widget.color.foreground, 0, 1, 0.5, false)

    return editorTopBarPanel
end

function editorTopBarPanel.destroy(pTknGfxContext)
    widget.removeToggleWidget(pTknGfxContext, editorTopBarPanel.editorToggleWidget)
    widget.removeDragWidget(pTknGfxContext, editorTopBarPanel.editorDragWidget)

end

return editorTopBarPanel
