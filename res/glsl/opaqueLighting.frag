#version 450
#include "global.glsl"
#include "lighting.subpass.glsl"

layout(location = 0) in vec2 inputUv;
layout(location = 0) out vec4 outputColor;

void main() {
    float depth = subpassLoad(i_depth).x;
    vec4 clip = vec4(inputUv * 2.0 - 1.0, depth, 1.0);
    mat4 invViewProj = inverse(globalUniform.proj * globalUniform.view);
    mat4 invView = inverse(globalUniform.view);
    vec4 world = invViewProj * clip;
    vec3 position = world.xyz / world.w;
    vec3 cameraPosition = invView[3].xyz;

    vec3 normal = normalize((subpassLoad(i_normal).xyz - 0.5) * 2.0);
    vec3 albedo = subpassLoad(i_albedo).rgb;
    float roughness = subpassLoad(i_albedo).a;
    vec3 v = normalize(cameraPosition - position);

    float shininess = mix(256.0, 1.0, roughness);
    vec3 dirL = -normalize(lightsUniform.directionalLight.direction);
    float ndl = max(dot(normal, dirL), 0.0);
    float halfLambert = ndl * 0.5 + 0.5;
    vec3 h = normalize(dirL + v);
    float spec = pow(max(dot(normal, h), 0.0), shininess) * (1.0 - roughness);
    vec3 outputRgb = (albedo * halfLambert + spec) * lightsUniform.directionalLight.color.rgb * lightsUniform.directionalLight.color.a;

    for(int i = 0; i < lightsUniform.pointLightCount; i++) {
        PointLight pointLight = lightsUniform.pointLights[i];
        vec3 toLight = pointLight.position - position;
        float distanceToLight = length(toLight);
        float attenuation = clamp(1.0 - distanceToLight / pointLight.range, 0.0, 1.0);
        attenuation *= step(distanceToLight, pointLight.range);

        vec3 pointL = normalize(toLight);
        float pointNdl = max(dot(normal, pointL), 0.0);
        float pointHalfLambert = pointNdl * 0.5 + 0.5;
        vec3 pointH = normalize(pointL + v);
        float pointSpec = pow(max(dot(normal, pointH), 0.0), shininess) * (1.0 - roughness);

        outputRgb += (albedo * pointHalfLambert + pointSpec) * pointLight.color.rgb * pointLight.color.a * attenuation;
    }

    const vec3 fogColor = vec3(0.13, 0.28, 0.36);
    float distanceToCamera = length(position - cameraPosition);
    float fogFactor = smoothstep(globalUniform.near, globalUniform.far, distanceToCamera);
    outputRgb = mix(outputRgb, fogColor, fogFactor);

    // Grid lines: ray-plane intersection with z=0，透过实体，颜色随距原点变化
    vec3 rayDir = normalize(position - cameraPosition);
    if(abs(rayDir.z) > 0.001) {
        float t = -cameraPosition.z / rayDir.z;
        if(t > 0.0) {
            vec3 gridPos = cameraPosition + t * rayDir;
            float gx = fract(gridPos.x);
            float gy = fract(gridPos.y);
            float lx = min(gx, 1.0 - gx);
            float ly = min(gy, 1.0 - gy);
            float lineWidth = 0.03;
            if(lx < lineWidth || ly < lineWidth) {
                // 原点白色，X轴→红，Y轴→绿，距离越远越暗
                float dist = length(gridPos.xy);
                float brightness = exp(-dist * 0.05); // 距离衰减
                vec3 axisColor = vec3(max(gridPos.x / (dist + 0.001), 0.0), // +X = R
                max(gridPos.y / (dist + 0.001), 0.0), // +Y = G
                1.0);
                vec3 gridColor = mix(axisColor, vec3(1.0), brightness) * brightness;

                float gridFog = smoothstep(globalUniform.near, globalUniform.far, t);
                float alpha = 0.7 * (1.0 - gridFog);
                outputRgb = mix(outputRgb, gridColor, alpha);
            }
        }
    }

    outputColor = vec4(outputRgb, 1.0);
}
