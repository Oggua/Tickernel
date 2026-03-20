#!/usr/bin/env lua
-- Convert Unicode code points to UTF-8 hex escape sequences for Lua strings
-- Usage:
--   lua unicode_to_utf8.lua U+EC5F
--   lua unicode_to_utf8.lua EC5F
--   lua unicode_to_utf8.lua 0xEC5F
--   lua unicode_to_utf8.lua 60511 (decimal)

local function utoa(code_point_str)
    local s = code_point_str:match("^%s*(.-)%s*$") or ""
    s = s:upper()
    local code
    if s:sub(1,2) == "U+" then
        code = tonumber(s:sub(3), 16)
    elseif s:sub(1,2) == "0X" or s:sub(1,2) == "0x" then
        code = tonumber(s:sub(3), 16)
    else
        code = tonumber(s, 16)
        if not code then
            code = tonumber(s, 10)
        end
    end
    if not code then
        return nil, "Cannot parse '" .. code_point_str .. "'"
    end
    if code < 0 or code > 0x10FFFF then
        return nil, string.format("Code point U+%04X out of valid Unicode range", code)
    end

    local utf8char
    if code <= 0x7F then
        utf8char = string.char(code)
    elseif code <= 0x7FF then
        utf8char = string.char(
            0xC0 + math.floor(code / 0x40),
            0x80 + (code % 0x40)
        )
    elseif code <= 0xFFFF then
        utf8char = string.char(
            0xE0 + math.floor(code / 0x1000),
            0x80 + (math.floor(code / 0x40) % 0x40),
            0x80 + (code % 0x40)
        )
    else
        utf8char = string.char(
            0xF0 + math.floor(code / 0x40000),
            0x80 + (math.floor(code / 0x1000) % 0x40),
            0x80 + (math.floor(code / 0x40) % 0x40),
            0x80 + (code % 0x40)
        )
    end

    local hex_escape = utf8char:gsub('.', function(c) return string.format('\\x%02x', string.byte(c)) end)
    return {
        codepoint = code,
        char = utf8char,
        hex_escape = hex_escape,
    }
end

local function print_usage()
    print("Usage: lua unicode_to_utf8.lua <code_point> [more]")
    print("Examples:")
    print("  lua unicode_to_utf8.lua U+EC5F")
    print("  lua unicode_to_utf8.lua EC5F")
    print("  lua unicode_to_utf8.lua 0xEC5F")
    print("  lua unicode_to_utf8.lua 60511")
end

local args = {...}
if #args == 0 then
    print_usage()
    os.exit(1)
end

for _, arg in ipairs(args) do
    local res, err = utoa(arg)
    if not res then
        io.stderr:write("Error: " .. err .. "\n")
    else
        local code = res.codepoint
        local char = res.char
        local hex_escape = res.hex_escape
        print(string.format("U+%04X (%d) '%s':", code, code, char))
        print("  UTF-8 hex: " .. hex_escape)
        print("  Lua string: \"text " .. hex_escape .. " more\"")
        print()
    end
end
