local input = require("input")
local buttonComponent = {}

function buttonComponent.setup()
    buttonComponent.pool = {}
end

function buttonComponent.teardown(pTknGfxContext)
    buttonComponent.pool = nil
end

function buttonComponent.createComponent(pTknGfxContext, processInput, node)
    local component = nil
    if #buttonComponent.pool > 0 then
        component = table.remove(buttonComponent.pool)
        component.overrideColor = nil
        component.processInput = processInput
        component.node = node
    else
        component = {
            type = "Button",
            processInput = processInput,
            overrideColor = nil,
            node = node,
        }
    end
    return component
end

function buttonComponent.destroyComponent(pTknGfxContext, component)
    component.processInput = nil
    component.overrideColor = nil
    component.node = nil
    table.insert(buttonComponent.pool, component)
end

return buttonComponent
