local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")

local tknImageNode = {}
function tknImageNode.addNode(pTknGfxContext, name, parent, index, horizontal, vertical, transform, color, mask, isRounded)
    if isRounded then
        return ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, color, tknWidgetConfig.defaultAlphaThreshold, tknWidgetConfig.roundedImageFitMode, tknWidgetConfig.roundedImage, tknWidgetConfig.roundedImageUv, mask)
    else
        return ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, color, tknWidgetConfig.defaultAlphaThreshold, tknWidgetConfig.squareImageFitMode, tknWidgetConfig.squareImage, tknWidgetConfig.squareImageUv, mask)
    end
end
return tknImageNode
