#include "tknFont.h"

static void assertFTError(FT_Error error)
{
    tknAssert(error == 0, "FreeType error: %d", error);
}

TknChar *loadTknChar(TknFont *pTknFont, uint32_t unicode)
{
    uint32_t index = unicode % pTknFont->tknCharCapacity;
    TknChar *pTknChar = pTknFont->tknCharPtrs[index];
    while (pTknChar)
    {
        if (pTknChar->unicode == unicode)
        {
            return pTknChar;
        }
        pTknChar = pTknChar->pNext;
    }

    // Load character using FreeType
    assertFTError(FT_Load_Char(pTknFont->ftFace, unicode, FT_LOAD_RENDER));
    FT_GlyphSlot glyph = pTknFont->ftFace->glyph;
    FT_Bitmap *ftBitmap = &glyph->bitmap;

    // Check if we need to move to next row
    if (pTknFont->penX + ftBitmap->width > pTknFont->atlasLength)
    {
        pTknFont->penX = 0;
        pTknFont->penY += pTknFont->maxRowHeight;
        pTknFont->maxRowHeight = 0;
    }
    // Check if atlas is full
    if (pTknFont->penY + ftBitmap->rows > pTknFont->atlasLength)
    {
        tknWarning("Font atlas is full (size: %dx%d), cannot load character U+%04X\n",
                   pTknFont->atlasLength, pTknFont->atlasLength, unicode);
        return NULL;
    }

    // Create TknChar entry
    TknChar *pNewChar = tknMalloc(sizeof(TknChar));
    pNewChar->unicode = unicode;
    pNewChar->x = pTknFont->penX;
    pNewChar->y = pTknFont->penY;
    pNewChar->width = glyph->bitmap.width;
    pNewChar->height = glyph->bitmap.rows;
    pNewChar->bearingX = glyph->bitmap_left;
    pNewChar->bearingY = glyph->bitmap_top;
    pNewChar->advance = glyph->advance.x >> 6;
    // Insert into hash table
    pNewChar->pNext = pTknFont->tknCharPtrs[index];
    pTknFont->tknCharPtrs[index] = pNewChar;
    pTknFont->tknCharCount++;

    pTknFont->dirtyTknCharPtrCount++;
    pNewChar->pNextDirty = pTknFont->pDirtyTknChar;
    pTknFont->pDirtyTknChar = pNewChar;
    
    // Cache bitmap in TknChar - copy FreeType bitmap data
    // Allocate and copy bitmap buffer (FreeType's buffer will be reused)
    pNewChar->bitmapSize = ftBitmap->rows * ftBitmap->pitch;
    if (pNewChar->bitmapSize > 0)
    {
        pNewChar->bitmapBuffer = tknMalloc(pNewChar->bitmapSize);
        memcpy(pNewChar->bitmapBuffer, ftBitmap->buffer, pNewChar->bitmapSize);
    }
    else
    {
        pNewChar->bitmapBuffer = NULL;
    }
    
    // Update pen position
    pTknFont->penX += glyph->bitmap.width + 1;
    if (glyph->bitmap.rows + 1 > pTknFont->maxRowHeight)
    {
        pTknFont->maxRowHeight = glyph->bitmap.rows + 1;
    }
    return pNewChar;
}

void flushTknFontPtr(TknFont *pTknFont, GfxContext *pGfxContext)
{
    if (pTknFont->dirtyTknCharPtrCount == 0)
    {
        return;  // No dirty characters to upload
    }

    // Allocate arrays for batch upload
    void **datas = tknMalloc(sizeof(void *) * pTknFont->dirtyTknCharPtrCount);
    VkOffset3D *offsets = tknMalloc(sizeof(VkOffset3D) * pTknFont->dirtyTknCharPtrCount);
    VkExtent3D *extents = tknMalloc(sizeof(VkExtent3D) * pTknFont->dirtyTknCharPtrCount);
    VkDeviceSize *sizes = tknMalloc(sizeof(VkDeviceSize) * pTknFont->dirtyTknCharPtrCount);

    // Gather all dirty character data
    TknChar *pCurrent = pTknFont->pDirtyTknChar;
    uint32_t index = 0;
    
    while (pCurrent)
    {
        datas[index] = pCurrent->bitmapBuffer;
        offsets[index] = (VkOffset3D){pCurrent->x, pCurrent->y, 0};
        extents[index] = (VkExtent3D){pCurrent->width, pCurrent->height, 1};
        sizes[index] = pCurrent->bitmapSize;
        
        index++;
        pCurrent = pCurrent->pNextDirty;
    }

    // Batch upload all characters
    updateImagePtr(pGfxContext, pTknFont->pImage, 
                   pTknFont->dirtyTknCharPtrCount, 
                   datas, offsets, extents, sizes);

    // Clean up: free bitmap buffers and clear dirty list
    pCurrent = pTknFont->pDirtyTknChar;
    while (pCurrent)
    {
        TknChar *pNext = pCurrent->pNextDirty;
        
        // Free the bitmap buffer
        if (pCurrent->bitmapBuffer)
        {
            tknFree(pCurrent->bitmapBuffer);
            pCurrent->bitmapBuffer = NULL;
        }
        pCurrent->bitmapSize = 0;
        
        pCurrent->pNextDirty = NULL;
        pCurrent = pNext;
    }

    // Clear dirty list
    pTknFont->pDirtyTknChar = NULL;
    pTknFont->dirtyTknCharPtrCount = 0;

    // Free temporary arrays
    tknFree(datas);
    tknFree(offsets);
    tknFree(extents);
    tknFree(sizes);
}

TknFont *createTknFontPtr(TknFontLibrary *pTknFontLibrary, GfxContext *pGfxContext, const char *fontPath, uint32_t fontSize, uint32_t atlasLength)
{
    TknFont *pTknFont = tknMalloc(sizeof(TknFont));

    // Calculate approximate character capacity based on atlas size and font size
    // Assume average character is fontSize x fontSize, with some overhead
    uint32_t charsPerRow = atlasLength / fontSize;
    uint32_t totalCharCount = charsPerRow * charsPerRow;
    // Use hash table capacity = totalChars * 1.5 for good load factor
    pTknFont->tknCharCapacity = totalCharCount * 3 / 2;

    pTknFont->tknCharCount = 0;
    pTknFont->tknCharPtrs = tknMalloc(sizeof(TknChar *) * pTknFont->tknCharCapacity);
    memset(pTknFont->tknCharPtrs, 0, sizeof(TknChar *) * pTknFont->tknCharCapacity);
    // Create fixed-size square atlas
    pTknFont->atlasLength = atlasLength;
    pTknFont->pImage = createImagePtr(pGfxContext, (VkExtent3D){atlasLength, atlasLength, 1},
                                      VK_FORMAT_R8_UNORM, VK_IMAGE_TILING_OPTIMAL,
                                      VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                                      VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                                      VK_IMAGE_ASPECT_COLOR_BIT,
                                      NULL, 0);
    // pTknFont->atlas = tknMalloc(sizeof(char) * atlasLength * atlasLength);
    // memset(pTknFont->atlas, 0, sizeof(char) * atlasLength * atlasLength);

    pTknFont->penX = 0;
    pTknFont->penY = 0;
    pTknFont->maxRowHeight = 0;
    pTknFont->tknCharCount = 0;
    pTknFont->pDirtyTknChar = NULL;
    pTknFont->tknCharCount = 0;
    pTknFont->pNext = NULL;

    // Load the font using FreeType
    assertFTError(FT_New_Face(pTknFontLibrary->ftLibrary, fontPath, 0, &pTknFont->ftFace));
    assertFTError(FT_Set_Pixel_Sizes(pTknFont->ftFace, 0, fontSize));

    // Store the TknFont in the library
    pTknFont->pNext = pTknFontLibrary->pTknFont;
    pTknFontLibrary->pTknFont = pTknFont;

    return pTknFont;
}

void destroyTknFontPtr(TknFont *pTknFont, GfxContext *pGfxContext)
{
    for (uint32_t i = 0; i < pTknFont->tknCharCapacity; i++)
    {
        TknChar *pCurrent = pTknFont->tknCharPtrs[i];
        while (pCurrent)
        {
            TknChar *pNext = pCurrent->pNext;
            
            // Free bitmap buffer if exists
            if (pCurrent->bitmapBuffer)
            {
                tknFree(pCurrent->bitmapBuffer);
            }
            
            tknFree(pCurrent);
            pCurrent = pNext;
        }
    }

    tknFree(pTknFont->tknCharPtrs);
    destroyImagePtr(pGfxContext, pTknFont->pImage);
    tknFree(pTknFont);
}

TknFontLibrary *createTknFontLibraryPtr()
{
    TknFontLibrary *pLibrary = tknMalloc(sizeof(TknFontLibrary));
    if (pLibrary)
    {
        FT_Init_FreeType(&pLibrary->ftLibrary);
        pLibrary->pTknFont = NULL;
    }
    return pLibrary;
}

void destroyTknFontLibraryPtr(TknFontLibrary *pTknFontLibrary, GfxContext *pGfxContext)
{
    TknFont *pCurrent = pTknFontLibrary->pTknFont;
    while (pCurrent)
    {
        TknFont *pNext = pCurrent->pNext;
        destroyTknFontPtr(pCurrent, pGfxContext);
        pCurrent = pNext;
    }
    FT_Done_FreeType(pTknFontLibrary->ftLibrary);
    tknFree(pTknFontLibrary);
}
