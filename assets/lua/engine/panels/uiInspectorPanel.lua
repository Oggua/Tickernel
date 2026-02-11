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

local function formatValue(v, depth, maxDepth)
    if type(v) ~= "table" or depth >= maxDepth then
        return tostring(v)
    end
    local indent = string.rep("  ", depth + 1)
    local parts = {}
    for k2, v2 in pairs(v) do
        parts[#parts + 1] = indent .. tostring(k2) .. ": " .. formatValue(v2, depth + 1, maxDepth)
    end
    return "{\n" .. table.concat(parts, "\n") .. "\n" .. string.rep("  ", depth) .. "}"
end

local function showSelected(panel)
    local detailString = ""
    if panel.selectedTreeNodeWidget == nil then
        detailString = "No UI Node Selected.."
    else
        local node = panel.selectedTreeNodeWidget.node
        for k, v in pairs(node) do
            detailString = detailString .. tostring(k) .. ": " .. formatValue(v, 0, 3) .. "\n"
        end
    end
    ui.setTextString(panel.uiDetailTextNode, detailString)
    local length = ui.measureText(panel.uiDetailTextNode.font, detailString, panel.uiDetailTextNode.size, panel.uiDetailTextNode.rect.horizontal.max - panel.uiDetailTextNode.rect.horizontal.min, ui.screenWidth, ui.screenHeight)
    print("Measured detail text length: " .. tostring(length))
    ui.setNodeOrientation(panel.uiDetailScrollViewWidget.contentNode, ui.orientationType.vertical, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = length,
        offset = 0,
    })
end

local function isChildOfNode(node, parent)
    local currentNode = node
    while currentNode ~= nil do
        if currentNode == parent then
            return true
        end
        currentNode = currentNode.parent
    end
    return false
end

local function removeNodeWidgetChildren(pTknGfxContext, panel, index)
    local parentNode = panel.treeNodeWidgets[index].node
    while index + 1 <= #panel.treeNodeWidgets and isChildOfNode(panel.treeNodeWidgets[index + 1].node, parentNode) do
        local w = table.remove(panel.treeNodeWidgets, index + 1)
        tknTreeNodeWidget.removeWidget(pTknGfxContext, w)
        if panel.selectedTreeNodeWidget == w then
            panel.selectedTreeNodeWidget = nil
            showSelected(panel)
        end
    end
    for i = index + 1, #panel.treeNodeWidgets do
        ui.setNodeOrientation(panel.treeNodeWidgets[i].selectedToggleWidget.toggleNode, ui.orientationType.vertical, {
            type = ui.layoutType.anchored,
            anchor = 0,
            pivot = 0,
            length = tknWidgetConfig.largeInteractableWidth,
            offset = (i - 1) * tknWidgetConfig.largeInteractableWidth,
        })
    end
end

local function addNodeWidget(pTknGfxContext, panel, node, index)
    local parentCount = 0
    local currentParent = node.parent
    while currentParent ~= nil do
        parentCount = parentCount + 1
        currentParent = currentParent.parent
    end
    local contentString
    if node.type == ui.nodeType.imageNode then
        contentString = string.rep("  ", parentCount) .. "\xee\xb9\x85 " .. node.name
    elseif node.type == ui.nodeType.node then
        contentString = string.rep("  ", parentCount) .. "\xee\xbe\x90 " .. node.name
    elseif node.type == ui.nodeType.textNode then
        contentString = string.rep("  ", parentCount) .. "\xee\xa9\xbe " .. node.name
    elseif node.type == ui.nodeType.interactableNode then
        contentString = string.rep("  ", parentCount) .. "\xee\xbd\xbd " .. node.name
    else
        error("Unknown node type: " .. tostring(node.type))
    end
    local onExpandedChange = nil
    if #node.children > 0 then
        onExpandedChange = function(widget, isExpanded)
            if node.children and #node.children > 0 then
                local startIndex = 1
                for i, w in pairs(panel.treeNodeWidgets) do
                    if w == widget then
                        startIndex = i
                        break
                    end
                end
                if isExpanded then
                    for i, childNode in ipairs(node.children) do
                        addNodeWidget(pTknGfxContext, panel, childNode, startIndex + i)
                    end
                    for i = startIndex + #node.children + 1, #panel.treeNodeWidgets, 1 do
                        ui.setNodeOrientation(panel.treeNodeWidgets[i].selectedToggleWidget.toggleNode, ui.orientationType.vertical, {
                            type = ui.layoutType.anchored,
                            anchor = 0,
                            pivot = 0,
                            length = tknWidgetConfig.largeInteractableWidth,
                            offset = (i - 1) * tknWidgetConfig.largeInteractableWidth,
                        })
                    end

                else
                    removeNodeWidgetChildren(pTknGfxContext, panel, startIndex)
                end
                ui.setNodeOrientation(panel.uiTreeScrollViewWidget.contentNode, ui.orientationType.vertical, {
                    type = ui.layoutType.anchored,
                    anchor = 0,
                    pivot = 0,
                    length = tknWidgetConfig.largeInteractableWidth * #panel.treeNodeWidgets,
                    offset = 0,
                })
            end
        end
    end
    local treeNodeWidget = tknTreeNodeWidget.addWidget(pTknGfxContext, panel.uiTreeScrollViewWidget.contentNode, index, {
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
        offset = (index - 1) * tknWidgetConfig.largeInteractableWidth,
    }, contentString, function(widget, isOn)
        if isOn then
            if panel.selectedTreeNodeWidget ~= nil then
                tknToggleWidget.setIsOn(panel.selectedTreeNodeWidget.selectedToggleWidget, false)
            end
            panel.selectedTreeNodeWidget = widget
        else
            panel.selectedTreeNodeWidget = nil
        end
        showSelected(panel)
    end, onExpandedChange)
    treeNodeWidget.node = node
    table.insert(panel.treeNodeWidgets, index, treeNodeWidget)
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
        length = 0,
        offset = 0,
    })
    panel.uiDetailTextNode = tknTextNode.addNode(pTknGfxContext, "detailPlaceholderText", panel.uiDetailScrollViewWidget.contentNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0, false)

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

    panel.treeNodeWidgets = {}
    panel.selectedTreeNodeWidget = nil
    addNodeWidget(pTknGfxContext, panel, ui.rootNode, 1)
    ui.setNodeOrientation(panel.uiTreeScrollViewWidget.contentNode, ui.orientationType.vertical, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.largeInteractableWidth * #panel.treeNodeWidgets,
        offset = 0,
    })

    ui.setNodeOrientation(panel.uiDetailScrollViewWidget.contentNode, ui.orientationType.vertical, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 0,
        offset = 0,
    })

    return panel
end

function uiInspectorPanel.destroy(pTknGfxContext, panel)
    if panel == nil then
        return
    end

    if panel.treeNodeWidgets then
        for i = #panel.treeNodeWidgets, 1, -1 do
            local widget = panel.treeNodeWidgets[i]
            tknTreeNodeWidget.removeWidget(pTknGfxContext, widget)
            panel.treeNodeWidgets[i] = nil
        end
    end
    panel.selectedTreeNodeWidget = nil

    if panel.uiTreeScrollViewWidget then
        tknScrollViewWidget.removeWidget(pTknGfxContext, panel.uiTreeScrollViewWidget)
        panel.uiTreeScrollViewWidget = nil
    end

    if panel.uiDetailScrollViewWidget then
        tknScrollViewWidget.removeWidget(pTknGfxContext, panel.uiDetailScrollViewWidget)
        panel.uiDetailScrollViewWidget = nil
    end
    panel.uiDetailTextNode = nil

    if panel.uiInspectorWindowWidget then
        tknWindowWidget.removeWidget(pTknGfxContext, panel.uiInspectorWindowWidget)
        panel.uiInspectorWindowWidget = nil
    end
end
return uiInspectorPanel
