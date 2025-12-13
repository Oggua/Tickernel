local tkn = require("tkn")
local textComponent = {}

function textComponent.setup(assetPath)
    textComponent.assetsPath = assetPath
    textComponent.pTknFontLibrary = tkn.tknCreateTknFontLibraryPtr()
    textComponent.pool = {}
    textComponent.pathToFont = {}
end

function textComponent.teardown(pTknGfxContext)
    tkn.tknDestroyTknFontLibraryPtr(pTknGfxContext, textComponent.pTknFontLibrary)
    textComponent.pool = nil
    textComponent.pathToFont = nil
    textComponent.pTknFontLibrary = nil
    textComponent.assetsPath = nil
end

function textComponent.update(pTknGfxContext)
    for path, font in pairs(textComponent.pathToFont) do
        if font.dirty then
            tkn.tknFlushTknFontPtr(font.pTknFont, pTknGfxContext)
        end
        font.dirty = false
    end
end

function textComponent.loadFont(pTknGfxContext, path, fontSize, atlasLength, pTknSampler, pTknPipeline)
    print("loadFont")
    local font = textComponent.pathToFont[path]
    if font then
        if fontSize > font.fontSize then
            local fullPath = textComponent.assetsPath .. path
            tkn.tknDestroyTknFontPtr(textComponent.pTknFontLibrary, font.pTknFont, pTknGfxContext)
            local pTknFont, pTknImage = tkn.tknCreateTknFontPtr(textComponent.pTknFontLibrary, pTknGfxContext, fullPath, fontSize, atlasLength)
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
        local fullPath = textComponent.assetsPath .. path
        local pTknFont, pTknImage = tkn.tknCreateTknFontPtr(textComponent.pTknFontLibrary, pTknGfxContext, fullPath, fontSize, atlasLength)
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
        textComponent.pathToFont[path] = font
        return font
    end
end

function textComponent.unloadFont(pTknGfxContext, font)
    print("unloadFont")
    textComponent.pathToFont[font.path] = nil
    tkn.tknDestroyPipelineMaterialPtr(pTknGfxContext, font.pTknMaterial)
    tkn.tknDestroyTknFontPtr(textComponent.pTknFontLibrary, font.pTknFont, pTknGfxContext)
end

function textComponent.createComponent(pTknGfxContext, textString, font, size, color, alignH, alignV, bold, pTknMaterial, vertexFormat, instanceFormat, pTknPipeline, node)
    local maxChars = #textString
    -- Bold text needs more vertices (4x for each character)
    local verticesPerChar = bold and 16 or 4
    local indicesPerChar = bold and 24 or 6
    local pTknMesh = tkn.tknCreateDefaultMeshPtr(pTknGfxContext, vertexFormat, vertexFormat.pTknVertexInputLayout, maxChars * verticesPerChar, VK_INDEX_TYPE_UINT16, maxChars * indicesPerChar)

    -- Create instance buffer (mat3 + color)
    local instances = {
        model = {1, 0, 0, 0, 1, 0, 0, 0, 1}, -- identity matrix
        color = {color},
    }
    local pTknInstance = tkn.tknCreateInstancePtr(pTknGfxContext, instanceFormat.pTknVertexInputLayout, instanceFormat, instances)

    local pTknDrawCall = tkn.tknCreateDrawCallPtr(pTknGfxContext, pTknPipeline, pTknMaterial, pTknMesh, pTknInstance)

    local component = #textComponent.pool > 0 and table.remove(textComponent.pool) or {
        type = "text",
    }
    component.text = textString
    component.font = font
    component.size = size
    component.color = color
    component.alignH = alignH
    component.alignV = alignV
    component.bold = bold
    component.pTknMaterial = pTknMaterial
    component.pTknMesh = pTknMesh
    component.pTknInstance = pTknInstance
    component.pTknDrawCall = pTknDrawCall

    return component
end

function textComponent.destroyComponent(pTknGfxContext, component)
    tkn.tknDestroyDrawCallPtr(pTknGfxContext, component.pTknDrawCall)
    tkn.tknDestroyInstancePtr(pTknGfxContext, component.pTknInstance)
    tkn.tknDestroyMeshPtr(pTknGfxContext, component.pTknMesh)

    component.pTknMaterial = nil
    component.pTknMesh = nil
    component.pTknInstance = nil
    component.pTknDrawCall = nil
    component.font = nil
    component.text = ""
    component.size = 0
    component.color = 0xFFFFFFFF
    component.alignH = 0
    component.alignV = 0
    component.bold = false
    table.insert(textComponent.pool, component)
end

function textComponent.updateMeshPtr(pTknGfxContext, component, rect, vertexFormat, screenWidth, screenHeight)
    -- rect.horizontal/vertical.min/max are already relative to pivot (0, 0)
    local rectWidth = rect.horizontal.max - rect.horizontal.min
    local rectHeight = rect.vertical.max - rect.vertical.min

    local font = component.font
    local sizeScale = component.size / font.fontSize
    local scaleX = sizeScale / screenWidth * 2
    local scaleY = sizeScale / screenHeight * 2
    local lineHeight = component.size / screenHeight * 2
    local atlasScale = 1 / font.atlasLength

    -- Bold offset in pixels (converted to NDC)
    local boldOffsetX = component.bold and (1 / screenWidth * 2) or 0
    local boldOffsetY = component.bold and (1 / screenHeight * 2) or 0

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

    for i = 1, #component.text do
        local pTknChar, x, y, width, height, bearingX, bearingY, advance = tkn.tknLoadTknChar(font.pTknFont, string.byte(component.text, i))

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
    local startY = top + (rectHeight - totalHeight) * component.alignV + lineHeight

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
        local startX = left + (rectWidth - line.width) * component.alignH

        for _, char in ipairs(line.chars) do
            local charLeft = startX + char.penX + char.bearingXNDC
            local charRight = charLeft + char.widthNDC
            local charTop = penY - char.bearingYNDC
            local charBottom = charTop + char.heightNDC

            -- UV coordinates
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

                -- UVs
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
            if component.bold then
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
        tkn.tknUpdateMeshPtr(pTknGfxContext, component.pTknMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    end

end

function textComponent.updateInstancePtr(pTknGfxContext, component, rect, instanceFormat)

end
return textComponent
