local input = require("input")
local interactableComponent = {}

function interactableComponent.setup()
    interactableComponent.pool = {}
end

function interactableComponent.teardown(pTknGfxContext)
    interactableComponent.pool = nil
end

function interactableComponent.createComponent(pTknGfxContext, processInput, node)
    local component = nil
    if #interactableComponent.pool > 0 then
        component = table.remove(interactableComponent.pool)
        component.overrideColor = nil
        component.processInput = processInput
        component.node = node
    else
        component = {
            type = "interactable",
            processInput = processInput,
            overrideColor = nil,
            node = node,
        }
    end
    return component
end

function interactableComponent.destroyComponent(pTknGfxContext, component)
    component.processInput = nil
    component.overrideColor = nil
    component.node = nil
    table.insert(interactableComponent.pool, component)
end

return interactableComponent
