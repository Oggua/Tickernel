#include "tickernel.glsl"
layout(set = GLOBAL_DESCRIPTOR_SET, binding = 0) uniform GlobalUniform {
    mat4 view;
    mat4 proj;
    float pointSizeFactor;
    float time;
    int frameCount;
    float near;
    float far;
    float fov;
    int screenWidth;
    int screenHeight;
} globalUniform;

