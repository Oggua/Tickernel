local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknDragWidget = require("engine.widgets.tknDragWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local editorTopBarPanel = {}

function editorTopBarPanel.create(pTknGfxContext, editorRootNode, editorTopBarNode)
    local panel = {}
    local defualtTransform = {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = true,
    }
    panel.dragWidget = tknDragWidget.addWidget(pTknGfxContext, "editorDragWidget", editorTopBarNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 256,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.defaultNormalButtonHeight,
        offset = 0,
    })

    tknTextNode.addNode(pTknGfxContext, "editorDragText", panel.dragWidget.backgroundNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 1,
        length = 32,
        offset = -tknWidgetConfig.defaultSpacing,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, defualtTransform, "\xEE\xB1\xA0", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 1, 0.5, false)

    panel.toggleWidget = tknToggleWidget.addWidget(pTknGfxContext, "editorToggleWidget", panel.dragWidget.backgroundNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.defaultToggleHeight,
        offset = tknWidgetConfig.defaultSpacing,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.defaultToggleHeight,
        offset = 0,
    }, function(isToggled)
        ui.setNodeTransformActive(editorRootNode, isToggled)
    end)
    tknToggleWidget.setToggle(panel.toggleWidget, true)

    
    return panel
end

function editorTopBarPanel.destroy(pTknGfxContext, panel)
    tknToggleWidget.removeWidget(pTknGfxContext, panel.toggleWidget)
    tknDragWidget.removeWidget(pTknGfxContext, panel.dragWidget)
    -- tknWidgetConfig.removeDragWidget(pTknGfxContext, panel.dragWidget)

end

return editorTopBarPanel
