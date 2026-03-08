local ui = require("ui.ui")
local input = require("input")
local tknWidgetConfig = require("engine.widgets.tknWidgetConfig")
local tknImageNode = require("engine.widgets.tknImageNode")
local tknTextNode = require("engine.widgets.tknTextNode")
local tknInputFieldWidget = {}

function tknInputFieldWidget.add(pTknGfxContext, name, parent, index, horizontal, vertical, placeholder, onValueChange)
    local widget = {}
    widget.text = ""
    widget.placeholder = placeholder or ""
    widget.isFocused = false
    widget.onValueChange = onValueChange
    widget.cursorVisible = true
    widget.cursorTimer = 0

    local processInput = function(node, xNdc, yNdc, inputState)
        if tknWidgetConfig.updateClickWidgetColor then
            tknWidgetConfig.updateClickWidgetColor(node, xNdc, yNdc, inputState)
        end
        if ui.rectContainsPoint(node.rect, xNdc, yNdc) then
            if inputState == input.inputState.down then
                tknInputFieldWidget.setFocused(widget, true)
            end
        else
            if inputState == input.inputState.up then
                tknInputFieldWidget.setFocused(widget, false)
                return false
            end
        end
        print("Input state:", inputState, "Focused widget:", tknInputFieldWidget.focusedWidget)
        return widget.isFocused
    end

    widget.inputFieldNode = ui.addInteractableNode(pTknGfxContext, processInput, parent, index, name, horizontal, vertical, tknWidgetConfig.defaultTransform)

    widget.backgroundNode = tknImageNode.addNode(pTknGfxContext, "inputFieldBackground", widget.inputFieldNode, 1, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, tknWidgetConfig.color.semiDark, false, true)

    widget.textNode = tknTextNode.addNode(pTknGfxContext, "inputFieldText", widget.backgroundNode, 1, tknWidgetConfig.paddedRelativeOrientation, tknWidgetConfig.fullRelativeOrientation, tknWidgetConfig.defaultTransform, widget.placeholder, tknWidgetConfig.normalFontSize, tknWidgetConfig.color.semiLighter, 0, 0.5, false)

    return widget
end

function tknInputFieldWidget.remove(pTknGfxContext, widget)
    if tknInputFieldWidget.focusedWidget == widget then
        input.imeEnabled = false
        tknInputFieldWidget.focusedWidget = nil
    end
    ui.removeNode(pTknGfxContext, widget.inputFieldNode)
    widget.inputFieldNode = nil
    widget.backgroundNode = nil
    widget.textNode = nil
end

function tknInputFieldWidget.setFocused(widget, focused)
    if widget.isFocused == focused then
        return
    end
    widget.isFocused = focused
    if focused then
        if tknInputFieldWidget.focusedWidget and tknInputFieldWidget.focusedWidget ~= widget then
            tknInputFieldWidget.setFocused(tknInputFieldWidget.focusedWidget, false)
        end
        tknInputFieldWidget.focusedWidget = widget
        input.imeEnabled = true
        widget.cursorVisible = true
        widget.cursorTimer = 0
        tknInputFieldWidget.refreshDisplay(widget)
    else
        if tknInputFieldWidget.focusedWidget == widget then
            tknInputFieldWidget.focusedWidget = nil
        end
        input.imeEnabled = false
        widget.cursorVisible = false
        tknInputFieldWidget.refreshDisplay(widget)
    end
end

function tknInputFieldWidget.setText(widget, text)
    widget.text = text
    tknInputFieldWidget.refreshDisplay(widget)
    if widget.onValueChange then
        widget.onValueChange(widget, text)
    end
end

function tknInputFieldWidget.refreshDisplay(widget)
    local displayText
    if widget.isFocused then
        if widget.cursorVisible then
            displayText = widget.text .. "|"
        else
            displayText = widget.text
        end
    else
        if #widget.text > 0 then
            displayText = widget.text
        else
            displayText = widget.placeholder
        end
    end
    ui.setTextContent(widget.textNode, displayText)
end

function tknInputFieldWidget.update(frameCount)
    if tknInputFieldWidget.focusedWidget == nil then
        return
    end
    local widget = tknInputFieldWidget.focusedWidget

    -- Handle IME text input
    if #input.inputText > 0 then
        widget.text = widget.text .. input.inputText
        widget.cursorVisible = true
        widget.cursorTimer = 0
        if widget.onValueChange then
            widget.onValueChange(widget, widget.text)
        end
    end

    -- Handle backspace
    if input.getKeyState(input.keyCode.backspace) == input.inputState.up then
        if #widget.text > 0 then
            -- Remove last UTF-8 character
            local bytes = {string.byte(widget.text, 1, #widget.text)}
            local i = #bytes
            while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do
                i = i - 1
            end
            if i > 0 then
                widget.text = string.sub(widget.text, 1, i - 1)
            end
            widget.cursorVisible = true
            widget.cursorTimer = 0
            if widget.onValueChange then
                widget.onValueChange(widget, widget.text)
            end
        end
    end

    -- Handle enter: confirm and unfocus
    if input.getKeyState(input.keyCode.enter) == input.inputState.up then
        tknInputFieldWidget.setFocused(widget, false)
        return
    end

    -- Handle escape: cancel and unfocus
    if input.getKeyState(input.keyCode.escape) == input.inputState.up then
        tknInputFieldWidget.setFocused(widget, false)
        return
    end

    -- Cursor blink
    widget.cursorVisible = math.floor(frameCount / 30) % 2 == 0

    tknInputFieldWidget.refreshDisplay(widget)
end

return tknInputFieldWidget
