#include "tickernel.glsl"

layout(set = SUBPASS_DESCRIPTOR_SET, binding = 0) uniform GeometryUniform {
    float pointSize;
} geometryUniform;