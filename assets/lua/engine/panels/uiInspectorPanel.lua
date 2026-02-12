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

local function isChildOfFieldNode(fields, parentFields)
    if #fields <= #parentFields then
        return false
    end
    for i = 1, #parentFields do
        if fields[i] ~= parentFields[i] then
            return false
        end
    end
    return true
end

local function removeFieldNodeWidgetChildren(pTknGfxContext, panel, index)
    local parentFields = panel.fieldTreeNodeWidgets[index].fields
    while index + 1 <= #panel.fieldTreeNodeWidgets and isChildOfFieldNode(panel.fieldTreeNodeWidgets[index + 1].fields, parentFields) do
        local w = table.remove(panel.fieldTreeNodeWidgets, index + 1)
        tknTreeNodeWidget.removeWidget(pTknGfxContext, w)
    end
    for i = index + 1, #panel.fieldTreeNodeWidgets do
        ui.setNodeOrientation(panel.fieldTreeNodeWidgets[i].selectedToggleWidget.toggleNode, ui.orientationType.vertical, {
            type = ui.layoutType.anchored,
            anchor = 0,
            pivot = 0,
            length = tknWidgetConfig.largeInteractableWidth,
            offset = (i - 1) * tknWidgetConfig.largeInteractableWidth,
        })
    end
end

local function addFieldTreeNodeWidget(pTknGfxContext, panel, node, fields, index)
    local value = nil
    for i, field in ipairs(fields) do
        if value == nil then
            value = node[field]
        else
            value = value[field]
        end
    end
    local iconString = nil
    if type(value) == "number" then
        iconString = "\xee\xb1\xb0"
    elseif type(value) == "string" then
        iconString = "\xef\x88\x81"
    elseif type(value) == "boolean" then
        -- iconString = "\xee\xae\x81"
        iconString = "\xef\x88\x99"
    elseif type(value) == "table" then
        iconString = "\xee\xab\xa9"
    elseif type(value) == "function" then
        -- iconString = "\xee\xaf\x86"
        -- iconString = "\xef\x8f\x98"
        iconString = "\xef\x93\x9c"
        
    elseif type(value) == "userdata" then
        iconString = "\xee\xb0\x96"
    elseif type(value) == "thread" then
        iconString = "\xee\xaf\xb0"
    elseif type(value) == "nil" then
        iconString = "\xef\x8e\xbb"
    else
        iconString = "\xef\x81\x85"
    end

    local contentString = string.rep("  ", #fields - 1) .. iconString .. " " .. fields[#fields] .. " : " .. tostring(value)
    local onExpandedChange = nil
    if type(value) == "table" then
        onExpandedChange = function(widget, isExpanded)
            local startIndex = 1
            for i, w in pairs(panel.fieldTreeNodeWidgets) do
                if w == widget then
                    startIndex = i
                    break
                end
            end
            if isExpanded then
                local indexOffset = 0
                for k, v in pairs(value) do
                    local newFields = {table.unpack(fields)}
                    newFields[#newFields + 1] = k
                    indexOffset = indexOffset + 1
                    addFieldTreeNodeWidget(pTknGfxContext, panel, node, newFields, startIndex + indexOffset)
                end
                for i = startIndex + indexOffset + 1, #panel.fieldTreeNodeWidgets, 1 do
                    ui.setNodeOrientation(panel.fieldTreeNodeWidgets[i].selectedToggleWidget.toggleNode, ui.orientationType.vertical, {
                        type = ui.layoutType.anchored,
                        anchor = 0,
                        pivot = 0,
                        length = tknWidgetConfig.largeInteractableWidth,
                        offset = (i - 1) * tknWidgetConfig.largeInteractableWidth,
                    })
                end
            else
                removeFieldNodeWidgetChildren(pTknGfxContext, panel, startIndex)
            end
            tknScrollViewWidget.setContentOrientation(panel.fieldTreeScrollViewWidget, ui.orientationType.vertical, {
                type = ui.layoutType.anchored,
                anchor = 0,
                pivot = 0,
                length = tknWidgetConfig.largeInteractableWidth * #panel.fieldTreeNodeWidgets,
                offset = 0,
            })
        end
    end
    local treeNodeWidget = tknTreeNodeWidget.addWidget(pTknGfxContext, panel.fieldTreeScrollViewWidget.contentNode, index, {
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
    }, contentString, nil, onExpandedChange)
    treeNodeWidget.node = node
    treeNodeWidget.fields = fields
    table.insert(panel.fieldTreeNodeWidgets, index, treeNodeWidget)
end

local function showSelected(pTknGfxContext, panel, node)
    if panel.selectedTreeNodeWidget then
        local index = 1
        for k, v in pairs(node) do
            addFieldTreeNodeWidget(pTknGfxContext, panel, node, {k}, index)
            index = index + 1
        end
    else
        while #panel.fieldTreeNodeWidgets > 0 do
            local w = table.remove(panel.fieldTreeNodeWidgets)
            tknTreeNodeWidget.removeWidget(pTknGfxContext, w)
        end
    end
end

local function removeNodeWidgetChildren(pTknGfxContext, panel, index)
    local parentNode = panel.treeNodeWidgets[index].node
    while index + 1 <= #panel.treeNodeWidgets and isChildOfNode(panel.treeNodeWidgets[index + 1].node, parentNode) do
        local w = table.remove(panel.treeNodeWidgets, index + 1)
        tknTreeNodeWidget.removeWidget(pTknGfxContext, w)
        if panel.selectedTreeNodeWidget == w then
            panel.selectedTreeNodeWidget = nil
            showSelected(pTknGfxContext, panel, nil)
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
                tknScrollViewWidget.setContentOrientation(panel.uiTreeScrollViewWidget, ui.orientationType.vertical, {
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
        showSelected(pTknGfxContext, panel, node)
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
    panel.uiTreeInspectorWindowWidget = tknWindowWidget.addWidget(pTknGfxContext, "uiTreeWindowNode", parent, index, horizontal, vertical, "\xee\xbe\x90 UI Tree Inspector")

    panel.uiTreeScrollViewWidget = tknScrollViewWidget.addWidget(pTknGfxContext, "uiTreeScrollViewNode", panel.uiTreeInspectorWindowWidget.contentNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 1024,
        offset = 0,
    })

    panel.treeNodeWidgets = {}
    panel.selectedTreeNodeWidget = nil
    addNodeWidget(pTknGfxContext, panel, ui.rootNode, 1)
    tknScrollViewWidget.setContentOrientation(panel.uiTreeScrollViewWidget, ui.orientationType.vertical, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.largeInteractableWidth * #panel.treeNodeWidgets,
        offset = 0,
    })

    panel.fieldInspectorWindowWidget = tknWindowWidget.addWidget(pTknGfxContext, "uiNodeInspectorWindowNode", parent, index, horizontal, vertical, "\xee\xa9\xbe UI Field Inspector")
    panel.fieldTreeScrollViewWidget = tknScrollViewWidget.addWidget(pTknGfxContext, "uiNodeInspectorScrollViewNode", panel.fieldInspectorWindowWidget.contentNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 0,
        offset = 0,
    })
    panel.fieldTreeNodeWidgets = {}
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

    tknScrollViewWidget.removeWidget(pTknGfxContext, panel.uiTreeScrollViewWidget)
    panel.uiTreeScrollViewWidget = nil

    -- tknScrollViewWidget.removeWidget(pTknGfxContext, panel.uiDetailScrollViewWidget)
    -- panel.uiDetailScrollViewWidget = nil
    -- panel.uiDetailTextNode = nil

    if panel.uiInspectorWindowWidget then
        tknWindowWidget.removeWidget(pTknGfxContext, panel.uiInspectorWindowWidget)
        panel.uiInspectorWindowWidget = nil
    end
end
return uiInspectorPanel
