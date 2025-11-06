#version 450
#include "global.glsl"
#include "lighting.subpass.frag.glsl"

layout(location = 0) in vec2 in_uv;
layout(location = 0) out vec4 o_color;

void main() {
    float depth = subpassLoad(i_depth).x;
    vec4 clip = vec4(in_uv * 2.0 - 1.0, depth, 1.0);
    vec4 world_w = globalUniform.inv_view_proj * clip;
    vec3 position = world_w.xyz / world_w.w;

    vec3 normal = normalize((subpassLoad(i_normal).xyz - 0.5) * 2);
    vec4 albedo = subpassLoad(i_albedo);

    float ndl = max(dot(normal, -normalize(lightsUniform.directionalLight.direction)), 0.0);
    float halfLambert = ndl * 0.5 + 0.5;
    vec3 o_rgb = albedo.rgb * lightsUniform.directionalLight.color.rgb * lightsUniform.directionalLight.color.a * halfLambert;
    for(int i = 0; i < lightsUniform.pointLightCount; i++) {
        PointLight light = lightsUniform.pointLights[i];
        vec3 toLight = position - light.position;
        float distance = length(toLight);
        float attenuation = clamp(1.0 - distance / light.range, 0.0, 1.0);
        attenuation *= step(distance, light.range);

        vec3 lightDir = -normalize(toLight);
        float pointNdl = max(dot(normal, lightDir), 0.0);
        float pointHalfLambert = pointNdl * 0.5 + 0.5;

        o_rgb += albedo.rgb * light.color.rgb * light.color.a * pointHalfLambert * attenuation;
    }
    o_color = vec4(o_rgb, 1.0);
}