local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknDropdownWidget = require("engine.widgets.tknDropdownWidget")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknWindowWidget = require("engine.widgets.tknWindowWidget")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local tknScrollViewWidget = require("engine.widgets.tknScrollViewWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTreeNodeWidget = require("engine.widgets.tknTreeNodeWidget")
local ui = require("ui.ui")
local uiInspectorPanel = {}

local function addNodeWidget(pTknGfxContext, panel, node)
    local treeNodeWidget = tknTreeNodeWidget.addWidget(pTknGfxContext, node.name, panel.uiTreeScrollViewWidget.contentNode, 1, {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = 0,
        maxOffset = -tknWidgetConfig.smallInteractableWidth,
        offset = 0,
    }, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.largeInteractableWidth,
        offset = 0,
    }, node.name, nil, function(widget, isExpanded)
        if node.children then
            for _, childNode in ipairs(node.children) do
                if isExpanded then
                    addNodeWidget(pTknGfxContext, panel, childNode)
                else
                    local childWidget = panel.treeNodeWidgets[childNode]
                    if childWidget then
                        ui.removeNode(pTknGfxContext, childWidget.selectedToggleWidget.backgroundNode)
                        panel.treeNodeWidgets[childNode] = nil
                    end
                end
            end
        end
    end)
    panel.treeNodeWidgets[node] = treeNodeWidget
end

function uiInspectorPanel.create(pTknGfxContext, parent, index)
    local panel = {}
    local horizontal = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1024,
        offset = 0,
    }
    local vertical = {
        type = ui.layoutType.anchored,
        anchor = 0.5,
        pivot = 0.5,
        length = 1280,
        offset = 0,
    }
    panel.uiInspectorWindowWidget = tknWindowWidget.addWidget(pTknGfxContext, "uiInspectorWindowWidget", parent, index, horizontal, vertical, "\xef\x8b\x86 UI Node Inspector")

    local detailHeight = 512
    panel.uiDetailScrollViewWidget = tknScrollViewWidget.addWidget(pTknGfxContext, "uiDetailScrollView", panel.uiInspectorWindowWidget.contentParentNode, 1, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = detailHeight,
        offset = tknWidgetConfig.defaultSpacing,
    }, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 1024,
        offset = 0,
    })

    panel.uiTreeScrollViewWidget = tknScrollViewWidget.addWidget(pTknGfxContext, "uiTreeScrollView", panel.uiInspectorWindowWidget.contentParentNode, 1, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = detailHeight + tknWidgetConfig.defaultSpacing * 2,
        maxOffset = 0,
        offset = 0,
    }, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 1024,
        offset = 0,
    })

    local selectedNode = nil

    panel.treeNodeWidgets = {}
    panel.selectedNode = nil
    addNodeWidget(pTknGfxContext, panel, ui.rootNode)
    return panel
end

function uiInspectorPanel.destroy(pTknGfxContext, panel)

end
return uiInspectorPanel
