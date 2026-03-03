#version 450

layout(location = 0) in vec4 inputAlbedo;
layout(location = 1) in vec4 inputNormal; // xyz = encoded normal, w = metallic
layout(location = 0) out vec4 outputAlbedo;
layout(location = 1) out vec4 outputNormal;

void main(void) {
    outputAlbedo = inputAlbedo;   // rgb = albedo, a = emissive
    outputNormal = inputNormal;   // already encoded in opaqueGeometry.vert
}
