local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local mainPanel = {}

function mainPanel.create(pTknGfxContext, game, parent, startButtonCallback, settingsButtonCallback, quitButtonCallback)
    local panel = {}
    -- tknButtonWidget.add(pTknGfxContext, "enterGameeButton", parent, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, startButtonCallback)
    -- ui.addImageNode(pTknGfxContext, root, 1, "mainPanelBackground", tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, 0xFFFFFFFF, true, true)
    return panel
end

function mainPanel.destroy(panel, pTknGfxContext)

end

return mainPanel
