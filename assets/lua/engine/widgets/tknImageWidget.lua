local ui = require("ui.ui")
local input = require("input")
local tknImageWidget = {}

function tknImageWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, transform, color, opacity, fitMode, image, imageUv, active)
    ui.addImageNode(pTknGfxContext, parent, index, name, horizontal, vertical, transform, color, opacity, fitMode, image, imageUv, active)
end

function tknImageWidget.removeWidget(pTknGfxContext, imageNode)
    ui.removeNode(pTknGfxContext, imageNode)
end
return tknImageWidget
