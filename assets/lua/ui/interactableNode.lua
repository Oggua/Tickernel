local input = require("input")
local interactableNode = {}

function interactableNode.setupNode(pTknGfxContext, processInput, node)
    node.type = "interactableNode"
    node.transform.color = nil
    node.processInput = processInput
end

function interactableNode.teardownNode(pTknGfxContext, node)
    node.type = nil
    node.processInput = nil
    node.transform.color = nil
end

return interactableNode
