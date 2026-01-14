#include "tknGfxCore.h"

TknDrawCall *tknCreateDrawCallPtr(TknGfxContext *pTknGfxContext, TknPipeline *pTknPipeline, TknMaterial *pTknMaterial, TknMesh *pTknMesh, TknInstance *pTknInstance)
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
    tknAssert(pTknMaterial->pTknDescriptorSet == pTknPipeline->pTknPipelineDescriptorSet, "TknDrawCall TknMaterial descriptor set must match TknPipeline descriptor set");

    TknDrawCall *pTknDrawCall = tknMalloc(sizeof(TknDrawCall));
    *pTknDrawCall = (TknDrawCall){
        .pTknPipeline = pTknPipeline,
        .pTknMaterial = pTknMaterial,
        .pTknInstance = pTknInstance,
        .pTknMesh = pTknMesh,
    };
    if (pTknMaterial != NULL)
        tknAddToHashSet(&pTknMaterial->tknDrawCallPtrHashSet, &pTknDrawCall);
    if (pTknInstance != NULL)
        tknAddToHashSet(&pTknInstance->tknDrawCallPtrHashSet, &pTknDrawCall);
    if (pTknMesh != NULL)
        tknAddToHashSet(&pTknMesh->tknDrawCallPtrHashSet, &pTknDrawCall);

    // Add to pipeline hashset only (dynamic array management is handled by addDrawCallToPipeline)
    tknAddToHashSet(&pTknPipeline->tknDrawCallPtrHashSet, &pTknDrawCall);

    return pTknDrawCall;
}

void tknDestroyDrawCallPtr(TknGfxContext *pTknGfxContext, TknDrawCall *pTknDrawCall)
{
    // Remove from subpass drawcall queue
    if (pTknDrawCall->pTknPipeline != NULL)
    {
        TknRenderPass *pTknRenderPass = pTknDrawCall->pTknPipeline->pTknRenderPass;
        struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[pTknDrawCall->pTknPipeline->subpassIndex];
        tknRemoveFromDynamicArray(&pTknSubpass->tknDrawCallPtrDynamicArray, &pTknDrawCall);
        tknRemoveFromHashSet(&pTknDrawCall->pTknPipeline->tknDrawCallPtrHashSet, &pTknDrawCall);
    }
    if (pTknDrawCall->pTknMaterial != NULL)
        tknRemoveFromHashSet(&pTknDrawCall->pTknMaterial->tknDrawCallPtrHashSet, &pTknDrawCall);
    if (pTknDrawCall->pTknInstance != NULL)
        tknRemoveFromHashSet(&pTknDrawCall->pTknInstance->tknDrawCallPtrHashSet, &pTknDrawCall);
    if (pTknDrawCall->pTknMesh != NULL)
        tknRemoveFromHashSet(&pTknDrawCall->pTknMesh->tknDrawCallPtrHashSet, &pTknDrawCall);
    *pTknDrawCall = (TknDrawCall){0};
    tknFree(pTknDrawCall);
}

void tknInsertDrawCallPtr(TknDrawCall *pTknDrawCall, uint32_t index)
{
    tknAssert(pTknDrawCall->pTknPipeline != NULL, "TknDrawCall must be associated with a TknPipeline");
    TknRenderPass *pTknRenderPass = pTknDrawCall->pTknPipeline->pTknRenderPass;
    struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[pTknDrawCall->pTknPipeline->subpassIndex];
    tknInsertIntoDynamicArray(&pTknSubpass->tknDrawCallPtrDynamicArray, &pTknDrawCall, index);
}

void tknRemoveDrawCallPtr(TknDrawCall *pTknDrawCall)
{
    tknAssert(pTknDrawCall->pTknPipeline != NULL, "TknDrawCall must be associated with a TknPipeline");
    TknRenderPass *pTknRenderPass = pTknDrawCall->pTknPipeline->pTknRenderPass;
    struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[pTknDrawCall->pTknPipeline->subpassIndex];
    tknRemoveFromDynamicArray(&pTknSubpass->tknDrawCallPtrDynamicArray, &pTknDrawCall);
}

void tknRemoveDrawCallAtIndex(TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t index)
{
    tknAssert(index > 0 && subpassIndex < pTknRenderPass->tknSubpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[subpassIndex];
    tknRemoveAtIndexFromDynamicArray(&pTknSubpass->tknDrawCallPtrDynamicArray, index);
}

TknDrawCall *tknGetDrawCallAtIndex(TknRenderPass *pTknRenderPass, uint32_t subpassIndex, uint32_t index)
{
    tknAssert(subpassIndex < pTknRenderPass->tknSubpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[subpassIndex];
    if (index >= pTknSubpass->tknDrawCallPtrDynamicArray.count)
    {
        return NULL;
    }
    return *(TknDrawCall **)tknGetFromDynamicArray(&pTknSubpass->tknDrawCallPtrDynamicArray, index);
}

uint32_t tknGetDrawCallCount(TknRenderPass *pTknRenderPass, uint32_t subpassIndex)
{
    tknAssert(subpassIndex < pTknRenderPass->tknSubpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct TknSubpass *pTknSubpass = &pTknRenderPass->pTknSubpasses[subpassIndex];
    return pTknSubpass->tknDrawCallPtrDynamicArray.count;
}
