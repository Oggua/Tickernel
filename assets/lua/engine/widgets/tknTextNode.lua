local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")

local tknTextNode = {}
function tknTextNode.addNode(pTknGfxContext, name, parent, index, horizontal, vertical, transform, textContent, fontSize, color, horizontalAlign, verticalAlign, bold)
    return ui.addTextNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, textContent, tknWidgetConfig.font, fontSize, color, 0.01, horizontalAlign, verticalAlign, bold)
end
return tknTextNode
