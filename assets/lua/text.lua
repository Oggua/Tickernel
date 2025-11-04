local tkn = require("tkn")
local text = {
    pool = {},
    fonts = {},
}

function text.setup()
    text.pTknFontLibrary = tkn.createTknFontLibraryPtr()
end

function text.teardown(pGfxContext)
    for _, font in ipairs(text.fonts) do
        text.destroyFont(pGfxContext, font)
    end
    tkn.destroyTknFontLibraryPtr(pGfxContext, text.pTknFontLibrary)
    text.pTknFontLibrary = nil
end

function text.update(pGfxContext)
    for _, font in ipairs(text.fonts) do
        tkn.flushTknFontPtr(font.pTknFont, pGfxContext)
    end
end

function text.createFont(pGfxContext, path, fontSize, atlasLength)
    local pTknFont, pImage = tkn.createTknFontPtr(text.pTknFontLibrary, pGfxContext, path, fontSize, atlasLength)
    local font = {
        path = path,
        fontSize = fontSize,
        atlasLength = atlasLength,
        pTknFont = pTknFont,
        pImage = pImage,
    }
    table.insert(text.fonts, font)
    return font
end

function text.destroyFont(pGfxContext, font)
    tkn.destroyTknFontPtr(font.pTknFont, pGfxContext)
    font = nil
end

function text.createComponent(pGfxContext, textString, font, size, color, pMaterial, vertexFormat, pPipeline, node)
    local component = nil

    -- Calculate max character count (estimate 4 vertices per character)
    local maxChars = #textString
    local vertexCount = maxChars * 4
    local indexCount = maxChars * 6

    local pMesh = tkn.createDefaultMeshPtr(pGfxContext, vertexFormat, vertexFormat.pVertexInputLayout, vertexCount, VK_INDEX_TYPE_UINT16, indexCount)
    local pDrawCall = tkn.createDrawCallPtr(pGfxContext, pPipeline, pMaterial, pMesh, nil)

    if #text.pool > 0 then
        component = table.remove(text.pool)
        component.text = textString
        component.font = font
        component.size = size
        component.color = color
        component.pMaterial = pMaterial
        component.pMesh = pMesh
        component.pDrawCall = pDrawCall
    else
        component = {
            type = "text",
            text = textString,
            font = font,
            size = size,
            color = color,
            pMaterial = pMaterial,
            pMesh = pMesh,
            pDrawCall = pDrawCall,
        }
    end
    return component
end

function text.destroyComponent(pGfxContext, component)
    tkn.destroyDrawCallPtr(pGfxContext, component.pDrawCall)
    tkn.destroyMeshPtr(pGfxContext, component.pMesh)

    component.pMaterial = nil
    component.pMesh = nil
    component.pDrawCall = nil
    component.font = nil
    component.text = ""
    component.size = 0
    component.color = 0xFFFFFFFF
    table.insert(text.pool, component)
end

function text.updateMeshPtr(pGfxContext, component, rect, vertexFormat, screenWidth, screenHeight)
    local vertices = {
        position = {},
        uv = {},
        color = {},
    }
    local indices = {}

    local font = component.font
    local textString = component.text
    local color = component.color
    local size = component.size

    -- Calculate text layout - size determines character pixel size
    -- Vulkan NDC: Y=-1 is top, Y=1 is bottom, Y increases downward
    local sizeScale = size / font.fontSize
    local penX = rect.left
    local penY = rect.top  -- Start from top (Y=-1 in Vulkan)
    local rectWidth = rect.right - rect.left

    local charIndex = 0
    for i = 1, #textString do
        local char = textString:sub(i, i)
        local unicode = string.byte(char)

        -- Load character from font
        local pTknChar, x, y, width, height, bearingX, bearingY, advance = tkn.loadTknChar(font.pTknFont, unicode)

        if pTknChar then
            -- Calculate character size in normalized screen space
            local charWidthNorm = width * sizeScale / screenWidth * 2
            local charHeightNorm = height * sizeScale / screenHeight * 2
            local bearingXNorm = bearingX * sizeScale / screenWidth * 2
            local bearingYNorm = bearingY * sizeScale / screenHeight * 2
            local advanceNorm = advance * sizeScale / screenWidth * 2

            -- Check if character would exceed rect width (word wrap)
            if penX + bearingXNorm + charWidthNorm > rect.right then
                penX = rect.left
                penY = penY + size / screenHeight * 2 -- Move to next line
            end

            -- Calculate character position in screen space
            local atlasU0 = x / font.atlasLength
            local atlasV0 = y / font.atlasLength
            local atlasU1 = (x + width) / font.atlasLength
            local atlasV1 = (y + height) / font.atlasLength

            -- Character position (normalized screen coordinates)
            -- Vulkan: Y increases downward. penY is baseline.
            -- bearingY is distance from baseline UP to char top (so subtract in Vulkan)
            local charLeft = penX + bearingXNorm
            local charRight = charLeft + charWidthNorm
            local charTop = penY - bearingYNorm  -- baseline - up distance (up means smaller Y)
            local charBottom = penY + (charHeightNorm - bearingYNorm)  -- baseline + down distance
            
            -- Add vertices for this character (quad): left-top, right-top, right-bottom, left-bottom
            table.insert(vertices.position, charLeft)
            table.insert(vertices.position, charTop)
            table.insert(vertices.position, charRight)
            table.insert(vertices.position, charTop)
            table.insert(vertices.position, charRight)
            table.insert(vertices.position, charBottom)
            table.insert(vertices.position, charLeft)
            table.insert(vertices.position, charBottom)

            -- UV coordinates: match image.lua pattern
            table.insert(vertices.uv, atlasU0)
            table.insert(vertices.uv, atlasV0)
            table.insert(vertices.uv, atlasU1)
            table.insert(vertices.uv, atlasV0)
            table.insert(vertices.uv, atlasU1)
            table.insert(vertices.uv, atlasV1)
            table.insert(vertices.uv, atlasU0)
            table.insert(vertices.uv, atlasV1)

            -- Colors
            table.insert(vertices.color, color)
            table.insert(vertices.color, color)
            table.insert(vertices.color, color)
            table.insert(vertices.color, color)

            -- Indices for this quad
            local base = charIndex * 4
            table.insert(indices, base + 0)
            table.insert(indices, base + 1)
            table.insert(indices, base + 2)
            table.insert(indices, base + 2)
            table.insert(indices, base + 3)
            table.insert(indices, base + 0)

            -- Advance pen position
            penX = penX + advanceNorm
            charIndex = charIndex + 1
        end
    end

    -- Flush font atlas updates
    tkn.flushTknFontPtr(font.pTknFont, pGfxContext)

    -- Update mesh with generated vertices
    if charIndex > 0 then
        tkn.updateMeshPtr(pGfxContext, component.pMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    end
end

return text
