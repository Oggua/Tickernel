local vulkan = require("vulkan")
local tkn = require("tkn")
local textPipeline = {}

function textPipeline.createPipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, assetsPath, pUIVertexInputLayout, pUIInstanceInputLayout)
    local textPipelineSpvPaths = {assetsPath .. "/shaders/ui.vert.spv", assetsPath .. "/shaders/text.frag.spv"}
    local vkPipelineInputAssemblyStateCreateInfo = {
        topology = vulkan.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    local vkPipelineDepthStencilStateCreateInfo = {
        depthTestEnable = false,
        depthWriteEnable = false,
        depthCompareOp = vulkan.VK_COMPARE_OP_ALWAYS,
        depthBoundsTestEnable = false,
        stencilTestEnable = true,
        front = {
            failOp = vulkan.VK_STENCIL_OP_KEEP,
            passOp = vulkan.VK_STENCIL_OP_REPLACE,
            depthFailOp = vulkan.VK_STENCIL_OP_KEEP,
            compareOp = vulkan.VK_COMPARE_OP_EQUAL,
            compareMask = 0xFF,
            writeMask = 0x00,
            reference = 0,
        },
        back = {
            failOp = vulkan.VK_STENCIL_OP_KEEP,
            passOp = vulkan.VK_STENCIL_OP_REPLACE,
            depthFailOp = vulkan.VK_STENCIL_OP_KEEP,
            compareOp = vulkan.VK_COMPARE_OP_EQUAL,
            compareMask = 0xFF,
            writeMask = 0x00,
            reference = 0,
        },
        minDepthBounds = 0.0,
        maxDepthBounds = 1.0,
    }
    local vkPipelineColorBlendStateCreateInfo = {
        logicOpEnable = false,
        logicOp = vulkan.VK_LOGIC_OP_COPY,
        pAttachments = {{
            blendEnable = true,
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
    local vkPipelineDynamicStateCreateInfo = {
        pDynamicStates = {vulkan.VK_DYNAMIC_STATE_VIEWPORT, vulkan.VK_DYNAMIC_STATE_SCISSOR, vulkan.VK_DYNAMIC_STATE_STENCIL_WRITE_MASK, vulkan.VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK, vulkan.VK_DYNAMIC_STATE_STENCIL_REFERENCE},
    }
    return tkn.tknCreatePipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, textPipelineSpvPaths, pUIVertexInputLayout, pUIInstanceInputLayout, vkPipelineInputAssemblyStateCreateInfo, tkn.defaultVkPipelineViewportStateCreateInfo, tkn.defaultVkPipelineRasterizationStateCreateInfo, tkn.defaultVkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, vkPipelineDynamicStateCreateInfo)
end

function textPipeline.destroyPipelinePtr(pTknGfxContext, pTknPipeline)
    tkn.tknDestroyPipelinePtr(pTknGfxContext, pTknPipeline)
end

return textPipeline
