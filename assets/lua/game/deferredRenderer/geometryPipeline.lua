local vulkan = require("vulkan")
local tkn = require("tkn")
local geometryPipeline = {}
function geometryPipeline.createPipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, assetsPath, pTknMeshVertexInputLayout, pInstanceVertexInputLayout)
    local geometryPipelineSpvPaths = {assetsPath .. "/shaders/opaqueGeometry.vert.spv", assetsPath .. "/shaders/opaqueGeometry.frag.spv"}
    local vkPipelineInputAssemblyStateCreateInfo = {
        topology = vulkan.VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
        primitiveRestartEnable = false,
    }

    local vkPipelineDepthStencilStateCreateInfo = {
        depthTestEnable = true,
        depthWriteEnable = true,
        depthCompareOp = vulkan.VK_COMPARE_OP_LESS,
        depthBoundsTestEnable = false,
        stencilTestEnable = false,
        minDepthBounds = 0.0,
        maxDepthBounds = 1.0,
    }
    local vkPipelineColorBlendStateCreateInfo = {
        logicOpEnable = false,
        logicOp = vulkan.VK_LOGIC_OP_COPY,
        pAttachments = {{
            blendEnable = true,
            srcColorBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
            dstColorBlendFactor = vulkan.VK_BLEND_FACTOR_ZERO,
            colorBlendOp = vulkan.VK_BLEND_OP_ADD,
            srcAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ZERO,
            alphaBlendOp = vulkan.VK_BLEND_OP_ADD,
            colorWriteMask = vulkan.VK_COLOR_COMPONENT_A_BIT | vulkan.VK_COLOR_COMPONENT_R_BIT | vulkan.VK_COLOR_COMPONENT_G_BIT | vulkan.VK_COLOR_COMPONENT_B_BIT,
        }, {
            blendEnable = true,
            srcColorBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
            dstColorBlendFactor = vulkan.VK_BLEND_FACTOR_ZERO,
            colorBlendOp = vulkan.VK_BLEND_OP_ADD,
            srcAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ZERO,
            alphaBlendOp = vulkan.VK_BLEND_OP_ADD,
            colorWriteMask = vulkan.VK_COLOR_COMPONENT_A_BIT | vulkan.VK_COLOR_COMPONENT_R_BIT | vulkan.VK_COLOR_COMPONENT_G_BIT | vulkan.VK_COLOR_COMPONENT_B_BIT,
        }},
        blendConstants = {0.0, 0.0, 0.0, 0.0},
    }

    return tkn.tknCreatePipelinePtr(pTknGfxContext, pTknRenderPass, subpassIndex, geometryPipelineSpvPaths, pTknMeshVertexInputLayout, pInstanceVertexInputLayout, vkPipelineInputAssemblyStateCreateInfo, tkn.defaultVkPipelineViewportStateCreateInfo, tkn.defaultVkPipelineRasterizationStateCreateInfo, tkn.defaultVkPipelineMultisampleStateCreateInfo, vkPipelineDepthStencilStateCreateInfo, vkPipelineColorBlendStateCreateInfo, tkn.defaultVkPipelineDynamicStateCreateInfo)
end

function geometryPipeline.destroyPipelinePtr(pTknGfxContext, pTknPipeline)
    tkn.tknDestroyPipelinePtr(pTknGfxContext, pTknPipeline)
end

return geometryPipeline
