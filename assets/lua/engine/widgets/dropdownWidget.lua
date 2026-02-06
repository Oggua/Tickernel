local ui = require("ui.ui")
local input = require("input")
local buttonWidget = require("engine.widgets.buttonWidget")
local dropdownWidget = {}
function dropdownWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, image, imageFitMode, imageUv, imageColor, font, text, fontSize, fontColor, animate, callbacks)
    local widget = {}
    widget.buttonWidget = buttonWidget.addWidget(pTknGfxContext, "dropdownButton", parent, index, horizontal, vertical, image, imageFitMode, imageUv, imageColor, font, text, fontSize, fontColor, animate, function()

    end)

    widget.dropdownBackgroundNode = ui.addImageNode(pTknGfxContext, widget.buttonWidget.buttonNode, 1, "dropdownBackground", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 1,
        length = 0,
        offset = 0,
    }, {
        rotation = 0,
        horizontalScale = 1,
        verticalScale = 1,
        color = nil,
        active = false,
    }, imageColor, 0, imageFitMode, image, imageUv, nil)

    return widget
end

function dropdownWidget.removeWidget(pTknGfxContext, widget)

end

return dropdownWidget
