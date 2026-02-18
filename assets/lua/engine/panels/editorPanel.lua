local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknDropdownWidget = require("engine.widgets.tknDropdownWidget")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknImageNode = require("engine.widgets.tknImageNode")

local uiInspectorPanel = require("engine.panels.uiInspectorPanel")
local editorPanel = {}

function editorPanel.create(pTknGfxContext, editorRootNode)
    local panel = {}
    panel.topBarBackgroundNode = tknImageNode.addNode(pTknGfxContext, "editorPanelBackgroundNode", editorRootNode, 1, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.largeInteractableWidth + (2 * tknWidgetConfig.defaultSpacing),
        offset = 0,
    }, tknWidgetConfig.defaultTransform, tknWidgetConfig.color.semiDarker, false, false)

    local closeLastPanel = function(widget)
        if panel.uiInspectorPanel then
            uiInspectorPanel.destroy(pTknGfxContext, panel.uiInspectorPanel)
            panel.uiInspectorPanel = nil
        end
    end

    local dropdownItems = {{
        name = "\xef\x98\x99 Game",
        onSelect = function(widget)
            print("Add Game Inspector selected")
            closeLastPanel(widget)
        end,
    }, {
        name = "\xef\x8b\x86 UI Inspector",
        onSelect = function(widget)
            closeLastPanel(widget)
            panel.uiInspectorPanel = uiInspectorPanel.create(pTknGfxContext, panel.contentNode, 1)
        end,
    }, {
        name = "\xee\xb5\x95 Asset Browser",
        onSelect = function(widget)
            print("Add Asset Browser selected")
            closeLastPanel(widget)
        end,
    } -- {
    --     name = "\xef\x87\xb9 Console",
    --     onSelect = function(widget)
    --         print("Add Console selected")
    --         closeLastPanel(widget)
    --     end,
    -- }
    }

    panel.topBarDropdownWidget = tknDropdownWidget.addWidget(pTknGfxContext, "editorPanelDropdownWidget", panel.topBarBackgroundNode, 1, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 512,
        offset = tknWidgetConfig.defaultSpacing,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = tknWidgetConfig.largeInteractableWidth,
        offset = 0,
    }, dropdownItems)

    panel.contentNode = ui.addNode(pTknGfxContext, editorRootNode, 1, "editorPanelContentNode", {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = 0,
        maxOffset = 0,
        offset = 0,
    }, {
        type = ui.layoutType.relative,
        pivot = 0.5,
        minOffset = tknWidgetConfig.largeInteractableWidth + (2 * tknWidgetConfig.defaultSpacing),
        maxOffset = 0,
        offset = 0,
    }, tknWidgetConfig.defaultTransform)

    return panel
end

function editorPanel.destroy(pTknGfxContext, panel)
    tknDropdownWidget.removeWidget(pTknGfxContext, panel.topBarDropdownWidget)
    panel.topBarDropdownWidget = nil
    uiInspectorPanel.destroy(pTknGfxContext, panel.uiInspectorPanel)
    panel.uiInspectorPanel = nil
    ui.removeNode(pTknGfxContext, panel.contentNode)
    panel.contentNode = nil
    ui.removeNode(pTknGfxContext, panel.topBarBackgroundNode)
    panel.topBarBackgroundNode = nil
end

return editorPanel
