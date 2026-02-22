#version 450
#include "global.glsl"
#include "lighting.subpass.glsl"

layout(location = 0) in vec2 in_uv;
layout(location = 0) out vec4 o_color;

void main() {
    float depth = subpassLoad(i_depth).x;
    vec4 clip = vec4(in_uv * 2.0 - 1.0, depth, 1.0);
    mat4 invViewProj = inverse(globalUniform.proj * globalUniform.view);
    mat4 invView = inverse(globalUniform.view);
    vec4 world_w = invViewProj * clip;
    vec3 position = world_w.xyz / world_w.w;
    vec3 cameraPosition = invView[3].xyz;

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

    const vec3 fogColor = vec3(0.13, 0.28, 0.36);
    float distanceToCamera = length(position - cameraPosition);
    float fogFactor = smoothstep(globalUniform.near, globalUniform.far, distanceToCamera);
    o_rgb = mix(o_rgb, fogColor, fogFactor);
    o_color = vec4(o_rgb, 1.0);
}