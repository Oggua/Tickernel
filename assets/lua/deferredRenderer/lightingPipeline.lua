require("vulkan")
local tkn = require("tkn")
local lightingPipeline = {}
function lightingPipeline.createPipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, assetsPath)
    local lightingPipelineSpvPaths = {assetsPath .. "/shaders/opaqueLighting.vert.spv", assetsPath .. "/shaders/opaqueLighting.frag.spv"}

    local vkPipelineInputAssemblyStateCreateInfo = {
        topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    local vkPipelineDepthStencilStateCreateInfo = {
        depthTestEnable = false,
        depthWriteEnable = false,
        depthCompareOp = VK_COMPARE_OP_ALWAYS,
        depthBoundsTestEnable = false,
        stencilTestEnable = false,
        minDepthBounds = 0.0,
        maxDepthBounds = 1.0,
    }

    local vkPipelineColorBlendStateCreateInfo = {
        logicOpEnable = false,
        logicOp = VK_LOGIC_OP_COPY,
        pAttachments = {{
            blendEnable = false,
            srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA,
            dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            colorBlendOp = VK_BLEND_OP_ADD,
            srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
            alphaBlendOp = VK_BLEND_OP_ADD,
            colorWriteMask = VK_COLOR_COMPONENT_A_BIT | VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT,
        }},
        blendConstants = {0.0, 0.0, 0.0, 0.0},
    }

    return tkn.tknCreatePipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, lightingPipelineSpvPaths, nil, nil, vkPipelineInputAssemblyStateCreateInfo, tkn.defaultVkPipelineViewportStateCreateInfo, tkn.defaultVkPipelineRasterizationStateCreateInfo, tkn.defaultVkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, tkn.defaultVkPipelineDynamicStateCreateInfo)
end

function lightingPipeline.destroyPipelinePtr(pTknGfxContext, pTknRenderPass)
    tkn.tknDestroyPipelinePtr(pTknGfxContext, pTknRenderPass)
end

return lightingPipeline
