#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>

#include "tkn.h"
#define TKN_CLAMP(x, min, max) \
    ((x) < (min) ? (min) : ((x) > (max) ? (max) : (x)))

#define TKN_DEFAULT_COLLECTION_SIZE 8
#define TKN_DEFAULT_COLLECTION_POWER_OF_TWO 7
#define TKN_MIN_COLLECTION_SIZE 1

typedef struct
{
    uint32_t maxCount;
    uint32_t count;
    size_t dataSize;
    void *array;
} TknDynamicArray;

typedef struct TknListNode
{
    void *data;
    struct TknListNode *pNextNode;
} TknListNode;

typedef struct
{
    uint32_t powerOfTwo;
    uint32_t capacity;
    uint32_t count;
    size_t dataSize;
    TknListNode **nodePtrs;
} TknHashSet;

TknHashSet tknCreateHashSet(size_t dataSize);
void tknDestroyHashSet(TknHashSet tknHashSet);
bool tknAddToHashSet(TknHashSet *pTknHashSet, const void *pData);
bool tknContainsInHashSet(TknHashSet *pTknHashSet, const void *pData);
void tknRemoveFromHashSet(TknHashSet *pTknHashSet, const void *pData);
void tknClearHashSet(TknHashSet *pTknHashSet);

TknDynamicArray tknCreateDynamicArray(size_t dataSize, uint32_t maxCount);
void tknDestroyDynamicArray(TknDynamicArray tknDynamicArray);
void tknInsertIntoDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData, uint32_t index);
void tknAddToDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData);
void tknRemoveFromDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData);
void tknRemoveAtIndexFromDynamicArray(TknDynamicArray *pTknDynamicArray, uint32_t index);
void tknClearDynamicArray(TknDynamicArray *pTknDynamicArray);
void *tknGetFromDynamicArray(TknDynamicArray *pTknDynamicArray, uint32_t index);
bool tknContainsInDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData);
