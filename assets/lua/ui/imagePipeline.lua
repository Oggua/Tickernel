require("vulkan")
local tkn = require("tkn")
local imagePipeline = {}

function imagePipeline.createPipelinePtr(pGfxContext, pRenderPass, subpassIndex, assetsPath, pUIVertexInputLayout, pUIInstanceInputLayout)
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
        stencilTestEnable = false,
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

    return tkn.tknCreatePipelinePtr(pGfxContext, pRenderPass, subpassIndex, imagePipelineSpvPaths, pUIVertexInputLayout, pUIInstanceInputLayout, vkPipelineInputAssemblyStateCreateInfo, tkn.defaultVkPipelineViewportStateCreateInfo, tkn.defaultVkPipelineRasterizationStateCreateInfo, tkn.defaultVkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, tkn.defaultVkPipelineDynamicStateCreateInfo)
end

function imagePipeline.destroyPipelinePtr(pGfxContext, pPipeline)
    tkn.tknDestroyPipelinePtr(pGfxContext, pPipeline)
end

return imagePipeline
