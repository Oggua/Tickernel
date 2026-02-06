local ui = require("ui.ui")
local input = require("input")
-- local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local editorPanel = {}

function editorPanel.create(pTknGfxContext, editorRootNode)
    -- local buttonHeight = 48
    -- editorPanel.addTabButtonWidget = tknWidgetConfig.addButtonWidget(pTknGfxContext, "addTabButton", editorRootNode, 1, {
    --     type = ui.layoutType.anchored,
    --     anchor = 0,
    --     pivot = 0,
    --     length = 512,
    --     offset = 0,
    -- }, {
    --     type = ui.layoutType.anchored,
    --     anchor = 0,
    --     pivot = 0,
    --     length = buttonHeight,
    --     offset = 0,
    -- }, "\xEE\xA8\x8E Add Tab", function()
    --     print("Add Tab button clicked")
    -- end)

    -- local buttonConfigs = {{
    --     name = "Add UI Inspector",
    --     func = function()
    --         print("Add UI Inspector selected")
    --     end,
    -- }, {
    --     name = "Add Entity Inspector",
    --     func = function()
    --         print("Add Entity Inspector selected")
    --     end,
    -- }}

    -- local defualtTransform = {
    --     rotation = 0,
    --     horizontalScale = 1,
    --     verticalScale = 1,
    --     color = nil,
    --     active = true,
    -- }
    -- editorPanel.dropdownBackgroundNode = tknWidgetConfig.addBackgroundImageNode(pTknGfxContext, editorPanel.addTabButtonWidget.buttonNode, 1, "dropdownBackground", {
    --     type = ui.layoutType.relative,
    --     pivot = 0.5,
    --     minOffset = 0,
    --     maxOffset = 0,
    --     offset = 0,
    -- }, {
    --     type = ui.layoutType.anchored,
    --     anchor = 1,
    --     pivot = 0,
    --     length = #buttonConfigs * buttonHeight,
    --     offset = 0,
    -- }, defualtTransform)
    -- for i, buttonConfig in ipairs(buttonConfigs) do
    --     tknWidgetConfig.addButtonWidget(pTknGfxContext, buttonConfig.name, editorPanel.dropdownBackgroundNode, i, {
    --         type = ui.layoutType.relative,
    --         pivot = 0.5,
    --         minOffset = 0,
    --         maxOffset = 0,
    --         offset = 0,
    --     }, {
    --         type = ui.layoutType.anchored,
    --         anchor = 0,
    --         pivot = 0,
    --         length = buttonHeight,
    --         offset = ((i - 1) * buttonHeight),
    --     }, buttonConfig.name, buttonConfig.func)
    -- end
end

function editorPanel.destroy(pTknGfxContext)
    -- tknWidgetConfig.removeButtonWidget(pTknGfxContext, editorPanel.addTabButtonWidget)
end

return editorPanel
