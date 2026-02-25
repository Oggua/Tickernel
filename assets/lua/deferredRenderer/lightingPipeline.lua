local vulkan = require("vulkan")
local tkn = require("tkn")
local lightingPipeline = {}
function lightingPipeline.createPipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, assetsPath)
    local lightingPipelineSpvPaths = {assetsPath .. "/shaders/opaqueLighting.vert.spv", assetsPath .. "/shaders/opaqueLighting.frag.spv"}

    local vkPipelineInputAssemblyStateCreateInfo = {
        topology = vulkan.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    local vkPipelineDepthStencilStateCreateInfo = {
        depthTestEnable = false,
        depthWriteEnable = false,
        depthCompareOp = vulkan.VK_COMPARE_OP_ALWAYS,
        depthBoundsTestEnable = false,
        stencilTestEnable = false,
        minDepthBounds = 0.0,
        maxDepthBounds = 1.0,
    }

    local vkPipelineColorBlendStateCreateInfo = {
        logicOpEnable = false,
        logicOp = vulkan.VK_LOGIC_OP_COPY,
        pAttachments = {{
            blendEnable = false,
            srcColorBlendFactor = vulkan.VK_BLEND_FACTOR_SRC_ALPHA,
            dstColorBlendFactor = vulkan.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            colorBlendOp = vulkan.VK_BLEND_OP_ADD,
            srcAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ZERO,
            alphaBlendOp = vulkan.VK_BLEND_OP_ADD,
            colorWriteMask = vulkan.VK_COLOR_COMPONENT_A_BIT | vulkan.VK_COLOR_COMPONENT_R_BIT | vulkan.VK_COLOR_COMPONENT_G_BIT | vulkan.VK_COLOR_COMPONENT_B_BIT,
        }},
        blendConstants = {0.0, 0.0, 0.0, 0.0},
    }

    return tkn.tknCreatePipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, lightingPipelineSpvPaths, nil, nil, vkPipelineInputAssemblyStateCreateInfo, tkn.defaultVkPipelineViewportStateCreateInfo, tkn.defaultVkPipelineRasterizationStateCreateInfo, tkn.defaultVkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, tkn.defaultVkPipelineDynamicStateCreateInfo)
end

function lightingPipeline.destroyPipelinePtr(pTknGfxContext, pTknRenderPass)
    tkn.tknDestroyPipelinePtr(pTknGfxContext, pTknRenderPass)
end

return lightingPipeline
