#include "gfxCore.h"

Image *createImagePtr(GfxContext *pGfxContext, VkExtent3D vkExtent3D, VkFormat vkFormat, VkImageTiling vkImageTiling, VkImageUsageFlags vkImageUsageFlags, VkMemoryPropertyFlags vkMemoryPropertyFlags, VkImageAspectFlags vkImageAspectFlags, void *data, VkDeviceSize dataSize)
{
    Image *pImage = tknMalloc(sizeof(Image));
    VkImage vkImage;
    VkImageView vkImageView;
    VkDeviceMemory vkDeviceMemory;

    // Create the Vulkan image
    createVkImage(pGfxContext, vkExtent3D, vkFormat, vkImageTiling, vkImageUsageFlags, vkMemoryPropertyFlags, vkImageAspectFlags, &vkImage, &vkDeviceMemory, &vkImageView);

    Image image = {
        .vkImage = vkImage,
        .vkDeviceMemory = vkDeviceMemory,
        .vkImageView = vkImageView,
        .bindingPtrHashSet = tknCreateHashSet(sizeof(Binding *)),
    };
    *pImage = image;

    // Handle image layout initialization based on usage
    if (data != NULL && dataSize > 0)
    {
        // Data provided - upload it immediately
        uint32_t width = vkExtent3D.width;
        uint32_t height = vkExtent3D.height;

        // Create staging buffer
        VkBuffer stagingBuffer;
        VkDeviceMemory stagingBufferMemory;
        createVkBuffer(pGfxContext, dataSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &stagingBuffer, &stagingBufferMemory);

        // Copy data to staging buffer
        void *mappedData;
        vkMapMemory(pGfxContext->vkDevice, stagingBufferMemory, 0, dataSize, 0, &mappedData);
        memcpy(mappedData, data, (size_t)dataSize);
        vkUnmapMemory(pGfxContext->vkDevice, stagingBufferMemory);

        // Begin command buffer - all operations in one submission
        VkCommandBuffer commandBuffer = beginSingleTimeCommands(pGfxContext);

        // Transition image layout for transfer (UNDEFINED -> TRANSFER_DST)
        VkImageMemoryBarrier barrier1 = {};
        barrier1.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier1.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        barrier1.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier1.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier1.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier1.image = pImage->vkImage;
        barrier1.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier1.subresourceRange.baseMipLevel = 0;
        barrier1.subresourceRange.levelCount = 1;
        barrier1.subresourceRange.baseArrayLayer = 0;
        barrier1.subresourceRange.layerCount = 1;
        barrier1.srcAccessMask = 0;
        barrier1.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

        vkCmdPipelineBarrier(commandBuffer,
                             VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                             VK_PIPELINE_STAGE_TRANSFER_BIT,
                             0, 0, NULL, 0, NULL, 1, &barrier1);

        // Copy buffer to image
        VkBufferImageCopy region = {};
        region.bufferOffset = 0;
        region.bufferRowLength = 0;
        region.bufferImageHeight = 0;
        region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        region.imageSubresource.mipLevel = 0;
        region.imageSubresource.baseArrayLayer = 0;
        region.imageSubresource.layerCount = 1;
        region.imageOffset = (VkOffset3D){0, 0, 0};
        region.imageExtent = (VkExtent3D){width, height, 1};

        vkCmdCopyBufferToImage(commandBuffer, stagingBuffer, pImage->vkImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);

        // Transition image layout for shader access (TRANSFER_DST -> SHADER_READ_ONLY)
        VkImageMemoryBarrier barrier2 = {};
        barrier2.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier2.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier2.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        barrier2.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier2.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier2.image = pImage->vkImage;
        barrier2.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier2.subresourceRange.baseMipLevel = 0;
        barrier2.subresourceRange.levelCount = 1;
        barrier2.subresourceRange.baseArrayLayer = 0;
        barrier2.subresourceRange.layerCount = 1;
        barrier2.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier2.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

        vkCmdPipelineBarrier(commandBuffer,
                             VK_PIPELINE_STAGE_TRANSFER_BIT,
                             VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                             0, 0, NULL, 0, NULL, 1, &barrier2);

        // Submit all commands once
        endSingleTimeCommands(pGfxContext, commandBuffer);

        // Clean up staging buffer
        destroyVkBuffer(pGfxContext, stagingBuffer, stagingBufferMemory);
    }
    // Note: Empty images (data == NULL) remain in VK_IMAGE_LAYOUT_UNDEFINED state
    // Layout transitions will be handled when the image is actually used
    return pImage;
}
void destroyImagePtr(GfxContext *pGfxContext, Image *pImage)
{
    clearBindingPtrHashSet(pGfxContext, pImage->bindingPtrHashSet);
    tknDestroyHashSet(pImage->bindingPtrHashSet);
    destroyVkImage(pGfxContext, pImage->vkImage, pImage->vkDeviceMemory, pImage->vkImageView);
    tknFree(pImage);
}
void updateImagePtr(GfxContext *pGfxContext, Image *pImage, uint32_t count, void **datas, VkOffset3D *imageOffsets, VkExtent3D *imageExtents, VkDeviceSize *dataSizes)
{
    // Calculate total staging buffer size
    VkDeviceSize totalSize = 0;
    for (uint32_t i = 0; i < count; i++)
    {
        totalSize += dataSizes[i];
    }

    // Create staging buffer
    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;
    createVkBuffer(pGfxContext, totalSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                   VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                   &stagingBuffer, &stagingBufferMemory);

    // Copy all data to staging buffer
    void *mappedData;
    vkMapMemory(pGfxContext->vkDevice, stagingBufferMemory, 0, totalSize, 0, &mappedData);
    
    VkDeviceSize currentOffset = 0;
    for (uint32_t i = 0; i < count; i++)
    {
        memcpy((char *)mappedData + currentOffset, datas[i], (size_t)dataSizes[i]);
        currentOffset += dataSizes[i];
    }
    
    vkUnmapMemory(pGfxContext->vkDevice, stagingBufferMemory);

    // Begin command buffer - all operations in one submission
    VkCommandBuffer commandBuffer = beginSingleTimeCommands(pGfxContext);

    // Transition image layout for transfer (SHADER_READ_ONLY -> TRANSFER_DST)
    VkImageMemoryBarrier barrier1 = {};
    barrier1.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier1.oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier1.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier1.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier1.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier1.image = pImage->vkImage;
    barrier1.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier1.subresourceRange.baseMipLevel = 0;
    barrier1.subresourceRange.levelCount = 1;
    barrier1.subresourceRange.baseArrayLayer = 0;
    barrier1.subresourceRange.layerCount = 1;
    barrier1.srcAccessMask = VK_ACCESS_SHADER_READ_BIT;
    barrier1.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

    vkCmdPipelineBarrier(commandBuffer,
                         VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                         VK_PIPELINE_STAGE_TRANSFER_BIT,
                         0, 0, NULL, 0, NULL, 1, &barrier1);

    // Build all copy regions
    VkBufferImageCopy *regions = tknMalloc(sizeof(VkBufferImageCopy) * count);
    currentOffset = 0;
    
    for (uint32_t i = 0; i < count; i++)
    {
        regions[i].bufferOffset = currentOffset;
        regions[i].bufferRowLength = 0;
        regions[i].bufferImageHeight = 0;
        regions[i].imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        regions[i].imageSubresource.mipLevel = 0;
        regions[i].imageSubresource.baseArrayLayer = 0;
        regions[i].imageSubresource.layerCount = 1;
        regions[i].imageOffset = imageOffsets[i];
        regions[i].imageExtent = imageExtents[i];
        
        currentOffset += dataSizes[i];
    }

    // Copy all regions in one command
    vkCmdCopyBufferToImage(commandBuffer, stagingBuffer, pImage->vkImage, 
                           VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, count, regions);

    tknFree(regions);

    // Transition image layout back to shader access (TRANSFER_DST -> SHADER_READ_ONLY)
    VkImageMemoryBarrier barrier2 = {};
    barrier2.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier2.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier2.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier2.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier2.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier2.image = pImage->vkImage;
    barrier2.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier2.subresourceRange.baseMipLevel = 0;
    barrier2.subresourceRange.levelCount = 1;
    barrier2.subresourceRange.baseArrayLayer = 0;
    barrier2.subresourceRange.layerCount = 1;
    barrier2.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier2.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

    vkCmdPipelineBarrier(commandBuffer,
                         VK_PIPELINE_STAGE_TRANSFER_BIT,
                         VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                         0, 0, NULL, 0, NULL, 1, &barrier2);

    // Submit all commands once
    endSingleTimeCommands(pGfxContext, commandBuffer);

    // Clean up staging buffer
    destroyVkBuffer(pGfxContext, stagingBuffer, stagingBufferMemory);
}