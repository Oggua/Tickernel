#include "tickernel.glsl"

layout(set = GLOBAL_DESCRIPTOR_SET, binding = 0) uniform GlobalUniform {
    mat4 view;
    mat4 proj;
    float near;
    float far;
    float fov;

    float time;
    int frameCount;
    int screenWidth;
    int screenHeight;
} globalUniform;
