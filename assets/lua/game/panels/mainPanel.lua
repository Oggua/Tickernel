local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local mainPanel = {}

function mainPanel.create(pTknGfxContext, game, parent, startButtonCallback, settingsButtonCallback, quitButtonCallback)
    local panel = {}
    -- ui.addImageNode(pTknGfxContext, parent, 1, "mainPanelBackground", tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, 0xFFFFFFFF, true, true)
    return panel
end

function mainPanel.destroy(panel, pTknGfxContext)

end

return mainPanel
