local input = require("input")
local interactableNode = {}

function interactableNode.setupNode(pTknGfxContext, processInputFunction, node)
    node.type = "interactableNode"
    node.transform.color = nil
    node.processInputFunction = processInputFunction
end

function interactableNode.teardownNode(pTknGfxContext, node)
    node.type = nil
    node.processInputFunction = nil
    node.transform.color = nil
end

return interactableNode
