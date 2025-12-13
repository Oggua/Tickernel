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

    assertFTError(FT_Load_Char(pTknFont->ftFace, unicode, FT_LOAD_RENDER));
    FT_GlyphSlot glyph = pTknFont->ftFace->glyph;
    FT_Bitmap *ftBitmap = &glyph->bitmap;

    if (pTknFont->penX + ftBitmap->width > pTknFont->atlasLength)
    {
        pTknFont->penX = 0;
        pTknFont->penY += pTknFont->maxRowHeight;
        pTknFont->maxRowHeight = 0;
    }

    if (pTknFont->penY + ftBitmap->rows > pTknFont->atlasLength)
    {
        tknWarning("Font atlas is full (size: %dx%d), cannot load character U+%04X\n",
                   pTknFont->atlasLength, pTknFont->atlasLength, unicode);
        return NULL;
    }

    TknChar *pNewChar = tknMalloc(sizeof(TknChar));
    pNewChar->unicode = unicode;
    pNewChar->x = pTknFont->penX;
    pNewChar->y = pTknFont->penY;
    pNewChar->width = glyph->bitmap.width;
    pNewChar->height = glyph->bitmap.rows;
    pNewChar->bearingX = glyph->bitmap_left;
    pNewChar->bearingY = glyph->bitmap_top;
    pNewChar->advance = glyph->advance.x >> 6;

    pNewChar->pNext = pTknFont->tknCharPtrs[index];
    pTknFont->tknCharPtrs[index] = pNewChar;
    pTknFont->tknCharCount++;

    pTknFont->dirtyTknCharPtrCount++;
    pNewChar->pNextDirty = pTknFont->pDirtyTknChar;
    pTknFont->pDirtyTknChar = pNewChar;

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

    pTknFont->penX += glyph->bitmap.width + 1;
    if (glyph->bitmap.rows + 1 > pTknFont->maxRowHeight)
    {
        pTknFont->maxRowHeight = glyph->bitmap.rows + 1;
    }
    return pNewChar;
}

void flushTknFontPtr(TknFont *pTknFont, TknGfxContext *pTknGfxContext)
{
    if (pTknFont->dirtyTknCharPtrCount == 0)
    {
        return;
    }

    // First, count how many dirty chars actually have bitmap data
    uint32_t validCharCount = 0;
    TknChar *pCurrent = pTknFont->pDirtyTknChar;
    while (pCurrent)
    {
        if (pCurrent->width > 0 && pCurrent->height > 0 && pCurrent->bitmapBuffer)
        {
            validCharCount++;
        }
        pCurrent = pCurrent->pNextDirty;
    }

    // If no valid chars to upload, just clean up
    if (validCharCount == 0)
    {
        pCurrent = pTknFont->pDirtyTknChar;
        while (pCurrent)
        {
            TknChar *pNext = pCurrent->pNextDirty;

            if (pCurrent->bitmapBuffer)
            {
                tknFree(pCurrent->bitmapBuffer);
                pCurrent->bitmapBuffer = NULL;
            }
            pCurrent->bitmapSize = 0;
            pCurrent->pNextDirty = NULL;
            pCurrent = pNext;
        }
        pTknFont->pDirtyTknChar = NULL;
        pTknFont->dirtyTknCharPtrCount = 0;
        return;
    }

    void **datas = tknMalloc(sizeof(void *) * validCharCount);
    VkOffset3D *offsets = tknMalloc(sizeof(VkOffset3D) * validCharCount);
    VkExtent3D *extents = tknMalloc(sizeof(VkExtent3D) * validCharCount);
    VkDeviceSize *sizes = tknMalloc(sizeof(VkDeviceSize) * validCharCount);

    pCurrent = pTknFont->pDirtyTknChar;
    uint32_t index = 0;

    while (pCurrent)
    {
        // Only copy chars with valid bitmap data
        if (pCurrent->width > 0 && pCurrent->height > 0 && pCurrent->bitmapBuffer)
        {
            datas[index] = pCurrent->bitmapBuffer;
            offsets[index] = (VkOffset3D){pCurrent->x, pCurrent->y, 0};
            extents[index] = (VkExtent3D){pCurrent->width, pCurrent->height, 1};
            sizes[index] = pCurrent->bitmapSize;
            index++;
        }
        pCurrent = pCurrent->pNextDirty;
    }

    tknUpdateImagePtr(pTknGfxContext, pTknFont->pTknImage,
                      validCharCount,
                      datas, offsets, extents, sizes);

    pCurrent = pTknFont->pDirtyTknChar;
    while (pCurrent)
    {
        TknChar *pNext = pCurrent->pNextDirty;

        if (pCurrent->bitmapBuffer)
        {
            tknFree(pCurrent->bitmapBuffer);
            pCurrent->bitmapBuffer = NULL;
        }
        pCurrent->bitmapSize = 0;

        pCurrent->pNextDirty = NULL;
        pCurrent = pNext;
    }

    pTknFont->pDirtyTknChar = NULL;
    pTknFont->dirtyTknCharPtrCount = 0;

    tknFree(datas);
    tknFree(offsets);
    tknFree(extents);
    tknFree(sizes);
}

TknFont *createTknFontPtr(TknFontLibrary *pTknFontLibrary, TknGfxContext *pTknGfxContext, const char *fontPath, uint32_t fontSize, uint32_t atlasLength)
{
    TknFont *pTknFont = tknMalloc(sizeof(TknFont));

    uint32_t charsPerRow = atlasLength / fontSize;
    uint32_t totalCharCount = charsPerRow * charsPerRow;
    pTknFont->tknCharCapacity = totalCharCount * 3 / 2;

    pTknFont->tknCharCount = 0;
    pTknFont->tknCharPtrs = tknMalloc(sizeof(TknChar *) * pTknFont->tknCharCapacity);
    memset(pTknFont->tknCharPtrs, 0, sizeof(TknChar *) * pTknFont->tknCharCapacity);

    pTknFont->atlasLength = atlasLength;

    // Create initial zero-filled buffer for atlas texture
    uint32_t atlasSize = atlasLength * atlasLength;
    unsigned char *pZeroBuffer = tknMalloc(atlasSize);
    memset(pZeroBuffer, 0, atlasSize);

    pTknFont->pTknImage = tknCreateImagePtr(pTknGfxContext, (VkExtent3D){atlasLength, atlasLength, 1},
                                            VK_FORMAT_R8_UNORM, VK_IMAGE_TILING_OPTIMAL,
                                            VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                                            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                                            VK_IMAGE_ASPECT_COLOR_BIT,
                                            pZeroBuffer, atlasSize);

    tknFree(pZeroBuffer);

    pTknFont->penX = 0;
    pTknFont->penY = 0;
    pTknFont->maxRowHeight = 0;
    pTknFont->tknCharCount = 0;
    pTknFont->pDirtyTknChar = NULL;
    pTknFont->tknCharCount = 0;
    pTknFont->pNext = NULL;

    assertFTError(FT_New_Face(pTknFontLibrary->ftLibrary, fontPath, 0, &pTknFont->ftFace));
    assertFTError(FT_Set_Pixel_Sizes(pTknFont->ftFace, 0, fontSize));

    pTknFont->pNext = pTknFontLibrary->pTknFont;
    pTknFontLibrary->pTknFont = pTknFont;

    return pTknFont;
}

void destroyTknFontPtr(TknFontLibrary *pTknFontLibrary, TknFont *pTknFont, TknGfxContext *pTknGfxContext)
{
    // Remove from library's linked list
    if (pTknFontLibrary->pTknFont == pTknFont)
    {
        pTknFontLibrary->pTknFont = pTknFont->pNext;
    }
    else
    {
        TknFont *pPrev = pTknFontLibrary->pTknFont;
        while (pPrev && pPrev->pNext != pTknFont)
        {
            pPrev = pPrev->pNext;
        }
        if (pPrev)
        {
            pPrev->pNext = pTknFont->pNext;
        }
    }

    for (uint32_t i = 0; i < pTknFont->tknCharCapacity; i++)
    {
        TknChar *pCurrent = pTknFont->tknCharPtrs[i];
        while (pCurrent)
        {
            TknChar *pNext = pCurrent->pNext;

            if (pCurrent->bitmapBuffer)
            {
                tknFree(pCurrent->bitmapBuffer);
            }

            tknFree(pCurrent);
            pCurrent = pNext;
        }
    }

    FT_Done_Face(pTknFont->ftFace);
    tknFree(pTknFont->tknCharPtrs);
    tknDestroyImagePtr(pTknGfxContext, pTknFont->pTknImage);
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

void destroyTknFontLibraryPtr(TknFontLibrary *pTknFontLibrary, TknGfxContext *pTknGfxContext)
{
    while (pTknFontLibrary->pTknFont)
    {
        destroyTknFontPtr(pTknFontLibrary, pTknFontLibrary->pTknFont, pTknGfxContext);
    }
    FT_Done_FreeType(pTknFontLibrary->ftLibrary);
    tknFree(pTknFontLibrary);
}
