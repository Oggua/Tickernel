#version 450

#include "tickernel.glsl"

// Vertex attributes (pivot-centered rect)
layout(location = 0) in vec2 position;
layout(location = 1) in vec2 uv;

layout(location = 2) in mat3 model;
layout(location = 5) in uint color;
layout(location = 6) in float alphaThreshold;

layout(location = 0) out vec2 outUV;
layout(location = 1) out vec4 outColor;
layout(location = 2) out float outAlphaThreshold;

void main() {
    vec3 transformedPos = model * vec3(position, 1.0);
    gl_Position = vec4(transformedPos.xy, 0.0, 1.0);
    outUV = uv;
    outColor = unpackUnorm4x8(color);
    outAlphaThreshold = alphaThreshold;
}
