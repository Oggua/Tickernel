#version 450

#include "tickernel.glsl"

layout(location = 0) in vec2 uv;
layout(location = 1) in vec4 color;
layout(location = 2) in float alphaThreshold;

layout(location = 0) out vec4 outColor;

layout(set = PIPELINE_DESCRIPTOR_SET, binding = 0) uniform sampler2D uiTexture;

void main() {
    vec4 texColor = texture(uiTexture, uv);
    outColor = texColor * color;
    if(outColor.a < alphaThreshold) {
        discard;
    }
}
