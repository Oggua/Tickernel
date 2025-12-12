#pragma once
#include <stdbool.h>
#include "vulkan/vulkan.h"

#define TKN_ARRAY_COUNT(array) (NULL == array) ? 0 : (sizeof(array) / sizeof(array[0]))

typedef struct TknGfxContext TknGfxContext;
typedef struct TknRenderPass TknRenderPass;
typedef struct TknVertexInputLayout TknVertexInputLayout;
typedef struct TknPipeline TknPipeline;
typedef struct TknMaterial TknMaterial;
typedef struct TknInstance TknInstance;
typedef struct TknMesh TknMesh;
typedef struct TknDrawCall TknDrawCall;

typedef struct TknAttachment TknAttachment;
typedef struct TknImage TknImage;
typedef struct TknSampler TknSampler;
typedef struct TknUniformBuffer TknUniformBuffer;

typedef struct
{
    TknSampler *pTknSampler;
} TknSamplerBinding;

typedef struct
{
    TknSampler *pTknSampler;
    TknImage *pTknImage;
} TknCombinedImageSamplerBinding;

typedef struct
{
    TknUniformBuffer *pTknUniformBuffer;
} TknUniformBufferBinding;

typedef union
{
    TknSamplerBinding tknSamplerBinding;
    TknCombinedImageSamplerBinding tknCombinedImageSamplerBinding;
    // VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE = 2,
    // VK_DESCRIPTOR_TYPE_STORAGE_IMAGE = 3,
    // VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER = 4,
    // VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER = 5,
    // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6,
    TknUniformBufferBinding tknUniformBufferBinding;
    // VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7,
    // VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC = 8,
    // VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC = 9,
} TknInputBindingUnion;

typedef struct
{
    VkDescriptorType vkDescriptorType;
    TknInputBindingUnion tknInputBindingUnion;
    uint32_t binding;
} TknInputBinding;

// ASTC image data
typedef struct
{
    uint32_t width;    // TknImage width
    uint32_t height;   // TknImage height
    VkFormat vkFormat; // Corresponding Vulkan ASTC format
    uint32_t size; // Compressed data size
    char *data;        // Compressed ASTC data
} TknASTCImage;

TknASTCImage *createASTCFromMemory(const char *buffer, size_t bufferSize);
void destroyASTCImage(TknASTCImage *tknAstcImage);

VkFormat getSupportedFormat(TknGfxContext *pTknGfxContext, uint32_t candidateCount, VkFormat *candidates, VkImageTiling tiling, VkFormatFeatureFlags features);

TknGfxContext *createGfxContextPtr(int targetSwapchainImageCount, VkSurfaceFormatKHR targetVkSurfaceFormat, VkPresentModeKHR targetVkPresentMode, VkInstance vkInstance, VkSurfaceKHR vkSurface, VkExtent2D swapchainExtent, uint32_t spvPathCount, const char **spvPaths);
void waitGfxRenderFence(TknGfxContext *pTknGfxContext);
void waitGfxDeviceIdle(TknGfxContext *pTknGfxContext);
void updateGfxContextPtr(TknGfxContext *pTknGfxContext, VkExtent2D swapchainExtent);
void destroyGfxContextPtr(TknGfxContext *pTknGfxContext);

TknAttachment *createDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, float scaler);
void destroyDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment);
TknAttachment *createFixedAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, uint32_t width, uint32_t height);
void destroyFixedAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment);
TknAttachment *getSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext);

TknVertexInputLayout *createVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, uint32_t attributeCount, const char **names, uint32_t *sizes);
void destroyVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout);

TknRenderPass *createRenderPassPtr(TknGfxContext *pTknGfxContext, uint32_t attachmentCount, VkAttachmentDescription *vkAttachmentDescriptions, TknAttachment **inputAttachmentPtrs, VkClearValue *vkClearValues, uint32_t subpassCount, VkSubpassDescription *vkSubpassDescriptions, uint32_t *spvPathCounts, const char ***spvPathsArray, uint32_t vkSubpassDependencyCount, VkSubpassDependency *vkSubpassDependencies, uint32_t renderPassIndex);
void destroyRenderPassPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);

TknPipeline *createPipelinePtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t spvPathCount, const char **spvPaths, TknVertexInputLayout *pTknMeshVertexInputLayout, TknVertexInputLayout *pTknInstanceVertexInputLayout, VkPipelineInputAssemblyStateCreateInfo vkPipelineInputAssemblyStateCreateInfo, VkPipelineViewportStateCreateInfo vkPipelineViewportStateCreateInfo, VkPipelineRasterizationStateCreateInfo vkPipelineRasterizationStateCreateInfo, VkPipelineMultisampleStateCreateInfo vkPipelineMultisampleStateCreateInfo, VkPipelineDepthStencilStateCreateInfo vkPipelineDepthStencilStateCreateInfo, VkPipelineColorBlendStateCreateInfo vkPipelineColorBlendStateCreateInfo, VkPipelineDynamicStateCreateInfo vkPipelineDynamicStateCreateInfo);
void destroyPipelinePtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline);

TknDrawCall *createDrawCallPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline, TknMaterial *pTknMaterial, TknMesh *pTknMesh, TknInstance *pTknInstance);
void destroyDrawCallPtr(TknGfxContext *pTknGfxContext, TknDrawCall *pTknDrawCall);
void insertDrawCallPtr(TknDrawCall *pTknDrawCall, uint32_t index);
void removeDrawCallPtr(TknDrawCall *pTknDrawCall);
void removeDrawCallAtIndex(TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t index);
TknDrawCall *getDrawCallAtIndex(TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t index);
uint32_t getDrawCallCount(TknRenderPass *pTknRenderPass, uint32_t subpassIndex);

TknImage *createImagePtr(TknGfxContext *pTknGfxContext, VkExtent3D vkExtent3D, VkFormat vkFormat, VkImageTiling vkImageTiling, VkImageUsageFlags vkImageUsageFlags, VkMemoryPropertyFlags vkMemoryPropertyFlags, VkImageAspectFlags vkImageAspectFlags, void *data, VkDeviceSize dataSize);
void destroyImagePtr(TknGfxContext *pTknGfxContext, TknImage *pTknImage);
void updateImagePtr(TknGfxContext *pTknGfxContext, TknImage *pTknImage, uint32_t count, void **datas, VkOffset3D *imageOffsets, VkExtent3D *imageExtents, VkDeviceSize *dataSizes);


TknSampler *createSamplerPtr(TknGfxContext *pTknGfxContext, VkFilter magFilter, VkFilter minFilter, VkSamplerMipmapMode mipmapMode, VkSamplerAddressMode addressModeU, VkSamplerAddressMode addressModeV, VkSamplerAddressMode addressModeW, float mipLodBias, VkBool32 anisotropyEnable, float maxAnisotropy, float minLod, float maxLod, VkBorderColor borderColor);
void destroySamplerPtr(TknGfxContext *pTknGfxContext, TknSampler *pTknSampler);
TknUniformBuffer *createUniformBufferPtr(TknGfxContext *pTknGfxContext, const void *data, VkDeviceSize size);
void destroyUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer);
void updateUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer, const void *data, VkDeviceSize size);

TknMesh *createMeshPtrWithData(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknMeshVertexInputLayout, void *vertices, uint32_t vertexCount, VkIndexType vkIndexType, void *indices, uint32_t indexCount);
TknMesh *createMeshPtrWithPlyFile(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknMeshVertexInputLayout, VkIndexType vkIndexType, const char *plyFilePath);
void saveMeshPtrToPlyFile(uint32_t vertexPropertyCount, const char **vertexPropertyNames, const char **vertexPropertyTypes, TknVertexInputLayout *pTknMeshVertexInputLayout, void *vertices, uint32_t vertexCount, VkIndexType vkIndexType, void *indices, uint32_t indexCount, const char *plyFilePath);
void destroyMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh);
void updateMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh, const char *format, const void *vertices, uint32_t vertexCount, uint32_t indexType, const void *indices, uint32_t indexCount);

TknInstance *createInstancePtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout, uint32_t instanceCount, void *instances);
void updateInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance, void *newData, uint32_t instanceCount);
void destroyInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance);

TknMaterial *getGlobalMaterialPtr(TknGfxContext *pTknGfxContext);
TknMaterial *getSubpassMaterialPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass, uint32_t subpassIndex);
TknMaterial *createPipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline);
void destroyPipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);
void updateMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial, uint32_t inputBindingCount, TknInputBinding *tknInputBindings);
TknInputBindingUnion getEmptyInputBindingUnion(TknGfxContext *pTknGfxContext, VkDescriptorType vkDescriptorType);

void tknError(char const *const _Format, ...);
void tknWarning(const char *format, ...);
void tknAssert(bool condition, char const *const _Format, ...);
void *tknMalloc(size_t size);
void tknFree(void *ptr);