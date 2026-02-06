local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknDragWidget = require("engine.widgets.tknDragWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local editorTopBarPanel = {}

function editorTopBarPanel.create(pTknGfxContext, editorRootNode, editorTopBarNode)
    local defualtTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    editorTopBarPanel.dragWidget = tknDragWidget.addWidget(pTknGfxContext, "editorDragWidget", editorTopBarNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 256,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.defaultButtonHeight,
        offset = 0,
    })

    tknTextNode.addNode(pTknGfxContext, "editorDragText", editorTopBarPanel.dragWidget.backgroundNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 1,
        length = 32,
        offset = -tknWidgetConfig.defaultPadding,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, defualtTransform, "\xEE\xB1\xA0", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 1, 0.5, false)

    editorTopBarPanel.toggleWidget = tknToggleWidget.addWidget(pTknGfxContext, "editorToggleWidget", editorTopBarPanel.dragWidget.backgroundNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.defaultToggleHeight,
        offset = tknWidgetConfig.defaultPadding,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.defaultToggleHeight,
        offset = 0,
    }, function(isToggled)
        ui.setNodeTransformActive(editorRootNode, isToggled)
    end)
    return editorTopBarPanel
end

function editorTopBarPanel.destroy(pTknGfxContext)
    tknDragWidget.removeWidget(pTknGfxContext, editorTopBarPanel.dragWidget)
    -- tknWidgetConfig.removeToggleWidget(pTknGfxContext, editorTopBarPanel.editorToggleWidget)
    -- tknWidgetConfig.removeDragWidget(pTknGfxContext, editorTopBarPanel.editorDragWidget)

end

return editorTopBarPanel
