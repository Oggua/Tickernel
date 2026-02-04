local ui = require("ui.ui")
local input = require("input")
local widget = require("engine.widgets.widget")
local editorPanel = {}

function editorPanel.create(pTknGfxContext, editorRootNode)
    editorPanel.addTabButtonWidget = widget.addButtonWidget(pTknGfxContext, "addTabButton", editorRootNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 32,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 64,
        offset = 0,
    }, "+", function()
        print("Add Tab button clicked")
    end)
end

function editorPanel.destroy(pTknGfxContext)
    widget.removeButtonWidget(pTknGfxContext, editorPanel.addTabButtonWidget)
end

return editorPanel
