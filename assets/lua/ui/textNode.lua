local tkn = require("tkn")
local vulkan = require("vulkan")
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

function textNode.loadFont(pTknGfxContext, relativePath, fontSize, atlasLength, pTknSampler, pTknPipeline, boldStrengths)
    -- Support both string and table for relativePath
    local fontPaths = {}
    local pathKey = ""

    if type(relativePath) == "table" then
        for i, p in ipairs(relativePath) do
            fontPaths[i] = textNode.assetsPath .. p
        end
        pathKey = table.concat(fontPaths, "|")
    else
        fontPaths[1] = textNode.assetsPath .. relativePath
        pathKey = fontPaths[1]
    end

    local font = textNode.pathToFont[pathKey]
    if font then
        if fontSize > font.fontSize then
            tkn.tknDestroyTknFontPtr(textNode.pTknFontLibrary, font.pTknFont, pTknGfxContext)
            local pTknFont, pTknImage, maxAscender, minDescender = tkn.tknCreateTknFontPtr(textNode.pTknFontLibrary, pTknGfxContext, fontPaths, fontSize, atlasLength, boldStrengths)
            local inputBindings = {{
                vkDescriptorType = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                pTknImage = pTknImage,
                pTknSampler = pTknSampler,
                binding = 0,
            }}
            tkn.tknUpdateMaterialPtr(pTknGfxContext, font.pTknMaterial, inputBindings)
            font.fontSize = fontSize
            font.atlasLength = atlasLength
            font.pTknFont = pTknFont
            font.pTknImage = pTknImage
            font.maxAscender = maxAscender
            font.minDescender = minDescender
            font.dirty = true
            return font
        else
            return font
        end
    else
        local pTknFont, pTknImage, maxAscender, minDescender = tkn.tknCreateTknFontPtr(textNode.pTknFontLibrary, pTknGfxContext, fontPaths, fontSize, atlasLength, boldStrengths)
        local pTknMaterial = tkn.tknCreatePipelineMaterialPtr(pTknGfxContext, pTknPipeline)
        local inputBindings = {{
            vkDescriptorType = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            pTknImage = pTknImage,
            pTknSampler = pTknSampler,
            binding = 0,
        }}
        tkn.tknUpdateMaterialPtr(pTknGfxContext, pTknMaterial, inputBindings)
        local font = {
            path = pathKey,
            fontSize = fontSize,
            atlasLength = atlasLength,
            pTknFont = pTknFont,
            pTknImage = pTknImage,
            pTknMaterial = pTknMaterial,
            dirty = false,
            maxAscender = maxAscender,
            minDescender = minDescender,
        }
        textNode.pathToFont[pathKey] = font
        return font
    end
end

function textNode.unloadFont(pTknGfxContext, font)
    textNode.pathToFont[font.path] = nil
    tkn.tknDestroyPipelineMaterialPtr(pTknGfxContext, font.pTknMaterial)
    tkn.tknDestroyTknFontPtr(textNode.pTknFontLibrary, font.pTknFont, pTknGfxContext)
end

function textNode.setupNode(pTknGfxContext, textString, font, size, color, alphaThreshold, horizontalAlign, verticalAlign, bold, pTknMaterial, vertexFormat, instanceFormat, pTknPipeline, node)
    local maxChars = math.max(#textString, 1)
    -- Bold text needs more vertices (4x for each character)
    local verticesPerChar = bold and 16 or 4
    local indicesPerChar = bold and 24 or 6
    local pTknMesh = tkn.tknCreateDefaultMeshPtr(pTknGfxContext, vertexFormat, vertexFormat.pTknVertexInputLayout, maxChars * verticesPerChar, vulkan.VK_INDEX_TYPE_UINT16, maxChars * indicesPerChar)

    -- Create instance buffer (mat3 + color)
    local instances = {
        model = {1, 0, 0, 0, 1, 0, 0, 0, 1}, -- identity matrix
        color = {tkn.rgbaToAbgr(color)},
        alphaThreshold = alphaThreshold,
    }
    local pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, instanceFormat.pTknVertexInputLayout, instanceFormat, instances)
    local pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, pTknPipeline, pTknMaterial, pTknMesh, pTknInstance)
    node.text = textString
    node.textDirty = true
    node.font = font
    node.size = size
    node.color = color
    node.alphaThreshold = alphaThreshold
    node.horizontalAlign = horizontalAlign
    node.verticalAlign = verticalAlign
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
    node.horizontalAlign = 0
    node.verticalAlign = 0
    node.bold = false
    node.type = nil
    node.textDirty = nil
end

function textNode.setTextString(node, textString)
    node.text = textString
    node.textDirty = true
end

function textNode.measureText(font, text, size, rectWidth, screenWidth, screenHeight)
    local sizeScale = size / font.fontSize
    local scaleX = sizeScale / screenWidth * 2
    local lineHeight = (font.maxAscender - font.minDescender) * sizeScale / screenHeight * 2

    local lineCount = 1
    local penX = 0
    local maxLineWidth = 0

    for pos, code in utf8.codes(text) do
        if code == 10 then -- \n
            if penX > maxLineWidth then
                maxLineWidth = penX
            end
            lineCount = lineCount + 1
            penX = 0
        else
            local pTknChar, hasLoaded, x, y, width, height, bearingX, bearingY, advance = tkn.tknLoadChar(font.pTknFont, code)
            if not hasLoaded then
                font.dirty = true
            end
            if pTknChar then
                local widthNDC = width * scaleX
                local bearingXNDC = bearingX * scaleX
                local advanceNDC = advance * scaleX

                if penX + bearingXNDC + widthNDC > rectWidth and penX > 0 then
                    if penX > maxLineWidth then
                        maxLineWidth = penX
                    end
                    lineCount = lineCount + 1
                    penX = 0
                end

                penX = penX + advanceNDC
            end
        end
    end

    if penX > maxLineWidth then
        maxLineWidth = penX
    end

    return lineCount * lineHeight
end

function textNode.updateMeshPtr(pTknGfxContext, node, vertexFormat, screenWidth, screenHeight, boundsDirty, screenSizeDirty)
    if boundsDirty or screenSizeDirty or node.font.dirty or node.textDirty then
        local rect = node.rect
        -- rect.horizontal/vertical.min/max are already relative to pivot (0, 0)
        local rectWidth = rect.horizontal.max - rect.horizontal.min
        local rectHeight = rect.vertical.max - rect.vertical.min

        local font = node.font
        local sizeScale = node.size / font.fontSize
        local scaleX = sizeScale / screenWidth * 2
        local scaleY = sizeScale / screenHeight * 2
        local lineHeight = (font.maxAscender - font.minDescender) * sizeScale / screenHeight * 2
        local atlasScale = 1 / font.atlasLength

        -- Bold offset in pixels (converted to NDC)
        local boldOffsetX = node.bold and (1 / screenWidth * 2) or 0
        local boldOffsetY = node.bold and (1 / screenHeight * 2) or 0

        -- Local coordinate bounds (already relative to pivot)
        local left = rect.horizontal.min
        local top = rect.vertical.min

        local glyphCache = {}
        local function getGlyph(code)
            local glyph = glyphCache[code]
            if glyph == nil then
                local pTknChar, hasLoaded, x, y, width, height, bearingX, bearingY, advance = tkn.tknLoadChar(font.pTknFont, code)
                if not hasLoaded then
                    font.dirty = true
                end
                if not pTknChar then
                    glyphCache[code] = false
                    return nil
                end
                glyph = {
                    x = x,
                    y = y,
                    width = width,
                    height = height,
                    bearingX = bearingX,
                    bearingY = bearingY,
                    advance = advance,
                }
                glyphCache[code] = glyph
            elseif glyph == false then
                return nil
            end
            return glyph
        end

        -- First pass: calculate line widths
        local lineWidths = {}
        local lineIndex = 1
        local penX = 0
        local lineCharCount = 0

        lineWidths[1] = 0

        for _, code in utf8.codes(node.text) do
            if code == 10 then -- \n
                lineWidths[lineIndex] = penX
                lineIndex = lineIndex + 1
                penX = 0
                lineCharCount = 0
            else
                local glyph = getGlyph(code)
                if glyph then
                    local widthNDC = glyph.width * scaleX
                    local bearingXNDC = glyph.bearingX * scaleX
                    local advanceNDC = glyph.advance * scaleX

                    if penX + bearingXNDC + widthNDC > rectWidth and lineCharCount > 0 then
                        lineWidths[lineIndex] = penX
                        lineIndex = lineIndex + 1
                        penX = 0
                        lineCharCount = 0
                    end

                    penX = penX + advanceNDC
                    lineCharCount = lineCharCount + 1
                end
            end
        end

        lineWidths[lineIndex] = penX
        local lineCount = lineIndex

        -- Second pass: generate vertices with alignment
        local vertices = {
            position = {},
            uv = {},
        }
        local indices = {}
        local charIndex = 0

        local function addQuad(l, r, t, b, u0, v0, u1, v1)
            local pos = vertices.position
            pos[#pos + 1], pos[#pos + 2] = l, t
            pos[#pos + 1], pos[#pos + 2] = r, t
            pos[#pos + 1], pos[#pos + 2] = r, b
            pos[#pos + 1], pos[#pos + 2] = l, b

            local uv = vertices.uv
            uv[#uv + 1], uv[#uv + 2] = u0, v0
            uv[#uv + 1], uv[#uv + 2] = u1, v0
            uv[#uv + 1], uv[#uv + 2] = u1, v1
            uv[#uv + 1], uv[#uv + 2] = u0, v1

            local base = charIndex * 4
            local idx = indices
            idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = base, base + 1, base + 2
            idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = base + 2, base + 3, base

            charIndex = charIndex + 1
        end

        local totalHeight = lineCount * lineHeight
        local penY = top + (rectHeight - totalHeight) * node.verticalAlign + (font.maxAscender * sizeScale / screenHeight * 2)
        lineIndex = 1
        penX = 0
        lineCharCount = 0
        local startX = left + (rectWidth - lineWidths[lineIndex]) * node.horizontalAlign

        for _, code in utf8.codes(node.text) do
            if code == 10 then -- \n
                lineIndex = lineIndex + 1
                penX = 0
                lineCharCount = 0
                penY = penY + lineHeight
                startX = left + (rectWidth - (lineWidths[lineIndex] or 0)) * node.horizontalAlign
            else
                local glyph = getGlyph(code)
                if glyph then
                    local widthNDC = glyph.width * scaleX
                    local heightNDC = glyph.height * scaleY
                    local bearingXNDC = glyph.bearingX * scaleX
                    local bearingYNDC = glyph.bearingY * scaleY
                    local advanceNDC = glyph.advance * scaleX

                    if penX + bearingXNDC + widthNDC > rectWidth and lineCharCount > 0 then
                        lineIndex = lineIndex + 1
                        penX = 0
                        lineCharCount = 0
                        penY = penY + lineHeight
                        startX = left + (rectWidth - (lineWidths[lineIndex] or 0)) * node.horizontalAlign
                    end

                    local charLeft = startX + penX + bearingXNDC
                    local charRight = charLeft + widthNDC
                    local charTop = penY - bearingYNDC
                    local charBottom = charTop + heightNDC

                    local u0, v0 = glyph.x * atlasScale, glyph.y * atlasScale
                    local u1, v1 = (glyph.x + glyph.width) * atlasScale, (glyph.y + glyph.height) * atlasScale

                    if node.bold then
                        addQuad(charLeft, charRight, charTop, charBottom, u0, v0, u1, v1)
                        addQuad(charLeft + boldOffsetX, charRight + boldOffsetX, charTop, charBottom, u0, v0, u1, v1)
                        addQuad(charLeft, charRight, charTop + boldOffsetY, charBottom + boldOffsetY, u0, v0, u1, v1)
                        addQuad(charLeft + boldOffsetX, charRight + boldOffsetX, charTop + boldOffsetY, charBottom + boldOffsetY, u0, v0, u1, v1)
                    else
                        addQuad(charLeft, charRight, charTop, charBottom, u0, v0, u1, v1)
                    end

                    penX = penX + advanceNDC
                    lineCharCount = lineCharCount + 1
                end
            end
        end

        if charIndex > 0 then
            tkn.tknUpdateMeshPtr(pTknGfxContext, node.pTknMesh, vertexFormat, vertices, vulkan.VK_INDEX_TYPE_UINT16, indices)
        end
        node.textDirty = false
    end
end

return textNode
