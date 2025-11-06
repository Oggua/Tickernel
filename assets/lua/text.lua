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

function text.createComponent(pGfxContext, textString, font, size, color, alignH, alignV, pMaterial, vertexFormat, pPipeline, node)
    local maxChars = #textString
    local pMesh = tkn.createDefaultMeshPtr(pGfxContext, vertexFormat, vertexFormat.pVertexInputLayout, maxChars * 4, VK_INDEX_TYPE_UINT16, maxChars * 6)
    local pDrawCall = tkn.createDrawCallPtr(pGfxContext, pPipeline, pMaterial, pMesh, nil)

    local component = #text.pool > 0 and table.remove(text.pool) or { type = "text" }
    component.text = textString
    component.font = font
    component.size = size
    component.color = color
    component.alignH = alignH
    component.alignV = alignV
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
    component.alignH = "left"
    component.alignV = "top"
    table.insert(text.pool, component)
end

function text.updateMeshPtr(pGfxContext, component, rect, vertexFormat, screenWidth, screenHeight)
    local font = component.font
    local sizeScale = component.size / font.fontSize
    local scaleX = sizeScale / screenWidth * 2
    local scaleY = sizeScale / screenHeight * 2
    local lineHeight = component.size / screenHeight * 2
    local atlasScale = 1 / font.atlasLength
    
    -- First pass: calculate line widths and total text bounds
    local lines = {{chars = {}, width = 0}}
    local currentLine = lines[1]
    local penX = 0
    
    for i = 1, #component.text do
        local pTknChar, x, y, width, height, bearingX, bearingY, advance = tkn.loadTknChar(font.pTknFont, string.byte(component.text, i))
        
        if pTknChar then
            local widthNDC = width * scaleX
            local heightNDC = height * scaleY
            local bearingXNDC = bearingX * scaleX
            local bearingYNDC = bearingY * scaleY
            local advanceNDC = advance * scaleX
            
            -- Word wrap check
            if penX + bearingXNDC + widthNDC > rect.right - rect.left and #currentLine.chars > 0 then
                currentLine.width = penX
                currentLine = {chars = {}, width = 0}
                table.insert(lines, currentLine)
                penX = 0
            end
            
            table.insert(currentLine.chars, {
                x = x, y = y, width = width, height = height,
                bearingX = bearingX, bearingY = bearingY, advance = advance,
                widthNDC = widthNDC, heightNDC = heightNDC,
                bearingXNDC = bearingXNDC, bearingYNDC = bearingYNDC,
                advanceNDC = advanceNDC, penX = penX
            })
            
            penX = penX + advanceNDC
        end
    end
    currentLine.width = penX
    
    -- Calculate starting Y position based on vertical alignment
    local totalHeight = #lines * lineHeight
    local startY
    if component.alignV == "top" then
        startY = rect.top + lineHeight
    elseif component.alignV == "center" then
        startY = (rect.top + rect.bottom - totalHeight) * 0.5 + lineHeight
    elseif component.alignV == "bottom" then
        startY = rect.bottom - totalHeight + lineHeight
    else
        startY = rect.top + lineHeight
    end
    
    -- Second pass: generate vertices with alignment
    local vertices = { position = {}, uv = {}, color = {} }
    local indices = {}
    local charIndex = 0
    local penY = startY
    
    for lineIdx, line in ipairs(lines) do
        -- Calculate starting X position based on horizontal alignment
        local startX
        if component.alignH == "left" then
            startX = rect.left
        elseif component.alignH == "center" then
            startX = (rect.left + rect.right - line.width) * 0.5
        elseif component.alignH == "right" then
            startX = rect.right - line.width
        else
            startX = rect.left
        end
        
        for _, char in ipairs(line.chars) do
            local left = startX + char.penX + char.bearingXNDC
            local right = left + char.widthNDC
            local top = penY - char.bearingYNDC
            local bottom = top + char.heightNDC
            
            -- Vertices (positions)
            local pos = vertices.position
            pos[#pos+1], pos[#pos+2] = left, top
            pos[#pos+1], pos[#pos+2] = right, top
            pos[#pos+1], pos[#pos+2] = right, bottom
            pos[#pos+1], pos[#pos+2] = left, bottom
            
            -- UVs
            local u0, v0 = char.x * atlasScale, char.y * atlasScale
            local u1, v1 = (char.x + char.width) * atlasScale, (char.y + char.height) * atlasScale
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
            
            charIndex = charIndex + 1
        end
        
        penY = penY + lineHeight
    end
    
    tkn.flushTknFontPtr(font.pTknFont, pGfxContext)
    
    if charIndex > 0 then
        tkn.updateMeshPtr(pGfxContext, component.pMesh, vertexFormat, vertices, VK_INDEX_TYPE_UINT16, indices)
    end
end

return text
