#include "gfxCore.h"

TknDrawCall *createDrawCallPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline, TknMaterial *pTknMaterial, TknMesh *pTknMesh, TknInstance *pTknInstance)
{
    // Validate TknDrawCall compatibility with TknPipeline
    if (pTknPipeline->pTknMeshVertexInputLayout != NULL)
    {
        tknAssert(pTknMesh != NULL, "TknDrawCall must have a TknMesh when TknPipeline requires mesh vertex input layout");
        tknAssert(pTknMesh->pTknVertexInputLayout == pTknPipeline->pTknMeshVertexInputLayout, "TknDrawCall TknMesh vertex input layout must match TknPipeline mesh vertex input layout");
    }
    else
    {
        tknAssert(pTknMesh == NULL, "TknDrawCall must not have a TknMesh when TknPipeline does not require mesh vertex input layout");
    }

    if (pTknPipeline->pTknInstanceVertexInputLayout != NULL)
    {
        tknAssert(pTknInstance != NULL, "TknDrawCall must have an TknInstance when TknPipeline requires instance vertex input layout");
        tknAssert(pTknInstance->pTknVertexInputLayout == pTknPipeline->pTknInstanceVertexInputLayout, "TknDrawCall TknInstance vertex input layout must match TknPipeline instance vertex input layout");
    }
    else
    {
        tknAssert(pTknInstance == NULL, "TknDrawCall must not have an TknInstance when TknPipeline does not require instance vertex input layout");
    }

    // Validate TknMaterial compatibility
    tknAssert(pTknMaterial != NULL, "TknDrawCall must have a TknMaterial");
    tknAssert(pTknMaterial->pDescriptorSet == pTknPipeline->pPipelineDescriptorSet, "TknDrawCall TknMaterial descriptor set must match TknPipeline descriptor set");

    TknDrawCall *pTknDrawCall = tknMalloc(sizeof(TknDrawCall));
    *pTknDrawCall = (TknDrawCall){
        .pTknPipeline = pTknPipeline,
        .pTknMaterial = pTknMaterial,
        .pTknInstance = pTknInstance,
        .pTknMesh = pTknMesh,
    };
    if (pTknMaterial != NULL)
        tknAddToHashSet(&pTknMaterial->drawCallPtrHashSet, &pTknDrawCall);
    if (pTknInstance != NULL)
        tknAddToHashSet(&pTknInstance->drawCallPtrHashSet, &pTknDrawCall);
    if (pTknMesh != NULL)
        tknAddToHashSet(&pTknMesh->drawCallPtrHashSet, &pTknDrawCall);

    // Add to pipeline hashset only (dynamic array management is handled by addDrawCallToPipeline)
    tknAddToHashSet(&pTknPipeline->drawCallPtrHashSet, &pTknDrawCall);

    return pTknDrawCall;
}

void destroyDrawCallPtr(TknGfxContext *pTknGfxContext, TknDrawCall *pTknDrawCall)
{
    // Remove from subpass drawcall queue
    if (pTknDrawCall->pTknPipeline != NULL)
    {
        TknRenderPass *pTknRenderPass = pTknDrawCall->pTknPipeline->pTknRenderPass;
        struct Subpass *pSubpass = &pTknRenderPass->subpasses[pTknDrawCall->pTknPipeline->subpassIndex];
        tknRemoveFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, &pTknDrawCall);
        tknRemoveFromHashSet(&pTknDrawCall->pTknPipeline->drawCallPtrHashSet, &pTknDrawCall);
    }
    if (pTknDrawCall->pTknMaterial != NULL)
        tknRemoveFromHashSet(&pTknDrawCall->pTknMaterial->drawCallPtrHashSet, &pTknDrawCall);
    if (pTknDrawCall->pTknInstance != NULL)
        tknRemoveFromHashSet(&pTknDrawCall->pTknInstance->drawCallPtrHashSet, &pTknDrawCall);
    if (pTknDrawCall->pTknMesh != NULL)
        tknRemoveFromHashSet(&pTknDrawCall->pTknMesh->drawCallPtrHashSet, &pTknDrawCall);
    *pTknDrawCall = (TknDrawCall){0};
    tknFree(pTknDrawCall);
}

void insertDrawCallPtr(TknDrawCall *pTknDrawCall, uint32_t index)
{
    tknAssert(pTknDrawCall->pTknPipeline != NULL, "TknDrawCall must be associated with a TknPipeline");
    TknRenderPass *pTknRenderPass = pTknDrawCall->pTknPipeline->pTknRenderPass;
    struct Subpass *pSubpass = &pTknRenderPass->subpasses[pTknDrawCall->pTknPipeline->subpassIndex];
    tknInsertIntoDynamicArray(&pSubpass->drawCallPtrDynamicArray, &pTknDrawCall, index);
}

void removeDrawCallPtr(TknDrawCall *pTknDrawCall)
{
    tknAssert(pTknDrawCall->pTknPipeline != NULL, "TknDrawCall must be associated with a TknPipeline");
    TknRenderPass *pTknRenderPass = pTknDrawCall->pTknPipeline->pTknRenderPass;
    struct Subpass *pSubpass = &pTknRenderPass->subpasses[pTknDrawCall->pTknPipeline->subpassIndex];
    tknRemoveFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, &pTknDrawCall);
    // Keep pipeline reference for hashset relationship tracking
}

void removeDrawCallAtIndex(TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t index)
{
    tknAssert(subpassIndex < pTknRenderPass->subpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct Subpass *pSubpass = &pTknRenderPass->subpasses[subpassIndex];
    if (index >= pSubpass->drawCallPtrDynamicArray.count)
    {
        return;
    }
    TknDrawCall *pTknDrawCall = *(TknDrawCall **)tknGetFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, index);
    destroyDrawCallPtr(NULL, pTknDrawCall);
}

TknDrawCall *getDrawCallAtIndex(TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t index)
{
    tknAssert(subpassIndex < pTknRenderPass->subpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct Subpass *pSubpass = &pTknRenderPass->subpasses[subpassIndex];
    if (index >= pSubpass->drawCallPtrDynamicArray.count)
    {
        return NULL;
    }
    return *(TknDrawCall **)tknGetFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, index);
}

uint32_t getDrawCallCount(TknRenderPass *pTknRenderPass, uint32_t subpassIndex)
{
    tknAssert(subpassIndex < pTknRenderPass->subpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct Subpass *pSubpass = &pTknRenderPass->subpasses[subpassIndex];
    return pSubpass->drawCallPtrDynamicArray.count;
}
