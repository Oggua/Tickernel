local tkn = require("tkn")
local colorPreset = require("ui.colorPreset")
local textNode = {}
function textNode.setup(assetsPath)
    textNode.pTknFontLibrary = tkn.tknCreateTknFontLibraryPtr()
    textNode.pathToFont = {}
    textNode.assetsPath = assetsPath
end
function textNode.teardown()
    tkn.tknDestroyTknFontLibraryPtr(textNode.pTknFontLibrary)
    textNode.pTknFontLibrary = nil
    textNode.pathToFont = nil
    textNode.assetsPath = nil
end

function textNode.update(pTknGfxContext)
    for path, font in pairs(textNode.pathToFont) do
        if font.dirty then
            tkn.tknFlushTknFontPtr(font.pTknFont, pTknGfxContext)
        end
        font.dirty = false
    end
end

function textNode.loadFont(pTknGfxContext, relativePath, fontSize, atlasLength, pTknSampler, pTknPipeline)
    local path = textNode.assetsPath .. relativePath
    local font = textNode.pathToFont[path]
    if font then
        if fontSize > font.fontSize then
            tkn.tknDestroyTknFontPtr(textNode.pTknFontLibrary, font.pTknFont, pTknGfxContext)
            local pTknFont, pTknImage = tkn.tknCreateTknFontPtr(textNode.pTknFontLibrary, pTknGfxContext, path, fontSize, atlasLength)
            local inputBindings = {{
                vkDescriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                pTknImage = pTknImage,
                pTknSampler = pTknSampler,
                binding = 0,
            }}
            tkn.tknUpdateMaterialPtr(pTknGfxContext, font.pTknMaterial, inputBindings)
            font.fontSize = fontSize
            font.atlasLength = atlasLength
            font.pTknFont = pTknFont
            font.pTknImage = pTknImage
            font.dirty = true
            return font
        else
            return font
        end
    else
        local pTknFont, pTknImage = tkn.tknCreateTknFontPtr(textNode.pTknFontLibrary, pTknGfxContext, path, fontSize, atlasLength)
        local pTknMaterial = tkn.tknCreatePipelineMaterialPtr(pTknGfxContext, pTknPipeline)
        local inputBindings = {{
            vkDescriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            pTknImage = pTknImage,
            pTknSampler = pTknSampler,
            binding = 0,
        }}
        tkn.tknUpdateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindings)
        local font = {
            path = path,
            fontSize = fontSize,
            atlasLength = atlasLength,
            pTknFont = pTknFont,
            pTknImage = pTknImage,
            pTknMaterial = pTknMaterial,
            dirty = false,
        }
        textNode.pathToFont[path] = font
        return font
    end
end

function textNode.unloadFont(pTknGfxContext, font)
    textNode.pathToFont[font.path] = nil
    tkn.tknDestroyPipelineMaterialPtr(pTknGfxContext, font.pTknMaterial)
    tkn.tknDestroyTknFontPtr(textNode.pTknFontLibrary, font.pTknFont, pTknGfxContext)
end

function textNode.setupNode(pTknGfxContext, textString, font, size, color, alphaThreshold, alignH, alignV, bold, pTknMaterial, vertexFormat, instanceFormat, pTknPipeline, node)
    local maxChars = #textString
    -- Bold text needs more vertices (4x for each character)
    local verticesPerChar = bold and 16 or 4
    local indicesPerChar = bold and 24 or 6
    local pTknMesh = tkn.tknCreateDefaultMeshPtr(pTknGfxContext, vertexFormat, vertexFormat.pTknVertexInputLayout, maxChars * verticesPerChar, VK_INDEX_TYPE_UINT16, maxChars * indicesPerChar)

    -- Create instance buffer (mat3 + color)
    local instances = {
        model = {1, 0, 0, 0, 1, 0, 0, 0, 1}, -- identity matrix
        color = {tkn.rgbaToAbgr(color)},
        alphaThreshold = alphaThreshold,
    }
    local pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, instanceFormat.pTknVertexInputLayout, instanceFormat, instances)
    local pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, pTknPipeline, pTknMaterial, pTknMesh, pTknInstance)
    node.text = textString
    node.font = font
    node.size = size
    node.color = color
    node.alphaThreshold = alphaThreshold
    node.alignH = alignH
    node.alignV = alignV
    node.bold = bold
    node.pTknMaterial = pTknMaterial
    node.pTknMesh = pTknMesh
    node.pTknInstance = pTknInstance
    node.pTknDrawCall = pTknDrawCall
    node.type = "textNode"
end

function textNode.teardownNode(pTknGfxContext, node)
    tkn.tknDestroyDrawCallPtr(pTknGfxContext, node.pTknDrawCall)
    tkn.tknDestroyInstancePtr(pTknGfxContext, node.pTknInstance)
    tkn.tknDestroyMeshPtr(pTknGfxContext, node.pTknMesh)
    node.pTknMaterial = nil
    node.pTknMesh = nil
    node.pTknInstance = nil
    node.pTknDrawCall = nil
    node.font = nil
    node.text = ""
    node.size = 0
    node.color = colorPreset.white
    node.alignH = 0
    node.alignV = 0
    node.bold = false
    node.type = nil
end

function textNode.updateMeshPtr(pTknGfxContext, node, vertexFormat, screenWidth, screenHeight, boundsDirty, screenSizeDirty)
    if boundsDirty or screenSizeDirty or node.font.dirty then
        local rect = node.rect
        -- rect.horizontal/vertical.min/max are already relative to pivot (0, 0)
        local rectWidth = rect.horizontal.max - rect.horizontal.min
        local rectHeight = rect.vertical.max - rect.vertical.min

        local font = node.font
        local sizeScale = node.size / font.fontSize
        local scaleX = sizeScale / screenWidth * 2
        local scaleY = sizeScale / screenHeight * 2
        local lineHeight = node.size / screenHeight * 2
        local atlasScale = 1 / font.atlasLength

        -- Bold offset in pixels (converted to NDC)
        local boldOffsetX = node.bold and (1 / screenWidth * 2) or 0
        local boldOffsetY = node.bold and (1 / screenHeight * 2) or 0

        -- Local coordinate bounds (already relative to pivot)
        local left = rect.horizontal.min
        local right = rect.horizontal.max
        local top = rect.vertical.min
        local bottom = rect.vertical.max

        -- First pass: calculate line widths and total text bounds
        local lines = {{
            chars = {},
            width = 0,
        }}
        local currentLine = lines[1]
        local penX = 0

        for pos, code in utf8.codes(node.text) do
            local pTknChar, x, y, width, height, bearingX, bearingY, advance = tkn.tknLoadTknChar(font.pTknFont, code)

            if pTknChar then
                local widthNDC = width * scaleX
                local heightNDC = height * scaleY
                local bearingXNDC = bearingX * scaleX
                local bearingYNDC = bearingY * scaleY
                local advanceNDC = advance * scaleX

                -- Word wrap check (use local width)
                if penX + bearingXNDC + widthNDC > rectWidth and #currentLine.chars > 0 then
                    currentLine.width = penX
                    currentLine = {
                        chars = {},
                        width = 0,
                    }
                    table.insert(lines, currentLine)
                    penX = 0
                end

                table.insert(currentLine.chars, {
                    x = x,
                    y = y,
                    width = width,
                    height = height,
                    bearingX = bearingX,
                    bearingY = bearingY,
                    advance = advance,
                    widthNDC = widthNDC,
                    heightNDC = heightNDC,
                    bearingXNDC = bearingXNDC,
                    bearingYNDC = bearingYNDC,
                    advanceNDC = advanceNDC,
                    penX = penX,
                })

                penX = penX + advanceNDC
            end
        end

        currentLine.width = penX

        -- Calculate starting Y position based on vertical alignment
        local totalHeight = #lines * lineHeight
        local startY = top + (rectHeight - totalHeight) * node.alignV + lineHeight

        -- Second pass: generate vertices with alignment
        local vertices = {
            position = {},
            uv = {},
        }
        local indices = {}
        local charIndex = 0
        local penY = startY

        for lineIdx, line in ipairs(lines) do
            -- Calculate starting X position based on horizontal alignment
            local startX = left + (rectWidth - line.width) * node.alignH

            for _, char in ipairs(line.chars) do
                local charLeft = startX + char.penX + char.bearingXNDC
                local charRight = charLeft + char.widthNDC
                local charTop = penY - char.bearingYNDC
                local charBottom = charTop + char.heightNDC

                -- Uv coordinates
                local u0, v0 = char.x * atlasScale, char.y * atlasScale
                local u1, v1 = (char.x + char.width) * atlasScale, (char.y + char.height) * atlasScale

                -- Helper function to add a character quad
                local function addCharQuad(offsetX, offsetY)
                    local l, r = charLeft + offsetX, charRight + offsetX
                    local t, b = charTop + offsetY, charBottom + offsetY

                    -- Vertices (positions)
                    local pos = vertices.position
                    pos[#pos + 1], pos[#pos + 2] = l, t
                    pos[#pos + 1], pos[#pos + 2] = r, t
                    pos[#pos + 1], pos[#pos + 2] = r, b
                    pos[#pos + 1], pos[#pos + 2] = l, b

                    -- Uvs
                    local uv = vertices.uv
                    uv[#uv + 1], uv[#uv + 2] = u0, v0
                    uv[#uv + 1], uv[#uv + 2] = u1, v0
                    uv[#uv + 1], uv[#uv + 2] = u1, v1
                    uv[#uv + 1], uv[#uv + 2] = u0, v1

                    -- Indices
                    local base = charIndex * 4
                    local idx = indices
                    idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = base, base + 1, base + 2
                    idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = base + 2, base + 3, base

                    charIndex = charIndex + 1
                end

                -- Render character (multiple times if bold)
                if node.bold then
                    addCharQuad(0, 0)
                    addCharQuad(boldOffsetX, 0)
                    addCharQuad(0, boldOffsetY)
                    addCharQuad(boldOffsetX, boldOffsetY)
                else
                    addCharQuad(0, 0)
                end
            end

            penY = penY + lineHeight
        end

        tkn.tknFlushTknFontPtr(font.pTknFont, pTknGfxContext)

        if charIndex > 0 then
            tkn.tknUpdateMeshPtr(pTknGfxContext, node.pTknMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
        end
    end
end

return textNode
