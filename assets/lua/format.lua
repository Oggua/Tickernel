local tkn = require("tkn")
local format = {}

function format.createLayouts(pGfxContext)
    format.voxelVertexFormat = {{
        name = "position",
        type = tkn.type.float,
        count = 3,
    }, {
        name = "color",
        type = tkn.type.uint32,
        count = 1,
    }, {
        name = "normal",
        type = tkn.type.uint32,
        count = 1,
    }}

    format.instanceFormat = {{
        name = "model",
        type = tkn.type.float,
        count = 16,
    }}

    format.globalUniformBufferFormat = {{
        name = "view",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "proj",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "inv_view_proj",
        type = tkn.type.float,
        count = 16,
    }, {
        name = "pointSizeFactor",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "time",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "frameCount",
        type = tkn.type.int32,
        count = 1,
    }, {
        name = "near",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "far",
        type = tkn.type.float,
        count = 1,
    }, {
        name = "fov",
        type = tkn.type.float,
        count = 1,
    }}

    format.lightsUniformBufferFormat = {{
        name = "directionalLightColor",
        type = tkn.type.float,
        count = 4,
    }, {
        name = "directionalLightDirection",
        type = tkn.type.float,
        count = 4,
    }, {
        -- PointLight array: 128 lights × (vec4 color + vec3 position + float range) = 128 × 8 floats
        name = "pointLights",
        type = tkn.type.float,
        count = 128 * 8,
    }, {
        name = "pointLightCount",
        type = tkn.type.int32,
        count = 1,
    }}
    format.voxelVertexFormat.pVertexInputLayout = tkn.createVertexInputLayoutPtr(pGfxContext, format.voxelVertexFormat)
    format.instanceFormat.pVertexInputLayout = tkn.createVertexInputLayoutPtr(pGfxContext, format.instanceFormat)
end

function format.destroyLayouts(pGfxContext)
    print("format.destroyLayouts")
    tkn.destroyVertexInputLayoutPtr(pGfxContext, format.instanceFormat.pVertexInputLayout)
    tkn.destroyVertexInputLayoutPtr(pGfxContext, format.voxelVertexFormat.pVertexInputLayout)
    format.instanceFormat.pVertexInputLayout = nil
    format.voxelVertexFormat.pVertexInputLayout = nil
end

return format
