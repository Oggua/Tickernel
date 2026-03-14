local luaInspectorPanel = {}
local ui = require("ui.ui")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknDropdownWidget = require("engine.widgets.tknDropdownWidget")
local tknButtonWidget = require("engine.widgets.tknButtonWidget")
local tknWindowWidget = require("engine.widgets.tknWindowWidget")
local tknToggleWidget = require("engine.widgets.tknToggleWidget")
local tknScrollViewWidget = require("engine.widgets.tknScrollViewWidget")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTreeNodeWidget = require("engine.widgets.tknTreeNodeWidget")
local tknInputFieldWidget = require("engine.widgets.tknInputFieldWidget")

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
    local parentFields = panel.treeNodeWidgets[index].fields
    while index + 1 <= #panel.treeNodeWidgets and isChildOfFieldNode(panel.treeNodeWidgets[index + 1].fields, parentFields) do
        local w = table.remove(panel.treeNodeWidgets, index + 1)
        tknTreeNodeWidget.remove(pTknGfxContext, w)
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

local function addFieldTreeNodeWidget(pTknGfxContext, panel, fields, index)
    local value = panel.data
    for i, field in ipairs(fields) do
        value = value[field]
    end
    local iconString = nil
    if type(value) == "number" then
        iconString = "\xee\xb1\xb0"
    elseif type(value) == "string" then
        iconString = "\xef\x88\x81"
    elseif type(value) == "boolean" then
        iconString = "\xef\x88\x99"
    elseif type(value) == "table" then
        iconString = "\xee\xab\xa9"
    elseif type(value) == "function" then
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
    local contentString
    if #fields == 0 then
        contentString = string.rep("  ", #fields) .. iconString .. " " .. panel.dataName .. " : " .. tostring(value)
    else
        contentString = string.rep("  ", #fields) .. iconString .. " " .. fields[#fields] .. " : " .. tostring(value)
    end
    local onExpandedChange = nil
    if type(value) == "table" then
        onExpandedChange = function(widget, isExpanded)
            local startIndex = 1
            for i, w in pairs(panel.treeNodeWidgets) do
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
                    addFieldTreeNodeWidget(pTknGfxContext, panel, newFields, startIndex + indexOffset)
                end
                for i = startIndex + indexOffset + 1, #panel.treeNodeWidgets, 1 do
                    ui.setNodeOrientation(panel.treeNodeWidgets[i].selectedToggleWidget.toggleNode, ui.orientationType.vertical, {
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
            tknScrollViewWidget.setContentOrientation(panel.scrollViewWidget, ui.orientationType.vertical, {
                type = ui.layoutType.anchored,
                anchor = 0,
                pivot = 0,
                length = tknWidgetConfig.largeInteractableWidth * #panel.treeNodeWidgets,
                offset = 0,
            })
        end
    end
    local treeNodeWidget = tknTreeNodeWidget.add(pTknGfxContext, panel.scrollViewWidget.contentNode, index, {
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
    treeNodeWidget.fields = fields
    table.insert(panel.treeNodeWidgets, index, treeNodeWidget)
end
function luaInspectorPanel.create(pTknGfxContext, parent, index)
    local panel = {}
    -- Window 
    local defaultItemVertical = {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = tknWidgetConfig.largeInteractableWidth,
        offset = tknWidgetConfig.defaultSpacing,
    }
    panel.windowWidget = tknWindowWidget.add(pTknGfxContext, "windowNode", parent, index, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, "\xee\xa9\xbe Lua Inspector")
    panel.codeInputFieldWidget = tknInputFieldWidget.add(pTknGfxContext, "codeInputField", panel.windowWidget.contentNode, 1, {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = 0,
        maxOffset = -128 - tknWidgetConfig.defaultSpacing,
        offset = 0,
    }, defaultItemVertical, "Code...")
    panel.runButtonWidget = tknButtonWidget.add(pTknGfxContext, "runButton", panel.windowWidget.contentNode, 2, {
        type = ui.layoutType.anchored,
        anchor = 1,
        pivot = 1,
        length = 128,
        offset = 0,
    }, defaultItemVertical, function()
        local code = panel.codeInputFieldWidget.text
        local fn, compileErr = load(code)
        if not fn then
            luaInspectorPanel.bind(pTknGfxContext, panel, {
                error = compileErr,
            }, "[compile error]")
            return
        end
        local results = table.pack(pcall(fn))
        local ok = table.remove(results, 1)
        results.n = results.n - 1
        if not ok then
            luaInspectorPanel.bind(pTknGfxContext, panel, {
                error = results[1],
            }, "[runtime error]")
        elseif results.n == 1 then
            luaInspectorPanel.bind(pTknGfxContext, panel, results[1], "result")
        else
            luaInspectorPanel.bind(pTknGfxContext, panel, results, "results")
        end
    end)
    panel.runButtonTextNode = tknTextNode.addNode(pTknGfxContext, "runButtonText", panel.runButtonWidget.backgroundNode, 1, tknWidgetConfig.paddedRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, "\xef\x80\x8b Run", tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0.5, 0.5, false)
    panel.scrollViewWidget = tknScrollViewWidget.add(pTknGfxContext, "scrollViewNode", panel.windowWidget.contentNode, 1, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.relative,
        pivot = 0,
        minOffset = tknWidgetConfig.largeInteractableWidth + tknWidgetConfig.defaultSpacing,
        maxOffset = 0,
        offset = 0,
    }, tknWidgetConfig.fullRelativeOrientation, {
        type = ui.layoutType.anchored,
        anchor = 0,
        pivot = 0,
        length = 0,
        offset = tknWidgetConfig.largeInteractableWidth + tknWidgetConfig.defaultSpacing,
    })

    panel.treeNodeWidgets = {}
    return panel
end

function luaInspectorPanel.destroy(pTknGfxContext, panel)
    for i, v in ipairs(panel.treeNodeWidgets) do
        tknTreeNodeWidget.remove(pTknGfxContext, v)
    end
    tknScrollViewWidget.remove(pTknGfxContext, panel.scrollViewWidget)
    tknWindowWidget.remove(pTknGfxContext, panel.windowWidget)
end

function luaInspectorPanel.bind(pTknGfxContext, panel, data, dataName)
    for i = #panel.treeNodeWidgets, 1, -1 do
        tknTreeNodeWidget.remove(pTknGfxContext, panel.treeNodeWidgets[i])
        table.remove(panel.treeNodeWidgets, i)
    end

    panel.data = data
    panel.dataName = dataName
    addFieldTreeNodeWidget(pTknGfxContext, panel, {}, 1)
end

return luaInspectorPanel
