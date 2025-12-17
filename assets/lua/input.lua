local input = {
    keyCodeStates = {},
    mouseStates = {},
    touches = {},
}

-- Key state constants - corresponding to C enum KeyState
input.keyState = {
    idle = 0,
    down = 1,
    up = 2,
}

-- Key codes - directly corresponding to C enum KeyCode
input.keyCode = {
    a = 0,
    b = 1,
    c = 2,
    d = 3,
    e = 4,
    f = 5,
    g = 6,
    h = 7,
    i = 8,
    j = 9,
    k = 10,
    l = 11,
    m = 12,
    n = 13,
    o = 14,
    p = 15,
    q = 16,
    r = 17,
    s = 18,
    t = 19,
    u = 20,
    v = 21,
    w = 22,
    x = 23,
    y = 24,
    z = 25,
    num0 = 26,
    num1 = 27,
    num2 = 28,
    num3 = 29,
    num4 = 30,
    num5 = 31,
    num6 = 32,
    num7 = 33,
    num8 = 34,
    num9 = 35,
    enter = 36,
    escape = 37,
    backspace = 38,
    tab = 39,
    space = 40,
    minus = 41,
    equal = 42,
    left_bracket = 43,
    right_bracket = 44,
    backslash = 45,
    semicolon = 46,
    apostrophe = 47,
    grave = 48,
    comma = 49,
    period = 50,
    slash = 51,
    caps_lock = 52,
    f1 = 53,
    f2 = 54,
    f3 = 55,
    f4 = 56,
    f5 = 57,
    f6 = 58,
    f7 = 59,
    f8 = 60,
    f9 = 61,
    f10 = 62,
    f11 = 63,
    f12 = 64,
    print_screen = 65,
    scroll_lock = 66,
    pause = 67,
    insert = 68,
    home = 69,
    page_up = 70,
    delete = 71,
    ["end"] = 72,
    page_down = 73,
    right = 74,
    left = 75,
    down = 76,
    up = 77,
    num_lock = 78,
    numpad0 = 79,
    numpad1 = 80,
    numpad2 = 81,
    numpad3 = 82,
    numpad4 = 83,
    numpad5 = 84,
    numpad6 = 85,
    numpad7 = 86,
    numpad8 = 87,
    numpad9 = 88,
    numpad_divide = 89,
    numpad_multiply = 90,
    numpad_subtract = 91,
    numpad_add = 92,
    numpad_enter = 93,
    numpad_decimal = 94,
}

-- Get the raw key state value (primary interface)
function input.getKeyState(key)
    return input.keyCodeStates[key] or input.keyState.idle
end

-- Convenience functions (optional - can be removed if you prefer direct state checking)
function input.isKeyPressed(key)
    return input.getKeyState(key) == input.keyState.down
end

function input.isKeyReleased(key)
    return input.getKeyState(key) == input.keyState.up
end

function input.isKeyIdle(key)
    return input.getKeyState(key) == input.keyState.idle
end

-- Legacy function for backward compatibility
function input.isKeyDown(key)
    return input.isKeyPressed(key)
end

return input
