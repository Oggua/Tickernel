#version 450
#include "global.glsl"
#include "lighting.subpass.glsl"

layout(location = 0) in vec2 inputUv;
layout(location = 0) out vec4 outputColor;

const float PI = 3.14159265359;
const float dielectricF0 = 0.04;
const float ambientDiffuseStrength = 0.03;
const float ambientSpecularStrength = 0.03;
const float emissiveStrength = 2.0;

// GGX 法线分布函数
float dGgx(float ndotH, float a2) {
    float d = ndotH * ndotH * (a2 - 1.0) + 1.0;
    return a2 / (PI * d * d + 0.0001);
}

// Schlick 菲涅尔
vec3 fSchlick(float hdotV, vec3 f0) {
    return f0 + (1.0 - f0) * pow(clamp(1.0 - hdotV, 0.0, 1.0), 5.0);
}

// Smith-Schlick 几何遮蔽
float gSmith(float ndotV, float ndotL, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    float gv = ndotV / (ndotV * (1.0 - k) + k);
    float gl = ndotL / (ndotL * (1.0 - k) + k);
    return gv * gl;
}

// Cook-Torrance BRDF，返回单光源贡献
vec3 pbr(vec3 n, vec3 v, vec3 l, vec3 albedo, float roughness, float metallic, vec3 lightColor, float lightIntensity) {
    vec3 h = normalize(v + l);
    float ndotL = max(dot(n, l), 0.0);
    float ndotV = max(dot(n, v), 0.001);
    float ndotH = max(dot(n, h), 0.0);
    float hdotV = max(dot(h, v), 0.0);

    roughness = roughness * roughness * roughness * roughness;
    // 非金属 F0=dielectricF0，金属 F0=albedo
    vec3 f0 = mix(vec3(dielectricF0), albedo, metallic);

    float d = dGgx(ndotH, roughness);
    vec3 f = fSchlick(hdotV, f0);
    float g = gSmith(ndotV, ndotL, roughness);

    vec3 specular = (d * f * g) / (4.0 * ndotV * ndotL + 0.0001);
    // 金属无漫反射
    vec3 kd = (vec3(1.0) - f) * (1.0 - metallic);
    // vec3 diffuse = kd * albedo;
    vec3 diffuse = kd * albedo / PI;

    return (diffuse + specular) * lightColor * lightIntensity * ndotL;
}

void main() {
    float depth = subpassLoad(inputDepth).x;
    vec4 clip = vec4(inputUv * 2.0 - 1.0, depth, 1.0);
    mat4 invViewProj = inverse(globalUniform.proj * globalUniform.view);
    mat4 invView = inverse(globalUniform.view);
    vec4 world = invViewProj * clip;
    vec3 position = world.xyz / world.w;
    vec3 cameraPosition = invView[3].xyz;

    vec4 normalData = subpassLoad(inputNormal);
    vec3 normal = normalize((normalData.xyz - 0.5) * 2.0);
    // Decode normal.a: low 4 bits = roughness, high 4 bits = metallic
    uint pbrByte = uint(round(normalData.w * 255.0));
    float roughness = float(pbrByte & 0xFu) / 15.0;
    float metallic = float((pbrByte >> 4u) & 0xFu) / 15.0;
    vec4 albedoData = subpassLoad(inputAlbedo);
    vec3 albedo = albedoData.rgb;
    float emissive = albedoData.a;

    vec3 v = normalize(cameraPosition - position);

    // 方向光
    vec3 dirL = -normalize(lightsUniform.directionalLight.direction);
    vec3 outputRgb = pbr(normal, v, dirL, albedo, roughness, metallic, lightsUniform.directionalLight.color.rgb, lightsUniform.directionalLight.color.a);

    // 点光源
    for(int i = 0; i < lightsUniform.pointLightCount; i++) {
        PointLight pointLight = lightsUniform.pointLights[i];
        vec3 toLight = pointLight.position - position;
        float distanceToLight = length(toLight);
        float attenuation = clamp(1.0 - distanceToLight / pointLight.range, 0.0, 1.0);
        attenuation *= step(distanceToLight, pointLight.range);

        vec3 pointL = normalize(toLight);
        outputRgb += pbr(normal, v, pointL, albedo, roughness, metallic, pointLight.color.rgb, pointLight.color.a) * attenuation;
    }

    // 环境光：非金属用 albedo，金属用 F0（albedo 染色的反射）
    vec3 f0Ambient = mix(vec3(dielectricF0), albedo, metallic);
    vec3 ambientDiffuse = vec3(ambientDiffuseStrength) * albedo * (1.0 - metallic);
    vec3 ambientSpecular = vec3(ambientSpecularStrength) * f0Ambient * metallic;
    outputRgb += ambientDiffuse + ambientSpecular;

    // 自发光：emissive=1.0 时亮度 = albedo * 5
    outputRgb += albedo * emissive * emissiveStrength;

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
