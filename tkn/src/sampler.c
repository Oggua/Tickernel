#include "gfxCore.h"

TknSampler *createSamplerPtr(TknGfxContext *pTknGfxContext, VkFilter magFilter, VkFilter minFilter, VkSamplerMipmapMode mipmapMode, VkSamplerAddressMode addressModeU, VkSamplerAddressMode addressModeV, VkSamplerAddressMode addressModeW, float mipLodBias, VkBool32 anisotropyEnable, float maxAnisotropy, float minLod, float maxLod, VkBorderColor borderColor)
{
    TknSampler *pTknSampler = tknMalloc(sizeof(TknSampler));
    // Initialize the hash set for binding references
    pTknSampler->bindingPtrHashSet = tknCreateHashSet(sizeof(Binding *));
    // Create sampler create info with provided parameters
    VkSamplerCreateInfo samplerCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .magFilter = magFilter,
        .minFilter = minFilter,
        .mipmapMode = mipmapMode,
        .addressModeU = addressModeU,
        .addressModeV = addressModeV,
        .addressModeW = addressModeW,
        .mipLodBias = mipLodBias,
        .anisotropyEnable = anisotropyEnable,
        .maxAnisotropy = maxAnisotropy,
        .compareEnable = VK_FALSE,
        .compareOp = VK_COMPARE_OP_ALWAYS,
        .minLod = minLod,
        .maxLod = maxLod,
        .borderColor = borderColor,
        .unnormalizedCoordinates = VK_FALSE,
    };

    // Create the Vulkan sampler
    VkResult result = vkCreateSampler(pTknGfxContext->vkDevice, &samplerCreateInfo, NULL, &pTknSampler->vkSampler);
    if (result != VK_SUCCESS)
    {
        tknError("Failed to create Vulkan sampler: %d", result);
        tknDestroyHashSet(pTknSampler->bindingPtrHashSet);
        tknFree(pTknSampler);
        return NULL;
    }
    
    return pTknSampler;
}

void destroySamplerPtr(TknGfxContext *pTknGfxContext, TknSampler *pTknSampler)
{
    if (pTknSampler == NULL)
    {
        return;
    }
    
    // Clear all binding references
    clearBindingPtrHashSet(pTknGfxContext, pTknSampler->bindingPtrHashSet);
    
    // Destroy the hash set
    tknDestroyHashSet(pTknSampler->bindingPtrHashSet);
    
    // Destroy the Vulkan sampler
    if (pTknSampler->vkSampler != VK_NULL_HANDLE)
    {
        vkDestroySampler(pTknGfxContext->vkDevice, pTknSampler->vkSampler, NULL);
    }
    
    // Free the sampler struct
    tknFree(pTknSampler);
}
