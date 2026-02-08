local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknDropdownWidget = require("engine.widgets.tknDropdownWidget")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknWindowWidget = require("engine.widgets.tknWindowWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknImageNode = require("engine.widgets.tknImageNode")
local ui = require("ui.ui")
local uiInspectorPanel = {}

function uiInspectorPanel.create(pTknGfxContext, parent, index)
    local panel = {}
    local horizontal = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1024,
        offset = 0,
    }
    local vertical = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1280,
        offset = 0,
    }
    tknWindowWidget.addWidget(pTknGfxContext, "uiInspectorWindowWidget", parent, index, horizontal, vertical, "\xef\x8b\x86 UI Node Inspector")
    return panel
end

function uiInspectorPanel.destroy(pTknGfxContext, panel)

end
return uiInspectorPanel
