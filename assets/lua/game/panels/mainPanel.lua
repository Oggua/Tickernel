local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknTextNode = require("engine.widgets.tknTextNode")

local mainPanel = {}

function mainPanel.create(pTknGfxContext, game, parent)
    local panel = {}
    panel.mapEditorButtonWidget = tknButtonWidget.add(pTknGfxContext, "mapEditorButton", parent, 1, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 512,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.largeInteractableWidth,
        offset = 0,
    }, function()
        game.switchScene(require("game.scenes.mapEditorScene"))
    end)
    tknTextNode.add(pTknGfxContext, "mapEditorButtonLabel", panel.mapEditorButtonWidget.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Map Editor", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)

    panel.gameSceneButtonWidget = tknButtonWidget.add(pTknGfxContext, "gameSceneButton", parent, 1, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 512,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.largeInteractableWidth,
        offset = -2 * tknWidgetConfig.largeInteractableWidth,
    }, function()
        game.switchScene(require("game.scenes.gameScene"))
    end)
    tknTextNode.add(pTknGfxContext, "gameSceneButtonLabel", panel.gameSceneButtonWidget.backgroundNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "Play Game", tknWidgetConfig.normalFontSize, 0xFFFFFFFF, 0.5, 0.5)

    return panel
end

function mainPanel.destroy(pTknGfxContext, panel)
    tknButtonWidget.remove(pTknGfxContext, panel.mapEditorButtonWidget)
    tknButtonWidget.remove(pTknGfxContext, panel.gameSceneButtonWidget)
end

return mainPanel
