#include "tkn.h"
#include "lualib.h"
#include <ft2build.h>
#include FT_FREETYPE_H

typedef struct TknChar
{
    uint32_t unicode;
    uint32_t x, y;
    uint32_t width, height;
    int32_t bearingX, bearingY;
    uint32_t advance;
    
    // Cached bitmap data for batch upload
    unsigned char *bitmapBuffer;
    uint32_t bitmapSize;
    
    struct TknChar *pNext;
    struct TknChar *pNextDirty;
} TknChar;

typedef struct TknFont
{
    FT_Face ftFace;
    uint32_t tknCharCapacity;
    uint32_t tknCharCount;
    TknChar **tknCharPtrs;
    uint32_t dirtyTknCharPtrCount;
    TknChar *pDirtyTknChar;
    Image *pImage;
    uint32_t atlasLength;
    uint32_t penX, penY;
    uint32_t maxRowHeight;

    struct TknFont *pNext;
} TknFont;

typedef struct
{
    FT_Library ftLibrary;
    TknFont *pTknFont;
} TknFontLibrary;

TknFontLibrary *createTknFontLibraryPtr();
void destroyTknFontLibraryPtr(TknFontLibrary *pTknFontLibrary, GfxContext *pGfxContext);

TknChar *loadTknChar(TknFont *pTknFont, uint32_t unicode);
void flushTknFontPtr(TknFont *pTknFont, GfxContext *pGfxContext);

TknFont *createTknFontPtr(TknFontLibrary *pTknFontLibrary, GfxContext *pGfxContext, const char *fontPath, uint32_t fontSize, uint32_t atlasLength);
void destroyTknFontPtr(TknFont *pTknFont, GfxContext *pGfxContext);
