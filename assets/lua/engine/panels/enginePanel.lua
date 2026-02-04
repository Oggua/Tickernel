local ui = require("ui.ui")
local input = require("input")
local widget = require("engine.widgets.widget")
local enginePanel = {}

function enginePanel.create(pTknGfxContext, editorRootNode, editorTopBarNode)
    local tknToggleHorizontal = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 256,
        offset = 0,
    }
    local tknToggleVertical = {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0.5,
        length = 64,
        offset = 0,
    }
    local dragWidgetInstance = widget.addDragWidget(pTknGfxContext, "tknToggleButton", editorTopBarNode, 1, tknToggleHorizontal, tknToggleVertical, widget.image, widget.imageFitMode, widget.imageUv, widget.color.background, widget.updateClickWidgetColor)
end

function enginePanel.destroy(pTknGfxContext)

end

return enginePanel
