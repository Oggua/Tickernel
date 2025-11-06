local tkn = require("tkn")
local text = {
    pool = {},
    fonts = {},
}

function text.setup()
    text.pTknFontLibrary = tkn.createTknFontLibraryPtr()
end

function text.teardown(pGfxContext)
    tkn.destroyTknFontLibraryPtr(pGfxContext, text.pTknFontLibrary)
    text.pTknFontLibrary = nil
end

function text.update(pGfxContext)
    for _, font in ipairs(text.fonts) do
        tkn.flushTknFontPtr(font.pTknFont, pGfxContext)
    end
end

function text.createFont(pGfxContext, path, fontSize, atlasLength)
    print("createFont")
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
    print("destroyFont")
    tkn.destroyTknFontPtr(font.pTknFont, pGfxContext)
    font = nil
end

function text.createComponent(pGfxContext, textString, font, size, color, pMaterial, vertexFormat, pPipeline, node)
    local maxChars = #textString
    local pMesh = tkn.createDefaultMeshPtr(pGfxContext, vertexFormat, vertexFormat.pVertexInputLayout, maxChars * 4, VK_INDEX_TYPE_UINT16, maxChars * 6)
    local pDrawCall = tkn.createDrawCallPtr(pGfxContext, pPipeline, pMaterial, pMesh, nil)

    local component = #text.pool > 0 and table.remove(text.pool) or { type = "text" }
    component.text = textString
    component.font = font
    component.size = size
    component.color = color
    component.pMaterial = pMaterial
    component.pMesh = pMesh
    component.pDrawCall = pDrawCall
    
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
    local vertices = { position = {}, uv = {}, color = {} }
    local indices = {}

    local font = component.font
    local sizeScale = component.size / font.fontSize
    local scaleX = sizeScale / screenWidth * 2
    local scaleY = sizeScale / screenHeight * 2
    local lineHeight = component.size / screenHeight * 2
    local atlasScale = 1 / font.atlasLength
    
    local penX = rect.left
    local penY = rect.top + lineHeight
    local charIndex = 0

    for i = 1, #component.text do
        local pTknChar, x, y, width, height, bearingX, bearingY, advance = tkn.loadTknChar(font.pTknFont, string.byte(component.text, i))

        if pTknChar then
            local widthNDC = width * scaleX
            local heightNDC = height * scaleY
            local bearingXNDC = bearingX * scaleX
            local bearingYNDC = bearingY * scaleY
            local advanceNDC = advance * scaleX

            -- Word wrap
            if penX + bearingXNDC + widthNDC > rect.right then
                penX = rect.left
                penY = penY + lineHeight
            end

            -- Character quad
            local left = penX + bearingXNDC
            local right = left + widthNDC
            local top = penY - bearingYNDC
            local bottom = top + heightNDC

            -- Vertices (positions)
            local pos = vertices.position
            pos[#pos+1], pos[#pos+2] = left, top
            pos[#pos+1], pos[#pos+2] = right, top
            pos[#pos+1], pos[#pos+2] = right, bottom
            pos[#pos+1], pos[#pos+2] = left, bottom

            -- UVs
            local u0, v0 = x * atlasScale, y * atlasScale
            local u1, v1 = (x + width) * atlasScale, (y + height) * atlasScale
            local uv = vertices.uv
            uv[#uv+1], uv[#uv+2] = u0, v0
            uv[#uv+1], uv[#uv+2] = u1, v0
            uv[#uv+1], uv[#uv+2] = u1, v1
            uv[#uv+1], uv[#uv+2] = u0, v1

            -- Colors
            local col = vertices.color
            col[#col+1], col[#col+2], col[#col+3], col[#col+4] = component.color, component.color, component.color, component.color

            -- Indices
            local base = charIndex * 4
            local idx = indices
            idx[#idx+1], idx[#idx+2], idx[#idx+3] = base, base + 1, base + 2
            idx[#idx+1], idx[#idx+2], idx[#idx+3] = base + 2, base + 3, base

            penX = penX + advanceNDC
            charIndex = charIndex + 1
        end
    end

    tkn.flushTknFontPtr(font.pTknFont, pGfxContext)
    
    if charIndex > 0 then
        tkn.updateMeshPtr(pGfxContext, component.pMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    end
end

return text
