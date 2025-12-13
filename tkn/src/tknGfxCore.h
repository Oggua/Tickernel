#pragma once
#include <stdio.h>
#include <cglm/cglm.h>
#include "tknCore.h"
#include <spirv_reflect.h>

struct TknSampler
{
    VkSampler vkSampler;
    TknHashSet tknBindingPtrHashSet;
};

struct TknImage
{
    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    TknHashSet tknBindingPtrHashSet;
};

struct TknUniformBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    void *mapped;
    TknHashSet tknBindingPtrHashSet;
    VkDeviceSize size;
};
struct TknStorageBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    TknHashSet tknBindingPtrHashSet;
    VkDeviceSize size;
};

struct TknUniformTexelBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    TknHashSet tknBindingPtrHashSet;
    VkDeviceSize size;
};
struct TknStorageTexelBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    TknHashSet tknBindingPtrHashSet;
    VkDeviceSize size;
};

struct TknUniformDynamicBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    void *mapped;
    TknHashSet tknBindingPtrHashSet;
    VkDeviceSize size;
};
struct TknStorageDynamicBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    void *mapped;
    TknHashSet tknBindingPtrHashSet;
    VkDeviceSize size;
};

typedef struct
{
    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    uint32_t width;
    uint32_t height;
    TknHashSet tknBindingPtrHashSet;
} TknFixedAttachment;
typedef struct
{
    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    float32_t scaler;
    VkImageUsageFlags vkImageUsageFlags;
    VkImageAspectFlags vkImageAspectFlags;
    TknHashSet tknBindingPtrHashSet;
} TknDynamicAttachment;
typedef struct
{
    VkExtent2D tknSwapchainExtent;
    VkSwapchainKHR vkSwapchain;
    uint32_t tknSwapchainImageCount;
    VkImage *tknSwapchainImages;
    VkImageView *tknSwapchainImageViews;
} TknSwapchainAttachment;
typedef union
{
    TknFixedAttachment tknFixedAttachment;
    TknDynamicAttachment tknDynamicAttachment;
    TknSwapchainAttachment tknSwapchainAttachment;
} TknAttachmentUnion;
typedef enum
{
    TKN_ATTACHMENT_TYPE_DYNAMIC,
    TKN_ATTACHMENT_TYPE_FIXED,
    TKN_ATTACHMENT_TYPE_SWAPCHAIN,
} TknAttachmentType;
struct TknAttachment
{
    TknAttachmentType tknAttachmentType;
    TknAttachmentUnion tknAttachmentUnion;
    VkFormat vkFormat;
    TknHashSet tknRenderPassPtrHashSet;
};

typedef struct
{
    TknAttachment *pTknAttachment;
    VkImageLayout vkImageLayout;
} TknInputAttachmentBinding;

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
    // VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT = 10,
    TknInputAttachmentBinding tknInputAttachmentBinding;
} TknBindingUnion;

typedef struct
{
    VkDescriptorType vkDescriptorType;
    TknBindingUnion tknBindingUnion;
    TknMaterial *pTknMaterial;
    uint32_t binding;
} TknBinding;

typedef struct
{
    VkDescriptorSetLayout vkDescriptorSetLayout;
    TknDynamicArray vkDescriptorPoolSizeDynamicArray;
    uint32_t tknDescriptorCount;
    VkDescriptorType *vkDescriptorTypes;
    TknHashSet tknMaterialPtrHashSet;
} TknDescriptorSet;

typedef enum
{
    VERTEX_BINDING_DESCRIPTION,
    INSTANCE_BINDING_DESCRIPTION,
    MAX_VERTEX_BINDING_DESCRIPTION
} TknVertexBindingDescription;

struct TknVertexInputLayout
{
    uint32_t tknAttributeCount;
    const char **names;
    uint32_t *sizes;
    uint32_t *offsets;
    uint32_t stride;
    TknHashSet tknReferencePtrHashSet;
};

struct TknInstance
{
    TknVertexInputLayout *pTknVertexInputLayout;
    VkBuffer tknInstanceVkBuffer;
    VkDeviceMemory tknInstanceVkDeviceMemory;
    void *tknInstanceMappedBuffer;
    uint32_t tknInstanceCount;
    uint32_t tknMaxInstanceCount;
    TknHashSet tknDrawCallPtrHashSet;
};

struct TknMesh
{
    TknVertexInputLayout *pTknVertexInputLayout;
    VkBuffer tknVertexVkBuffer;
    VkDeviceMemory tknVertexVkDeviceMemory;
    uint32_t tknVertexCount;

    VkIndexType vkIndexType;
    VkBuffer tknIndexVkBuffer;
    VkDeviceMemory tknIndexVkDeviceMemory;
    uint32_t tknIndexCount;
    TknHashSet tknDrawCallPtrHashSet;
};

struct TknMaterial
{
    VkDescriptorSet vkDescriptorSet;
    uint32_t tknBindingCount;
    TknBinding *pTknBindings;
    VkDescriptorPool vkDescriptorPool;
    TknDescriptorSet *pTknDescriptorSet;
    TknHashSet tknDrawCallPtrHashSet;
};

struct TknDrawCall
{
    TknPipeline *pTknPipeline;
    TknMaterial *pTknMaterial;
    TknInstance *pTknInstance;
    TknMesh *pTknMesh;
};

typedef enum
{
    TKN_GLOBAL_DESCRIPTOR_SET,
    TKN_SUBPASS_DESCRIPTOR_SET,
    TKN_PIPELINE_DESCRIPTOR_SET,
    TKN_MAX_DESCRIPTOR_SET,
} TknTickernelDescriptorSet;

struct TknPipeline
{
    VkPipeline vkPipeline;
    TknDescriptorSet *pTknPipelineDescriptorSet;
    VkPipelineLayout vkPipelineLayout;
    TknRenderPass *pTknRenderPass;
    uint32_t subpassIndex;

    TknVertexInputLayout *pTknMeshVertexInputLayout;
    TknVertexInputLayout *pTknInstanceVertexInputLayout;
    TknHashSet tknDrawCallPtrHashSet;  // Only track which drawcalls belong to this pipeline
};

struct TknSubpass
{
    TknDescriptorSet *pTknSubpassDescriptorSet;
    TknHashSet tknPipelinePtrHashSet;
    TknDynamicArray tknDrawCallPtrDynamicArray;  // Shared drawcall queue for all pipelines in this subpass
};

struct TknRenderPass
{
    VkRenderPass vkRenderPass;
    uint32_t tknAttachmentCount;
    TknAttachment **tknAttachmentPtrs;
    VkClearValue *vkClearValues;
    uint32_t vkFramebufferCount;
    VkFramebuffer *vkFramebuffers;
    VkRect2D tknRenderArea;
    uint32_t tknSubpassCount;
    struct TknSubpass *pTknSubpasses;
};

struct TknGfxContext
{
    uint32_t tknFrameCount;
    VkInstance vkInstance;
    VkSurfaceKHR vkSurface;

    VkPhysicalDevice vkPhysicalDevice;
    VkPhysicalDeviceProperties vkPhysicalDeviceProperties;
    uint32_t tknGfxQueueFamilyIndex;
    uint32_t tknPresentQueueFamilyIndex;
    VkSurfaceFormatKHR tknSurfaceFormat;
    VkPresentModeKHR tknPresentMode;

    VkDevice vkDevice;
    VkQueue vkGfxQueue;
    VkQueue vkPresentQueue;

    VkSurfaceCapabilitiesKHR vkSurfaceCapabilities;
    TknAttachment *pTknSwapchainAttachment;

    VkSemaphore vkImageAvailableSemaphore;
    VkSemaphore vkRenderFinishedSemaphore;
    VkFence vkRenderFinishedFence;

    VkCommandPool vkGfxCommandPool;
    VkCommandBuffer *vkGfxCommandBuffers;

    TknHashSet tknDynamicAttachmentPtrHashSet;
    TknHashSet tknFixedAttachmentPtrHashSet;
    TknDynamicArray tknRenderPassPtrDynamicArray;

    TknDescriptorSet *pTknGlobalDescriptorSet;
    TknHashSet tknVertexInputLayoutPtrHashSet;

    // Empty resources for empty bindings
    TknUniformBuffer *pTknEmptyUniformBuffer;
    TknSampler *pTknEmptySampler;
    TknImage *pTknEmptyImage;
};

void tknAssertVkResult(VkResult vkResult);

SpvReflectShaderModule tknCreateSpvReflectShaderModule(const char *filePath);
void tknDestroySpvReflectShaderModule(SpvReflectShaderModule *pSpvReflectShaderModule);

void tknCreateVkBuffer(TknGfxContext *pTknGfxContext, VkDeviceSize bufferSize, VkBufferUsageFlags bufferUsageFlags, VkMemoryPropertyFlags memoryPropertyFlags, VkBuffer *pVkBuffer, VkDeviceMemory *pVkDeviceMemory);
void tknDestroyVkBuffer(TknGfxContext *pTknGfxContext, VkBuffer vkBuffer, VkDeviceMemory vkDeviceMemory);

TknDescriptorSet *tknCreateDescriptorSetPtr(TknGfxContext *pTknGfxContext, uint32_t spvReflectShaderModuleCount, SpvReflectShaderModule *spvReflectShaderModules, uint32_t set);
void tknDestroyDescriptorSetPtr(TknGfxContext *pTknGfxContext, TknDescriptorSet *pTknDescriptorSet);

void tknPopulateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);
void tknCleanupFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);
void tknRepopulateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);

TknMaterial *tknCreateMaterialPtr(TknGfxContext *pTknGfxContext, TknDescriptorSet *pTknDescriptorSet);
void tknDestroyMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);

void tknResizeDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment);
void tknBindAttachmentsToMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);
void tknUnbindAttachmentsFromMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);
void tknUpdateAttachmentOfMaterialPtr(TknGfxContext *pTknGfxContext, TknBinding *pTknBinding);
TknInputBindingUnion tknGetEmptyInputBindingUnion(TknGfxContext *pTknGfxContext, VkDescriptorType vkDescriptorType);
void tknClearBindingPtrHashSet(TknGfxContext *pTknGfxContext, TknHashSet tknBindingPtrHashSet);

void tknCreateVkImage(TknGfxContext *pTknGfxContext, VkExtent3D vkExtent3D, VkFormat vkFormat, VkImageTiling vkImageTiling, VkImageUsageFlags vkImageUsageFlags, VkMemoryPropertyFlags vkMemoryPropertyFlags, VkImageAspectFlags vkImageAspectFlags, VkImage *pVkImage, VkDeviceMemory *pVkDeviceMemory, VkImageView *pVkImageView);
void tknDestroyVkImage(TknGfxContext *pTknGfxContext, VkImage vkImage, VkDeviceMemory vkDeviceMemory, VkImageView vkImageView);

VkCommandBuffer tknBeginSingleTimeCommands(TknGfxContext *pTknGfxContext);
void tknEndSingleTimeCommands(TknGfxContext *pTknGfxContext, VkCommandBuffer vkCommandBuffer);