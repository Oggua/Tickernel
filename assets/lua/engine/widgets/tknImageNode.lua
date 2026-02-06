local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")

local tknImageNode = {}
function tknImageNode.addNode(pTknGfxContext, name, parent, index, horizontal, vertical, transform, color, mask)
    return ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, color, tknWidgetConfig.defaultAlphaThreshold, tknWidgetConfig.imageFitMode, tknWidgetConfig.image, tknWidgetConfig.imageUv, mask)
end
return tknImageNode
