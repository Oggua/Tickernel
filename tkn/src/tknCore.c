#include "tknCore.h"

static void tknInternalError(const char *prefix, const char *format, va_list args)
{
    if (prefix)
    {
        fprintf(stderr, "%s: ", prefix);
    }
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");

    abort();
}

void tknWarning(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    fprintf(stderr, "WARNING: ");
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
}

void tknError(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    tknInternalError("ERROR: ", format, args);
    va_end(args);
}

void tknAssert(bool condition, const char *format, ...)
{
    if (!condition)
    {
        va_list args;
        va_start(args, format);
        tknInternalError("ASSERTION FAILED: ", format, args);
        va_end(args);
    }
}

// static int allocTimes = 0;

void *tknMalloc(size_t size)
{
    return malloc(size);
}

void tknFree(void *ptr)
{
    free(ptr);
}

TknDynamicArray tknCreateDynamicArray(size_t dataSize, uint32_t maxCount)
{
    TknDynamicArray tknDynamicArray = {
        .maxCount = maxCount,
        .count = 0,
        .dataSize = dataSize,
        .array = tknMalloc(dataSize * maxCount)};
    memset(tknDynamicArray.array, 0, dataSize * maxCount);
    return tknDynamicArray;
}
void tknDestroyDynamicArray(TknDynamicArray tknDynamicArray)
{
    tknFree(tknDynamicArray.array);
    tknDynamicArray.array = NULL;
    tknDynamicArray.count = 0;
    tknDynamicArray.maxCount = 0;
}
void tknInsertIntoDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData, uint32_t index)
{
    tknAssert(index >= 0 && index <= pTknDynamicArray->count, "Index %u is out of bounds for count %u\n", index, pTknDynamicArray->count);
    if (pTknDynamicArray->count >= pTknDynamicArray->maxCount)
    {
        pTknDynamicArray->maxCount *= 2;
        void *newArray;
        newArray = tknMalloc(pTknDynamicArray->dataSize * pTknDynamicArray->maxCount);
        memcpy(newArray, pTknDynamicArray->array, pTknDynamicArray->dataSize * pTknDynamicArray->count);
        tknFree(pTknDynamicArray->array);
        pTknDynamicArray->array = newArray;
    }
    void *targetAddress = (char *)pTknDynamicArray->array + index * pTknDynamicArray->dataSize;
    if (index < pTknDynamicArray->count)
    {
        memmove(
            (char *)pTknDynamicArray->array + (index + 1) * pTknDynamicArray->dataSize,
            targetAddress,
            (pTknDynamicArray->count - index) * pTknDynamicArray->dataSize);
    }
    memcpy(targetAddress, pData, pTknDynamicArray->dataSize);
    pTknDynamicArray->count++;
}
void tknAddToDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData)
{
    tknInsertIntoDynamicArray(pTknDynamicArray, pData, pTknDynamicArray->count);
}
void tknRemoveFromDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData)
{
    for (uint32_t i = 0; i < pTknDynamicArray->count; i++)
    {
        void *currentElement = (char *)pTknDynamicArray->array + i * pTknDynamicArray->dataSize;
        if (memcmp(currentElement, pData, pTknDynamicArray->dataSize) == 0)
        {
            if (i < pTknDynamicArray->count - 1)
            {
                memmove(
                    currentElement,
                    (char *)pTknDynamicArray->array + (i + 1) * pTknDynamicArray->dataSize,
                    (pTknDynamicArray->count - i - 1) * pTknDynamicArray->dataSize);
            }
            pTknDynamicArray->count--;
            return;
        }
    }
    tknError("Data not found!\n");
}
void tknRemoveAtIndexFromDynamicArray(TknDynamicArray *pTknDynamicArray, uint32_t index)
{
    tknAssert(index < pTknDynamicArray->count, "Index %u is out of bounds for count %u\n", index, pTknDynamicArray->count);
    void *target = (char *)pTknDynamicArray->array + index * pTknDynamicArray->dataSize;
    if (index < pTknDynamicArray->count - 1)
    {
        memmove(
            target,
            (char *)pTknDynamicArray->array + (index + 1) * pTknDynamicArray->dataSize,
            (pTknDynamicArray->count - index - 1) * pTknDynamicArray->dataSize);
    }
    pTknDynamicArray->count--;
}
void tknClearDynamicArray(TknDynamicArray *pTknDynamicArray)
{
    pTknDynamicArray->count = 0;
    memset(pTknDynamicArray->array, 0, pTknDynamicArray->dataSize * pTknDynamicArray->maxCount);
}
void *tknGetFromDynamicArray(TknDynamicArray *pTknDynamicArray, uint32_t index)
{
    if (index < pTknDynamicArray->count)
    {
        void *output = (char *)pTknDynamicArray->array + index * pTknDynamicArray->dataSize;
        return output;
    }
    else
    {
        printf("Index %u is out of bounds for count %u\n", index, pTknDynamicArray->count);
        return NULL;
    }
}
bool tknContainsInDynamicArray(TknDynamicArray *pTknDynamicArray, void *pData)
{
    if (NULL == pTknDynamicArray || NULL == pData || 0 == pTknDynamicArray->count)
    {
        return false;
    }
    uint8_t *arrayData = (uint8_t *)pTknDynamicArray->array;
    for (uint32_t i = 0; i < pTknDynamicArray->count; i++)
    {
        void *currentElement = arrayData + (i * pTknDynamicArray->dataSize);
        if (memcmp(currentElement, pData, pTknDynamicArray->dataSize) == 0)
        {
            return true;
        }
    }
    return false;
}

TknHashSet tknCreateHashSet(size_t dataSize)
{
    uint32_t capacity = 1u << TKN_DEFAULT_COLLECTION_POWER_OF_TWO;
    TknHashSet tknHashSet = {
        .capacity = capacity,
        .count = 0,
        .dataSize = dataSize,
        .nodePtrs = tknMalloc(sizeof(TknListNode *) * capacity),
    };
    memset(tknHashSet.nodePtrs, 0, sizeof(TknListNode *) * capacity);
    return tknHashSet;
}

void tknDestroyHashSet(TknHashSet tknHashSet)
{
    tknClearHashSet(&tknHashSet);
    tknFree(tknHashSet.nodePtrs);
    tknHashSet.nodePtrs = NULL;
    tknHashSet.capacity = 0;
    tknHashSet.count = 0;
    tknHashSet.dataSize = 0;
}

bool tknAddToHashSet(TknHashSet *pTknHashSet, const void *pData)
{
    if (pTknHashSet->count >= pTknHashSet->capacity * 3 / 4)
    {
        uint32_t newCapacity = pTknHashSet->capacity * 2;
        TknListNode **newNodePtrs = tknMalloc(sizeof(TknListNode *) * newCapacity);
        memset(newNodePtrs, 0, sizeof(TknListNode *) * newCapacity);
        for (uint32_t i = 0; i < pTknHashSet->capacity; i++)
        {
            TknListNode *node = pTknHashSet->nodePtrs[i];
            while (node)
            {
                size_t newIndex = 0;
                memcpy(&newIndex, node->data, sizeof(newIndex) < pTknHashSet->dataSize ? sizeof(newIndex) : pTknHashSet->dataSize);
                newIndex &= (newCapacity - 1);

                TknListNode *nextNode = node->pNextNode;
                node->pNextNode = newNodePtrs[newIndex];
                newNodePtrs[newIndex] = node;
                node = nextNode;
            }
        }
        tknFree(pTknHashSet->nodePtrs);
        pTknHashSet->nodePtrs = newNodePtrs;
        pTknHashSet->capacity = newCapacity;
    }

    size_t index = 0;
    memcpy(&index, pData, sizeof(index) < pTknHashSet->dataSize ? sizeof(index) : pTknHashSet->dataSize);
    index &= (pTknHashSet->capacity - 1);

    TknListNode *node = pTknHashSet->nodePtrs[index];
    while (node)
    {
        if (memcmp(node->data, pData, pTknHashSet->dataSize) == 0)
            return false;
        node = node->pNextNode;
    }
    TknListNode *newNode = tknMalloc(sizeof(TknListNode));
    newNode->data = tknMalloc(pTknHashSet->dataSize);
    memcpy(newNode->data, pData, pTknHashSet->dataSize);
    newNode->pNextNode = pTknHashSet->nodePtrs[index];
    pTknHashSet->nodePtrs[index] = newNode;
    pTknHashSet->count++;
    return true;
}

bool tknContainsInHashSet(TknHashSet *pTknHashSet, const void *pData)
{
    size_t index = 0;
    memcpy(&index, pData, sizeof(index) < pTknHashSet->dataSize ? sizeof(index) : pTknHashSet->dataSize);
    index &= (pTknHashSet->capacity - 1);

    TknListNode *node = pTknHashSet->nodePtrs[index];
    while (node)
    {
        if (memcmp(node->data, pData, pTknHashSet->dataSize) == 0)
            return true;
        node = node->pNextNode;
    }
    return false;
}

void tknRemoveFromHashSet(TknHashSet *pTknHashSet, const void *pData)
{
    size_t index = 0;
    memcpy(&index, pData, sizeof(index) < pTknHashSet->dataSize ? sizeof(index) : pTknHashSet->dataSize);
    index &= (pTknHashSet->capacity - 1);

    TknListNode *node = pTknHashSet->nodePtrs[index];
    TknListNode *prevNode = NULL;
    while (node)
    {
        if (memcmp(node->data, pData, pTknHashSet->dataSize) == 0)
        {
            if (prevNode)
                prevNode->pNextNode = node->pNextNode;
            else
                pTknHashSet->nodePtrs[index] = node->pNextNode;
            tknFree(node->data);
            tknFree(node);
            pTknHashSet->count--;
            return;
        }
        prevNode = node;
        node = node->pNextNode;
    }
}

void tknClearHashSet(TknHashSet *pTknHashSet)
{
    for (size_t i = 0; i < pTknHashSet->capacity; i++)
    {
        TknListNode *node = pTknHashSet->nodePtrs[i];
        while (node)
        {
            TknListNode *nextNode = node->pNextNode;
            tknFree(node->data);
            tknFree(node);
            node = nextNode;
        }
        pTknHashSet->nodePtrs[i] = NULL;
    }
    pTknHashSet->count = 0;
}
