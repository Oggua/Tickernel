#include "gfxCore.h"

DrawCall *createDrawCallPtr(GfxContext *pGfxContext, Pipeline *pPipeline, Material *pMaterial, Mesh *pMesh, Instance *pInstance)
{
    // Validate DrawCall compatibility with Pipeline
    if (pPipeline->pMeshVertexInputLayout != NULL)
    {
        tknAssert(pMesh != NULL, "DrawCall must have a Mesh when Pipeline requires mesh vertex input layout");
        tknAssert(pMesh->pVertexInputLayout == pPipeline->pMeshVertexInputLayout, "DrawCall Mesh vertex input layout must match Pipeline mesh vertex input layout");
    }
    else
    {
        tknAssert(pMesh == NULL, "DrawCall must not have a Mesh when Pipeline does not require mesh vertex input layout");
    }

    if (pPipeline->pInstanceVertexInputLayout != NULL)
    {
        tknAssert(pInstance != NULL, "DrawCall must have an Instance when Pipeline requires instance vertex input layout");
        tknAssert(pInstance->pVertexInputLayout == pPipeline->pInstanceVertexInputLayout, "DrawCall Instance vertex input layout must match Pipeline instance vertex input layout");
    }
    else
    {
        tknAssert(pInstance == NULL, "DrawCall must not have an Instance when Pipeline does not require instance vertex input layout");
    }

    // Validate Material compatibility
    tknAssert(pMaterial != NULL, "DrawCall must have a Material");
    tknAssert(pMaterial->pDescriptorSet == pPipeline->pPipelineDescriptorSet, "DrawCall Material descriptor set must match Pipeline descriptor set");

    DrawCall *pDrawCall = tknMalloc(sizeof(DrawCall));
    *pDrawCall = (DrawCall){
        .pPipeline = pPipeline,
        .pMaterial = pMaterial,
        .pInstance = pInstance,
        .pMesh = pMesh,
    };
    if (pMaterial != NULL)
        tknAddToHashSet(&pMaterial->drawCallPtrHashSet, &pDrawCall);
    if (pInstance != NULL)
        tknAddToHashSet(&pInstance->drawCallPtrHashSet, &pDrawCall);
    if (pMesh != NULL)
        tknAddToHashSet(&pMesh->drawCallPtrHashSet, &pDrawCall);

    // Add to pipeline hashset only (dynamic array management is handled by addDrawCallToPipeline)
    tknAddToHashSet(&pPipeline->drawCallPtrHashSet, &pDrawCall);

    return pDrawCall;
}

void destroyDrawCallPtr(GfxContext *pGfxContext, DrawCall *pDrawCall)
{
    // Remove from subpass drawcall queue
    if (pDrawCall->pPipeline != NULL)
    {
        RenderPass *pRenderPass = pDrawCall->pPipeline->pRenderPass;
        struct Subpass *pSubpass = &pRenderPass->subpasses[pDrawCall->pPipeline->subpassIndex];
        tknRemoveFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, &pDrawCall);
        tknRemoveFromHashSet(&pDrawCall->pPipeline->drawCallPtrHashSet, &pDrawCall);
    }
    if (pDrawCall->pMaterial != NULL)
        tknRemoveFromHashSet(&pDrawCall->pMaterial->drawCallPtrHashSet, &pDrawCall);
    if (pDrawCall->pInstance != NULL)
        tknRemoveFromHashSet(&pDrawCall->pInstance->drawCallPtrHashSet, &pDrawCall);
    if (pDrawCall->pMesh != NULL)
        tknRemoveFromHashSet(&pDrawCall->pMesh->drawCallPtrHashSet, &pDrawCall);
    *pDrawCall = (DrawCall){0};
    tknFree(pDrawCall);
}

void insertDrawCallPtr(DrawCall *pDrawCall, uint32_t index)
{
    tknAssert(pDrawCall->pPipeline != NULL, "DrawCall must be associated with a Pipeline");
    RenderPass *pRenderPass = pDrawCall->pPipeline->pRenderPass;
    struct Subpass *pSubpass = &pRenderPass->subpasses[pDrawCall->pPipeline->subpassIndex];
    tknInsertIntoDynamicArray(&pSubpass->drawCallPtrDynamicArray, &pDrawCall, index);
}

void removeDrawCallPtr(DrawCall *pDrawCall)
{
    tknAssert(pDrawCall->pPipeline != NULL, "DrawCall must be associated with a Pipeline");
    RenderPass *pRenderPass = pDrawCall->pPipeline->pRenderPass;
    struct Subpass *pSubpass = &pRenderPass->subpasses[pDrawCall->pPipeline->subpassIndex];
    tknRemoveFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, &pDrawCall);
    // Keep pipeline reference for hashset relationship tracking
}

void removeDrawCallAtIndex(RenderPass *pRenderPass, uint32_t subpassIndex, uint32_t index)
{
    tknAssert(subpassIndex < pRenderPass->subpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct Subpass *pSubpass = &pRenderPass->subpasses[subpassIndex];
    if (index >= pSubpass->drawCallPtrDynamicArray.count)
    {
        return;
    }
    DrawCall *pDrawCall = *(DrawCall **)tknGetFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, index);
    destroyDrawCallPtr(NULL, pDrawCall);
}

DrawCall *getDrawCallAtIndex(RenderPass *pRenderPass, uint32_t subpassIndex, uint32_t index)
{
    tknAssert(subpassIndex < pRenderPass->subpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct Subpass *pSubpass = &pRenderPass->subpasses[subpassIndex];
    if (index >= pSubpass->drawCallPtrDynamicArray.count)
    {
        return NULL;
    }
    return *(DrawCall **)tknGetFromDynamicArray(&pSubpass->drawCallPtrDynamicArray, index);
}

uint32_t getDrawCallCount(RenderPass *pRenderPass, uint32_t subpassIndex)
{
    tknAssert(subpassIndex < pRenderPass->subpassCount, "Subpass index %u out of bounds", subpassIndex);
    struct Subpass *pSubpass = &pRenderPass->subpasses[subpassIndex];
    return pSubpass->drawCallPtrDynamicArray.count;
}
