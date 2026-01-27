#pragma once
#include <stdbool.h>
#include "vulkan/vulkan.h"

#define TKN_ARRAY_COUNT(array) (NULL == array) ? 0 : (sizeof(array) / sizeof(array[0]))

typedef struct TknGfxContext TknGfxContext;
typedef struct TknFrame TknFrame;

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
    uint32_t size;     // Compressed data size
    char *data;        // Compressed ASTC data
} TknASTCImage;

TknASTCImage *tknCreateASTCFromMemory(const char *buffer, size_t bufferSize);
void tknDestroyASTCImage(TknASTCImage *tknAstcImage);

VkFormat tknGetSupportedFormat(TknGfxContext *pTknGfxContext, uint32_t candidateCount, VkFormat *candidates, VkImageTiling tiling, VkFormatFeatureFlags features);

TknGfxContext *tknCreateGfxContextPtr(int targetSwapchainImageCount, VkSurfaceFormatKHR targetVkSurfaceFormat, VkPresentModeKHR targetVkPresentMode, VkInstance vkInstance, VkSurfaceKHR vkSurface, VkExtent2D tknSwapchainExtent, uint32_t spvPathCount, const char **spvPaths);
void tknWaitGfxRenderFence(TknGfxContext *pTknGfxContext);
void tknWaitGfxDeviceIdle(TknGfxContext *pTknGfxContext);
TknFrame *tknAcquireFramePtr(TknGfxContext *pTknGfxContext, VkExtent2D tknSwapchainExtent);
void tknSubmitAndPresentFramePtr(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame);
void tknDestroyGfxContextPtr(TknGfxContext *pTknGfxContext);
void tknBeginRenderPassPtr(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame, TknRenderPass *pTknRenderPass);
void tknEndRenderPassPtr(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame);
void tknNextSubpassPtr(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame);
void tknRecordDrawCallPtr(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame, TknDrawCall *pTknDrawCall);
void tknSetStencilCompareMask(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame, VkStencilFaceFlags faceMask, uint32_t compareMask);
void tknSetStencilWriteMask(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame, VkStencilFaceFlags faceMask, uint32_t writeMask);
void tknSetStencilReference(TknGfxContext *pTknGfxContext, TknFrame *pTknFrame, VkStencilFaceFlags faceMask, uint32_t reference);

TknAttachment *tknCreateDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, float scaler);
void tknDestroyDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment);
TknAttachment *tknCreateFixedAttachmentPtr(TknGfxContext *pTknGfxContext, VkFormat vkFormat, VkImageUsageFlags vkImageUsageFlags, VkImageAspectFlags vkImageAspectFlags, uint32_t width, uint32_t height);
void tknDestroyFixedAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment);
TknAttachment *tknGetSwapchainAttachmentPtr(TknGfxContext *pTknGfxContext);

TknVertexInputLayout *tknCreateVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, uint32_t tknAttributeCount, const char **names, uint32_t *sizes);
void tknDestroyVertexInputLayoutPtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout);

TknRenderPass *tknCreateRenderPassPtr(TknGfxContext *pTknGfxContext, uint32_t tknAttachmentCount, VkAttachmentDescription *vkAttachmentDescriptions, TknAttachment **inputAttachmentPtrs, VkClearValue *vkClearValues, uint32_t tknSubpassCount, VkSubpassDescription *vkSubpassDescriptions, uint32_t *spvPathCounts, const char ***spvPathsArray, uint32_t vkSubpassDependencyCount, VkSubpassDependency *vkSubpassDependencies, uint32_t renderPassIndex);
void tknDestroyRenderPassPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);

TknPipeline *tknCreatePipelinePtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t spvPathCount, const char **spvPaths, TknVertexInputLayout *pTknMeshVertexInputLayout, TknVertexInputLayout *pTknInstanceVertexInputLayout, VkPipelineInputAssemblyStateCreateInfo vkPipelineInputAssemblyStateCreateInfo, VkPipelineViewportStateCreateInfo vkPipelineViewportStateCreateInfo, VkPipelineRasterizationStateCreateInfo vkPipelineRasterizationStateCreateInfo, VkPipelineMultisampleStateCreateInfo vkPipelineMultisampleStateCreateInfo, VkPipelineDepthStencilStateCreateInfo vkPipelineDepthStencilStateCreateInfo, VkPipelineColorBlendStateCreateInfo vkPipelineColorBlendStateCreateInfo, VkPipelineDynamicStateCreateInfo vkPipelineDynamicStateCreateInfo);
void tknDestroyPipelinePtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline);

TknDrawCall *tknCreateDrawCallPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline, TknMaterial *pTknMaterial, TknMesh *pTknMesh, TknInstance *pTknInstance);
void tknDestroyDrawCallPtr(TknGfxContext *pTknGfxContext, TknDrawCall *pTknDrawCall);

TknImage *tknCreateImagePtr(TknGfxContext *pTknGfxContext, VkExtent3D vkExtent3D, VkFormat vkFormat, VkImageTiling vkImageTiling, VkImageUsageFlags vkImageUsageFlags, VkMemoryPropertyFlags vkMemoryPropertyFlags, VkImageAspectFlags vkImageAspectFlags, void *data, VkDeviceSize dataSize);
void tknDestroyImagePtr(TknGfxContext *pTknGfxContext, TknImage *pTknImage);
void tknUpdateImagePtr(TknGfxContext *pTknGfxContext, TknImage *pTknImage, uint32_t count, void **datas, VkOffset3D *imageOffsets, VkExtent3D *imageExtents, VkDeviceSize *dataSizes);

TknSampler *tknCreateSamplerPtr(TknGfxContext *pTknGfxContext, VkFilter magFilter, VkFilter minFilter, VkSamplerMipmapMode mipmapMode, VkSamplerAddressMode addressModeU, VkSamplerAddressMode addressModeV, VkSamplerAddressMode addressModeW, float mipLodBias, VkBool32 anisotropyEnable, float maxAnisotropy, float minLod, float maxLod, VkBorderColor borderColor);
void tknDestroySamplerPtr(TknGfxContext *pTknGfxContext, TknSampler *pTknSampler);
TknUniformBuffer *tknCreateUniformBufferPtr(TknGfxContext *pTknGfxContext, const void *data, VkDeviceSize size);
void tknDestroyUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer);
void tknUpdateUniformBufferPtr(TknGfxContext *pTknGfxContext, TknUniformBuffer *pTknUniformBuffer, const void *data, VkDeviceSize size);

TknMesh *tknCreateMeshPtrWithData(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknMeshVertexInputLayout, void *vertices, uint32_t tknVertexCount, VkIndexType vkIndexType, void *indices, uint32_t tknIndexCount);
TknMesh *tknCreateMeshPtrWithPlyFile(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknMeshVertexInputLayout, VkIndexType vkIndexType, const char *plyFilePath);
void tknSaveMeshPtrToPlyFile(uint32_t vertexPropertyCount, const char **vertexPropertyNames, const char **vertexPropertyTypes, TknVertexInputLayout *pTknMeshVertexInputLayout, void *vertices, uint32_t tknVertexCount, VkIndexType vkIndexType, void *indices, uint32_t tknIndexCount, const char *plyFilePath);
void tknDestroyMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh);
void tknUpdateMeshPtr(TknGfxContext *pTknGfxContext, TknMesh *pTknMesh, const char *format, const void *vertices, uint32_t tknVertexCount, uint32_t indexType, const void *indices, uint32_t tknIndexCount);

TknInstance *tknCreateInstancePtr(TknGfxContext *pTknGfxContext, TknVertexInputLayout *pTknVertexInputLayout, uint32_t tknInstanceCount, void *instances);
void tknUpdateInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance, void *newData, uint32_t tknInstanceCount);
void tknDestroyInstancePtr(TknGfxContext *pTknGfxContext, TknInstance *pTknInstance);

TknMaterial *tknGetGlobalMaterialPtr(TknGfxContext *pTknGfxContext);
TknMaterial *tknGetSubpassMaterialPtr(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass, uint32_t subpassIndex);
TknMaterial *tknCreatePipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline);
void tknDestroyPipelineMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);
void tknUpdateMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial, uint32_t inputBindingCount, TknInputBinding *tknInputBindings);
TknInputBindingUnion tknGetEmptyInputBindingUnion(TknGfxContext *pTknGfxContext, VkDescriptorType vkDescriptorType);

void tknError(char const *const _Format, ...);
void tknWarning(const char *format, ...);
void tknAssert(bool condition, char const *const _Format, ...);
void *tknMalloc(size_t size);
void tknFree(void *ptr);