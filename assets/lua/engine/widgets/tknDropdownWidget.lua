local ui = require("ui.ui")
local input = require("input")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknDropdownWidget = {}

function tknDropdownWidget.addWidget(pTknGfxContext, name, parent, index, horizontal, vertical, text)
    local widget = {}
    widget.buttonWidget = tknButtonWidget.addWidget(pTknGfxContext, "dropdownButton", parent, index, horizontal, vertical, text, function()

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

function tknDropdownWidget.removeWidget(pTknGfxContext, widget)

end

return tknDropdownWidget
