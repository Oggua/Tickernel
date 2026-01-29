require("vulkan")
local tkn = require("tkn")
local imagePipeline = {}

function imagePipeline.createPipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, assetsPath, pUIVertexInputLayout, pUIInstanceInputLayout)
    local imagePipelineSpvPaths = {assetsPath .. "/shaders/ui.vert.spv", assetsPath .. "/shaders/image.frag.spv"}
    local vkPipelineInputAssemblyStateCreateInfo = {
        topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    local vkPipelineDepthStencilStateCreateInfo = {
        depthTestEnable = false,
        depthWriteEnable = false,
        depthCompareOp = VK_COMPARE_OP_ALWAYS,
        depthBoundsTestEnable = false,
        stencilTestEnable = true,
        front = {
            failOp = VK_STENCIL_OP_KEEP,
            passOp = VK_STENCIL_OP_REPLACE,
            depthFailOp = VK_STENCIL_OP_KEEP,
            compareOp = VK_COMPARE_OP_EQUAL,
            compareMask = 0xFF,
            writeMask = 0x00,
            reference = 0,
        },
        back = {
            failOp = VK_STENCIL_OP_KEEP,
            passOp = VK_STENCIL_OP_REPLACE,
            depthFailOp = VK_STENCIL_OP_KEEP,
            compareOp = VK_COMPARE_OP_EQUAL,
            compareMask = 0xFF,
            writeMask = 0x00,
            reference = 0,
        },
        minDepthBounds = 0.0,
        maxDepthBounds = 1.0,
    }
    local vkPipelineColorBlendStateCreateInfo = {
        logicOpEnable = false,
        logicOp = VK_LOGIC_OP_COPY,
        pAttachments = {{
            blendEnable = true,
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
    local vkPipelineDynamicStateCreateInfo = {
        pDynamicStates = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR, VK_DYNAMIC_STATE_STENCIL_WRITE_MASK, VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK, VK_DYNAMIC_STATE_STENCIL_REFERENCE},
    }
    return tkn.tknCreatePipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, imagePipelineSpvPaths, pUIVertexInputLayout, pUIInstanceInputLayout, vkPipelineInputAssemblyStateCreateInfo, tkn.defaultVkPipelineViewportStateCreateInfo, tkn.defaultVkPipelineRasterizationStateCreateInfo, tkn.defaultVkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, vkPipelineDynamicStateCreateInfo)
end

function imagePipeline.destroyPipelinePtr(pTknGfxContext, pTknPipeline)
    tkn.tknDestroyPipelinePtr(pTknGfxContext, pTknPipeline)
end

return imagePipeline
