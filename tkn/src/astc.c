#include "gfxCore.h"

// ASTC file header structure
typedef struct {
    uint8_t magic[4];        // ASTC magic number
    uint8_t blockdim_x;      // Block dimension X (4, 5, 6, 8, 10, 12)
    uint8_t blockdim_y;      // Block dimension Y (4, 5, 6, 8, 10, 12)  
    uint8_t blockdim_z;      // Block dimension Z (1 for 2D textures)
    uint8_t xsize[3];        // X size (little endian)
    uint8_t ysize[3];        // Y size (little endian)
    uint8_t zsize[3];        // Z size (little endian)
} TknASTCHeader;

// Helper function to read 24-bit little endian value
static uint32_t read24LE(const uint8_t* data) {
    return data[0] | (data[1] << 8) | (data[2] << 16);
}

static VkFormat getASTCVulkanFormat(uint32_t blockWidth, uint32_t blockHeight) {
    // Map ASTC block sizes to Vulkan formats
    if (blockWidth == 4 && blockHeight == 4) {
        return VK_FORMAT_ASTC_4x4_UNORM_BLOCK;
    } else if (blockWidth == 5 && blockHeight == 4) {
        return VK_FORMAT_ASTC_5x4_UNORM_BLOCK;
    } else if (blockWidth == 5 && blockHeight == 5) {
        return VK_FORMAT_ASTC_5x5_UNORM_BLOCK;
    } else if (blockWidth == 6 && blockHeight == 5) {
        return VK_FORMAT_ASTC_6x5_UNORM_BLOCK;
    } else if (blockWidth == 6 && blockHeight == 6) {
        return VK_FORMAT_ASTC_6x6_UNORM_BLOCK;
    } else if (blockWidth == 8 && blockHeight == 5) {
        return VK_FORMAT_ASTC_8x5_UNORM_BLOCK;
    } else if (blockWidth == 8 && blockHeight == 6) {
        return VK_FORMAT_ASTC_8x6_UNORM_BLOCK;
    } else if (blockWidth == 8 && blockHeight == 8) {
        return VK_FORMAT_ASTC_8x8_UNORM_BLOCK;
    } else if (blockWidth == 10 && blockHeight == 5) {
        return VK_FORMAT_ASTC_10x5_UNORM_BLOCK;
    } else if (blockWidth == 10 && blockHeight == 6) {
        return VK_FORMAT_ASTC_10x6_UNORM_BLOCK;
    } else if (blockWidth == 10 && blockHeight == 8) {
        return VK_FORMAT_ASTC_10x8_UNORM_BLOCK;
    } else if (blockWidth == 10 && blockHeight == 10) {
        return VK_FORMAT_ASTC_10x10_UNORM_BLOCK;
    } else if (blockWidth == 12 && blockHeight == 10) {
        return VK_FORMAT_ASTC_12x10_UNORM_BLOCK;
    } else if (blockWidth == 12 && blockHeight == 12) {
        return VK_FORMAT_ASTC_12x12_UNORM_BLOCK;
    }
    
    printf("Error: Unsupported ASTC block size %dx%d\n", blockWidth, blockHeight);
    return VK_FORMAT_UNDEFINED;
}



TknASTCImage* createASTCFromMemory(const char* buffer, size_t bufferSize) {
    if (!buffer || bufferSize < sizeof(TknASTCHeader)) {
        printf("Error: Invalid buffer or buffer too small\n");
        return NULL;
    }
    
    const TknASTCHeader* header = (const TknASTCHeader*)buffer;
    
    // Check ASTC magic number (0x5CA1AB13)
    if (header->magic[0] != 0x13 || header->magic[1] != 0xAB || 
        header->magic[2] != 0xA1 || header->magic[3] != 0x5C) {
        printf("Error: Invalid ASTC magic number\n");
        return NULL;
    }
    
    // Parse dimensions
    uint32_t width = read24LE(header->xsize);
    uint32_t height = read24LE(header->ysize);
    uint32_t depth = read24LE(header->zsize);
    uint32_t blockWidth = header->blockdim_x;
    uint32_t blockHeight = header->blockdim_y;
    uint32_t blockDepth = header->blockdim_z;
    
    // Validate dimensions
    if (width == 0 || height == 0 || depth != 1 || blockDepth != 1) {
        printf("Error: Invalid ASTC dimensions: %dx%dx%d, blocks: %dx%dx%d\n", 
               width, height, depth, blockWidth, blockHeight, blockDepth);
        return NULL;
    }
    
    // Calculate compressed data size
    uint32_t blocksX = (width + blockWidth - 1) / blockWidth;
    uint32_t blocksY = (height + blockHeight - 1) / blockHeight;
    uint32_t compressedSize = blocksX * blocksY * 16; // Each ASTC block is 128 bits (16 bytes)
    
    if (sizeof(TknASTCHeader) + compressedSize != bufferSize) {
        printf("Error: ASTC file size mismatch. Expected %zu, got %zu\n", 
               sizeof(TknASTCHeader) + compressedSize, bufferSize);
        return NULL;
    }
    
    // Get Vulkan format
    VkFormat vkFormat = getASTCVulkanFormat(blockWidth, blockHeight);
    if (vkFormat == VK_FORMAT_UNDEFINED) {
        return NULL;
    }
    
    // Create TknASTCImage structure
    TknASTCImage* tknAstcImage = tknMalloc(sizeof(TknASTCImage));
    tknAstcImage->width = width;
    tknAstcImage->height = height;
    tknAstcImage->vkFormat = vkFormat;
    tknAstcImage->size = compressedSize;
    
    // Copy compressed data
    tknAstcImage->data = tknMalloc(compressedSize);
    memcpy(tknAstcImage->data, buffer + sizeof(TknASTCHeader), compressedSize);
    
    printf("Loaded ASTC image: %dx%d, blocks: %dx%d, format: %d, size: %u bytes\n", 
           width, height, blockWidth, blockHeight, vkFormat, compressedSize);
    
    return tknAstcImage;
}

void destroyASTCImage(TknASTCImage* tknAstcImage) {
    if (tknAstcImage) {
        if (tknAstcImage->data) {
            tknFree(tknAstcImage->data);
        }
        tknFree(tknAstcImage);
    }
}