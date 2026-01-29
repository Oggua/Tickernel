#version 450

#include "tickernel.glsl"

layout(location = 0) in vec2 uv;
layout(location = 1) in vec4 color;
layout(location = 2) in float alphaThreshold;

layout(location = 0) out vec4 outColor;

layout(set = PIPELINE_DESCRIPTOR_SET, binding = 0) uniform sampler2D fontTexture;

void main() {
    // R8 format: read R channel as alpha
    float alpha = texture(fontTexture, uv).r;

    outColor = vec4(color.rgb, color.a * alpha);
    if(outColor.a < alphaThreshold) {
        discard;
    }
}
