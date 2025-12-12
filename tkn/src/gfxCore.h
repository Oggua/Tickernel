#pragma once
#include <stdio.h>
#include <cglm/cglm.h>
#include "tknCore.h"
#include <spirv_reflect.h>

struct TknSampler
{
    VkSampler vkSampler;
    TknHashSet bindingPtrHashSet;
};

struct TknImage
{
    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    TknHashSet bindingPtrHashSet;
};

struct TknUniformBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    void *mapped;
    TknHashSet bindingPtrHashSet;
    VkDeviceSize size;
};
struct StorageBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    TknHashSet bindingPtrHashSet;
    VkDeviceSize size;
};

struct UniformTexelBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    TknHashSet bindingPtrHashSet;
    VkDeviceSize size;
};
struct StorageTexelBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    TknHashSet bindingPtrHashSet;
    VkDeviceSize size;
};

struct UniformDynamicBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    void *mapped;
    TknHashSet bindingPtrHashSet;
    VkDeviceSize size;
};
struct StorageDynamicBuffer
{
    VkBuffer vkBuffer;
    VkDeviceMemory vkDeviceMemory;
    void *mapped;
    TknHashSet bindingPtrHashSet;
    VkDeviceSize size;
};

typedef struct
{
    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    uint32_t width;
    uint32_t height;
    TknHashSet bindingPtrHashSet;
} FixedAttachment;
typedef struct
{
    VkImage vkImage;
    VkDeviceMemory vkDeviceMemory;
    VkImageView vkImageView;
    float32_t scaler;
    VkImageUsageFlags vkImageUsageFlags;
    VkImageAspectFlags vkImageAspectFlags;
    TknHashSet bindingPtrHashSet;
} DynamicAttachment;
typedef struct
{
    VkExtent2D swapchainExtent;
    VkSwapchainKHR vkSwapchain;
    uint32_t swapchainImageCount;
    VkImage *swapchainImages;
    VkImageView *swapchainImageViews;
} SwapchainAttachment;
typedef union
{
    FixedAttachment fixedAttachment;
    DynamicAttachment dynamicAttachment;
    SwapchainAttachment swapchainAttachment;
} AttachmentUnion;
typedef enum
{
    ATTACHMENT_TYPE_DYNAMIC,
    ATTACHMENT_TYPE_FIXED,
    ATTACHMENT_TYPE_SWAPCHAIN,
} AttachmentType;
struct TknAttachment
{
    AttachmentType attachmentType;
    AttachmentUnion attachmentUnion;
    VkFormat vkFormat;
    TknHashSet renderPassPtrHashSet;
};

typedef struct
{
    TknAttachment *pTknAttachment;
    VkImageLayout vkImageLayout;
} InputAttachmentBinding;

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
    InputAttachmentBinding inputAttachmentBinding;
} BindingUnion;

typedef struct
{
    VkDescriptorType vkDescriptorType;
    BindingUnion bindingUnion;
    TknMaterial *pTknMaterial;
    uint32_t binding;
} Binding;

typedef struct
{
    VkDescriptorSetLayout vkDescriptorSetLayout;
    TknDynamicArray vkDescriptorPoolSizeDynamicArray;
    uint32_t descriptorCount;
    VkDescriptorType *vkDescriptorTypes;
    TknHashSet materialPtrHashSet;
} DescriptorSet;

typedef enum
{
    VERTEX_BINDING_DESCRIPTION,
    INSTANCE_BINDING_DESCRIPTION,
    MAX_VERTEX_BINDING_DESCRIPTION
} VertexBindingDescription;

struct TknVertexInputLayout
{
    uint32_t attributeCount;
    const char **names;
    uint32_t *sizes;
    uint32_t *offsets;
    uint32_t stride;
    TknHashSet referencePtrHashSet;
};

struct TknInstance
{
    TknVertexInputLayout *pTknVertexInputLayout;
    VkBuffer instanceVkBuffer;
    VkDeviceMemory instanceVkDeviceMemory;
    void *instanceMappedBuffer;
    uint32_t instanceCount;
    uint32_t maxInstanceCount;
    TknHashSet drawCallPtrHashSet;
};

struct TknMesh
{
    TknVertexInputLayout *pTknVertexInputLayout;
    VkBuffer vertexVkBuffer;
    VkDeviceMemory vertexVkDeviceMemory;
    uint32_t vertexCount;

    VkIndexType vkIndexType;
    VkBuffer indexVkBuffer;
    VkDeviceMemory indexVkDeviceMemory;
    uint32_t indexCount;
    TknHashSet drawCallPtrHashSet;
};

struct TknMaterial
{
    VkDescriptorSet vkDescriptorSet;
    uint32_t bindingCount;
    Binding *bindings;
    VkDescriptorPool vkDescriptorPool;
    DescriptorSet *pDescriptorSet;
    TknHashSet drawCallPtrHashSet;
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
} TickernelDescriptorSet;

struct TknPipeline
{
    VkPipeline vkPipeline;
    DescriptorSet *pPipelineDescriptorSet;
    VkPipelineLayout vkPipelineLayout;
    TknRenderPass *pTknRenderPass;
    uint32_t subpassIndex;

    TknVertexInputLayout *pTknMeshVertexInputLayout;
    TknVertexInputLayout *pTknInstanceVertexInputLayout;
    TknHashSet drawCallPtrHashSet;  // Only track which drawcalls belong to this pipeline
};

struct Subpass
{
    DescriptorSet *pSubpassDescriptorSet;
    TknHashSet pipelinePtrHashSet;
    TknDynamicArray drawCallPtrDynamicArray;  // Shared drawcall queue for all pipelines in this subpass
};

struct TknRenderPass
{
    VkRenderPass vkRenderPass;
    uint32_t attachmentCount;
    TknAttachment **attachmentPtrs;
    VkClearValue *vkClearValues;
    uint32_t vkFramebufferCount;
    VkFramebuffer *vkFramebuffers;
    VkRect2D renderArea;
    uint32_t subpassCount;
    struct Subpass *subpasses;
};

struct TknGfxContext
{
    uint32_t frameCount;
    VkInstance vkInstance;
    VkSurfaceKHR vkSurface;

    VkPhysicalDevice vkPhysicalDevice;
    VkPhysicalDeviceProperties vkPhysicalDeviceProperties;
    uint32_t gfxQueueFamilyIndex;
    uint32_t presentQueueFamilyIndex;
    VkSurfaceFormatKHR surfaceFormat;
    VkPresentModeKHR presentMode;

    VkDevice vkDevice;
    VkQueue vkGfxQueue;
    VkQueue vkPresentQueue;

    VkSurfaceCapabilitiesKHR vkSurfaceCapabilities;
    TknAttachment *pSwapchainAttachment;

    VkSemaphore imageAvailableSemaphore;
    VkSemaphore renderFinishedSemaphore;
    VkFence renderFinishedFence;

    VkCommandPool gfxVkCommandPool;
    VkCommandBuffer *gfxVkCommandBuffers;

    TknHashSet dynamicAttachmentPtrHashSet;
    TknHashSet fixedAttachmentPtrHashSet;
    TknDynamicArray renderPassPtrDynamicArray;

    DescriptorSet *pGlobalDescriptorSet;
    TknHashSet vertexInputLayoutPtrHashSet;

    // Empty resources for empty bindings
    TknUniformBuffer *pEmptyUniformBuffer;
    TknSampler *pEmptySampler;
    TknImage *pEmptyImage;
};

void assertVkResult(VkResult vkResult);

SpvReflectShaderModule createSpvReflectShaderModule(const char *filePath);
void destroySpvReflectShaderModule(SpvReflectShaderModule *pSpvReflectShaderModule);

void createVkBuffer(TknGfxContext *pTknGfxContext, VkDeviceSize bufferSize, VkBufferUsageFlags bufferUsageFlags, VkMemoryPropertyFlags memoryPropertyFlags, VkBuffer *pVkBuffer, VkDeviceMemory *pVkDeviceMemory);
void destroyVkBuffer(TknGfxContext *pTknGfxContext, VkBuffer vkBuffer, VkDeviceMemory vkDeviceMemory);

DescriptorSet *createDescriptorSetPtr(TknGfxContext *pTknGfxContext, uint32_t spvReflectShaderModuleCount, SpvReflectShaderModule *spvReflectShaderModules, uint32_t set);
void destroyDescriptorSetPtr(TknGfxContext *pTknGfxContext, DescriptorSet *pDescriptorSet);

void populateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);
void cleanupFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);
void repopulateFramebuffers(TknGfxContext *pTknGfxContext, TknRenderPass *pTknRenderPass);

TknMaterial *createMaterialPtr(TknGfxContext *pTknGfxContext, DescriptorSet *pDescriptorSet);
void destroyMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);

void resizeDynamicAttachmentPtr(TknGfxContext *pTknGfxContext, TknAttachment *pTknAttachment);
void bindAttachmentsToMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);
void unbindAttachmentsFromMaterialPtr(TknGfxContext *pTknGfxContext, TknMaterial *pTknMaterial);
void updateAttachmentOfMaterialPtr(TknGfxContext *pTknGfxContext, Binding *pBinding);
TknInputBindingUnion getEmptyInputBindingUnion(TknGfxContext *pTknGfxContext, VkDescriptorType vkDescriptorType);
void clearBindingPtrHashSet(TknGfxContext *pTknGfxContext, TknHashSet bindingPtrHashSet);

void createVkImage(TknGfxContext *pTknGfxContext, VkExtent3D vkExtent3D, VkFormat vkFormat, VkImageTiling vkImageTiling, VkImageUsageFlags vkImageUsageFlags, VkMemoryPropertyFlags vkMemoryPropertyFlags, VkImageAspectFlags vkImageAspectFlags, VkImage *pVkImage, VkDeviceMemory *pVkDeviceMemory, VkImageView *pVkImageView);
void destroyVkImage(TknGfxContext *pTknGfxContext, VkImage vkImage, VkDeviceMemory vkDeviceMemory, VkImageView vkImageView);

VkCommandBuffer beginSingleTimeCommands(TknGfxContext *pTknGfxContext);
void endSingleTimeCommands(TknGfxContext *pTknGfxContext, VkCommandBuffer vkCommandBuffer);