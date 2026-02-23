
#version 450
#include "global.glsl"
#include "geometry.subpass.glsl"

layout(location = 0) in vec3 position;
layout(location = 1) in uint color;
layout(location = 2) in uint normal;
layout(location = 3) in mat4 model;

layout(location = 0) out vec4 outputAlbedo;
layout(location = 1) out vec3 outputNormal;

void main(void) {
    vec4 unpackedColor = unpackUnorm4x8(color);

    const vec3 normalTable[26] = vec3[26](
        // 6 faces
    vec3(-1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, -1.0), vec3(0.0, 0.0, 1.0),
        // 12 edges
    vec3(-0.7071, -0.7071, 0.0), vec3(-0.7071, 0.7071, 0.0), vec3(0.7071, -0.7071, 0.0), vec3(0.7071, 0.7071, 0.0), vec3(-0.7071, 0.0, -0.7071), vec3(-0.7071, 0.0, 0.7071), vec3(0.7071, 0.0, -0.7071), vec3(0.7071, 0.0, 0.7071), vec3(0.0, -0.7071, -0.7071), vec3(0.0, -0.7071, 0.7071), vec3(0.0, 0.7071, -0.7071), vec3(0.0, 0.7071, 0.7071),
        // 8 corners
    vec3(-0.5774, -0.5774, -0.5774), vec3(-0.5774, -0.5774, 0.5774), vec3(-0.5774, 0.5774, -0.5774), vec3(-0.5774, 0.5774, 0.5774), vec3(0.5774, -0.5774, -0.5774), vec3(0.5774, -0.5774, 0.5774), vec3(0.5774, 0.5774, -0.5774), vec3(0.5774, 0.5774, 0.5774));

    vec3 lightDirection = normalize(vec3(0.0, 0.0, 1.0));
    uint normalMask = normal & 0x3FFFFFFu;

    float maxDotProduct = -1.0;
    vec3 bestNormal = vec3(0.0, 0.0, 1.0); // 默认

    for(int i = 0; i < 26; i++) {
        uint bitSet = (normalMask >> uint(i)) & 1u;
        if(bitSet == 0u)
            continue;
        vec3 worldNormal = normalize(mat3(model) * normalTable[i]);
        float dotProduct = dot(worldNormal, lightDirection);
        if(dotProduct > maxDotProduct) {
            maxDotProduct = dotProduct;
            bestNormal = worldNormal;
        }
    }

    vec4 worldPosition = model * vec4(position, 1);
    vec4 viewPosition = globalUniform.view * worldPosition;
    gl_Position = globalUniform.proj * viewPosition;

    // // Scale point size for oblique surfaces: when the face is viewed at a steep angle,
    // // adjacent voxels at different depths create gaps. Compensate by 1/cos(angle),
    // // plus a perspective correction: at wider FOV and closer depth, oblique voxels
    // // at different depths diverge more (e.g. at FOV 90° and z=1, each unit depth doubles pixels).
    // vec3 viewSpaceNormal = normalize(mat3(globalUniform.view) * bestNormal);
    // float cosAngle = abs(viewSpaceNormal.z); // dot with -Z (camera forward in view space)
    // float sinAngle = sqrt(1.0 - cosAngle * cosAngle);
    // float perspectiveGap = sinAngle / (-viewPosition.z); // relative depth spread per voxel
    // float tanHalfFov = 1.0 / globalUniform.proj[1][1];  // derive tan(FOV/2) from projection matrix
    // float obliqueFactor = (1.0 + perspectiveGap * tanHalfFov) / max(cosAngle, 0.25); // clamp to max 4x base

    gl_PointSize = 1.0 / -viewPosition.z * geometryUniform.pointSize;
    outputNormal = bestNormal;
    outputAlbedo = unpackedColor;
}
