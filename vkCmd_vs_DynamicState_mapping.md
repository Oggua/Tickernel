# Vulkan 1.0 vkCmd Complete Parameter Reference

## Vulkan 1.0 Core Commands

### Viewport and Scissor

| vkCmd | VkDynamicState | Parameter List |
|------|------------------|--------|
| `vkCmdSetViewport` | `VK_DYNAMIC_STATE_VIEWPORT` | `(VkCommandBuffer commandBuffer, uint32_t firstViewport, uint32_t viewportCount, const VkViewport* pViewports)` |
| `vkCmdSetScissor` | `VK_DYNAMIC_STATE_SCISSOR` | `(VkCommandBuffer commandBuffer, uint32_t firstScissor, uint32_t scissorCount, const VkRect2D* pScissors)` |

### Rasterization State

| vkCmd | VkDynamicState | Parameter List |
|------|------------------|--------|
| `vkCmdSetLineWidth` | `VK_DYNAMIC_STATE_LINE_WIDTH` | `(VkCommandBuffer commandBuffer, float lineWidth)` |
| `vkCmdSetDepthBias` | `VK_DYNAMIC_STATE_DEPTH_BIAS` | `(VkCommandBuffer commandBuffer, float depthBiasConstantFactor, float depthBiasClamp, float depthBiasSlopeFactor)` |

### Depth Testing

| vkCmd | VkDynamicState | Parameter List |
|------|------------------|--------|
| `vkCmdSetDepthBounds` | `VK_DYNAMIC_STATE_DEPTH_BOUNDS` | `(VkCommandBuffer commandBuffer, float minDepthBounds, float maxDepthBounds)` |

### Stencil Testing

| vkCmd | VkDynamicState | Parameter List |
|------|------------------|--------|
| `vkCmdSetStencilCompareMask` | `VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK` | `(VkCommandBuffer commandBuffer, VkStencilFaceFlags faceMask, uint32_t compareMask)` |
| `vkCmdSetStencilWriteMask` | `VK_DYNAMIC_STATE_STENCIL_WRITE_MASK` | `(VkCommandBuffer commandBuffer, VkStencilFaceFlags faceMask, uint32_t writeMask)` |
| `vkCmdSetStencilReference` | `VK_DYNAMIC_STATE_STENCIL_REFERENCE` | `(VkCommandBuffer commandBuffer, VkStencilFaceFlags faceMask, uint32_t reference)` |

### Blending

| vkCmd | VkDynamicState | Parameter List |
|------|------------------|--------|
| `vkCmdSetBlendConstants` | `VK_DYNAMIC_STATE_BLEND_CONSTANTS` | `(VkCommandBuffer commandBuffer, const float blendConstants[4])` |

---

## 📊 Statistics

| Category | Count |
|----------|-------|
| **vkCmd Functions** | 9 |
| **VkDynamicState Enums** | 9 |

---

## 📝 Parameter Explanation

### Common Parameters
- `VkCommandBuffer commandBuffer` - Target command buffer

### Command-Specific Parameter Details

**vkCmdSetViewport / vkCmdSetScissor**
- `uint32_t first*` - Starting index
- `uint32_t *Count` - Number of items to set
- `const VkViewport* / const VkRect2D*` - Pointer to data

**vkCmdSetDepthBias**
- `depthBiasConstantFactor` - Constant factor for depth bias
- `depthBiasClamp` - Clamp value for depth bias
- `depthBiasSlopeFactor` - Slope factor for depth bias

**vkCmdSetStencil\***
- `VkStencilFaceFlags faceMask` - Face mask (front/back/both)
- `uint32_t compareMask / writeMask / reference` - Corresponding stencil values

**vkCmdSetBlendConstants**
- `const float blendConstants[4]` - RGBA blend constant values