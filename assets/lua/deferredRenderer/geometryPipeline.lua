require("vulkan")
local tkn = require("tkn")
local geometryPipeline = {}
function geometryPipeline.createPipelinePtr(pGfxContext, pRenderPass, subpassIndex, assetsPath, pMeshVertexInputLayout, pInstanceVertexInputLayout)
    local geometryPipelineSpvPaths = {assetsPath .. "/shaders/opaqueGeometry.vert.spv", assetsPath .. "/shaders/opaqueGeometry.frag.spv"}
    local vkPipelineInputAssemblyStateCreateInfo = {
        topology = VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
        primitiveRestartEnable = false,
    }

    local vkPipelineDepthStencilStateCreateInfo = {
        depthTestEnable = true,
        depthWriteEnable = true,
        depthCompareOp = VK_COMPARE_OP_LESS,
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
            srcColorBlendFactor = VK_BLEND_FACTOR_ONE,
            dstColorBlendFactor = VK_BLEND_FACTOR_ZERO,
            colorBlendOp = VK_BLEND_OP_ADD,
            srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
            alphaBlendOp = VK_BLEND_OP_ADD,
            colorWriteMask = VK_COLOR_COMPONENT_A_BIT | VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT,
        }, {
            blendEnable = true,
            srcColorBlendFactor = VK_BLEND_FACTOR_ONE,
            dstColorBlendFactor = VK_BLEND_FACTOR_ZERO,
            colorBlendOp = VK_BLEND_OP_ADD,
            srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
            alphaBlendOp = VK_BLEND_OP_ADD,
            colorWriteMask = VK_COLOR_COMPONENT_A_BIT | VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT,
        }},
        blendConstants = {0.0, 0.0, 0.0, 0.0},
    }

    return tkn.tknCreatePipelinePtr(pGfxContext, pRenderPass, subpassIndex, geometryPipelineSpvPaths, pMeshVertexInputLayout, pInstanceVertexInputLayout, vkPipelineInputAssemblyStateCreateInfo, tkn.defaultVkPipelineViewportStateCreateInfo, tkn.defaultVkPipelineRasterizationStateCreateInfo, tkn.defaultVkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, tkn.defaultVkPipelineDynamicStateCreateInfo)
end

function geometryPipeline.destroyPipelinePtr(pGfxContext, pPipeline)
    tkn.tknDestroyPipelinePtr(pGfxContext, pPipeline)
end

return geometryPipeline
