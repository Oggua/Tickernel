local tknMath = {}
function tknMath.rgbaToAbgr(rgba)
    local r = (rgba >> 24) & 0xFF
    local g = (rgba >> 16) & 0xFF
    local b = (rgba >> 8) & 0xFF
    local a = rgba & 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r
end

function tknMath.multiplyColors(c1, c2)
    local a1 = (c1 >> 24) & 0xFF
    local r1 = (c1 >> 16) & 0xFF
    local g1 = (c1 >> 8) & 0xFF
    local b1 = c1 & 0xFF
    local a2 = (c2 >> 24) & 0xFF
    local r2 = (c2 >> 16) & 0xFF
    local g2 = (c2 >> 8) & 0xFF
    local b2 = c2 & 0xFF
    local a = (a1 * a2) // 255
    local r = (r1 * r2) // 255
    local g = (g1 * g2) // 255
    local b = (b1 * b2) // 255
    return (a << 24) | (r << 16) | (g << 8) | b
end
-- 3x3 matrix multiplication for flat ROW-MAJOR arrays (returns new table)
-- Matrices are stored as: [m00, m01, m02, m10, m11, m12, m20, m21, m22]
-- Computes r = a * b where a,b are row-major flat arrays
function tknMath.multiplyMatrix3x3(a, b)
    local r = {}
    r[1] = a[1] * b[1] + a[2] * b[4] + a[3] * b[7]
    r[2] = a[1] * b[2] + a[2] * b[5] + a[3] * b[8]
    r[3] = a[1] * b[3] + a[2] * b[6] + a[3] * b[9]

    r[4] = a[4] * b[1] + a[5] * b[4] + a[6] * b[7]
    r[5] = a[4] * b[2] + a[5] * b[5] + a[6] * b[8]
    r[6] = a[4] * b[3] + a[5] * b[6] + a[6] * b[9]

    r[7] = a[7] * b[1] + a[8] * b[4] + a[9] * b[7]
    r[8] = a[7] * b[2] + a[8] * b[5] + a[9] * b[8]
    r[9] = a[7] * b[3] + a[8] * b[6] + a[9] * b[9]
    return r
end

-- backward compatibility aliases
-- (no backward-compat aliases; project uses descriptive names)

-- 4x4 matrix multiplication for flat row-major arrays (returns new table)
function tknMath.multiplyMatrix4x4(a, b)
    -- Unrolled 4x4 multiplication (row-major flat arrays) for performance in Lua
    local c = {}
    c[1] = a[1] * b[1] + a[2] * b[5] + a[3] * b[9] + a[4] * b[13]
    c[2] = a[1] * b[2] + a[2] * b[6] + a[3] * b[10] + a[4] * b[14]
    c[3] = a[1] * b[3] + a[2] * b[7] + a[3] * b[11] + a[4] * b[15]
    c[4] = a[1] * b[4] + a[2] * b[8] + a[3] * b[12] + a[4] * b[16]

    c[5] = a[5] * b[1] + a[6] * b[5] + a[7] * b[9] + a[8] * b[13]
    c[6] = a[5] * b[2] + a[6] * b[6] + a[7] * b[10] + a[8] * b[14]
    c[7] = a[5] * b[3] + a[6] * b[7] + a[7] * b[11] + a[8] * b[15]
    c[8] = a[5] * b[4] + a[6] * b[8] + a[7] * b[12] + a[8] * b[16]

    c[9] = a[9] * b[1] + a[10] * b[5] + a[11] * b[9] + a[12] * b[13]
    c[10] = a[9] * b[2] + a[10] * b[6] + a[11] * b[10] + a[12] * b[14]
    c[11] = a[9] * b[3] + a[10] * b[7] + a[11] * b[11] + a[12] * b[15]
    c[12] = a[9] * b[4] + a[10] * b[8] + a[11] * b[12] + a[12] * b[16]

    c[13] = a[13] * b[1] + a[14] * b[5] + a[15] * b[9] + a[16] * b[13]
    c[14] = a[13] * b[2] + a[14] * b[6] + a[15] * b[10] + a[16] * b[14]
    c[15] = a[13] * b[3] + a[14] * b[7] + a[15] * b[11] + a[16] * b[15]
    c[16] = a[13] * b[4] + a[14] * b[8] + a[15] * b[12] + a[16] * b[16]
    return c
end

-- backward compatibility alias
-- (no backward-compat alias; project uses descriptive names)

function tknMath.round(v)
    return math.floor(0.5 + v)
end

function tknMath.clamp(v, min, max)
    if v < min then
        return min
    elseif v > max then
        return max
    else
        return v
    end
end

function tknMath.lerp(a, b, t)
    t = tknMath.clamp(t, 0, 1)
    return a + (b - a) * t
end

function tknMath.cantorPair(a, b)
    local ai = math.tointeger(math.floor(a))
    local bi = math.tointeger(math.floor(b))
    return (ai + bi) * (ai + bi + 1) // 2 + bi
end

function tknMath.lcgRandom(v)
    local vi = math.tointeger(math.floor(v))
    vi = vi & 0xFFFFFFFF
    return (1664525 * vi + 1013904223) & 0xFFFFFFFF
end

function tknMath.pingPong(a, b, t)
    local floor = math.floor(t)
    local remainder = t - floor
    if floor % 2 == 0 then
        return a + (b - a) * remainder
    else
        return a + (b - a) * (1 - remainder)
    end
end

function tknMath.smoothLerp(a, b, t)
    t = t * t * t * (6 * t * t - 15 * t + 10)
    return a + (b - a) * t
end

local rotationMatrix = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}

local scaleMatrix = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}

local translateMatrix = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}}

local modelMatrix = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}

local function rotateAroundZ(angle)
    local rad = math.rad(angle)
    rotationMatrix[1][1] = math.cos(rad)
    rotationMatrix[1][2] = -math.sin(rad)
    rotationMatrix[1][3] = 0
    rotationMatrix[1][4] = 0

    rotationMatrix[2][1] = math.sin(rad)
    rotationMatrix[2][2] = math.cos(rad)
    rotationMatrix[2][3] = 0
    rotationMatrix[2][4] = 0

    rotationMatrix[3][1] = 0
    rotationMatrix[3][2] = 0
    rotationMatrix[3][3] = 1
    rotationMatrix[3][4] = 0

    rotationMatrix[4][1] = 0
    rotationMatrix[4][2] = 0
    rotationMatrix[4][3] = 0
    rotationMatrix[4][4] = 1

    return rotationMatrix
end

local function scaleModel(scale)
    scaleMatrix[1][1] = scale
    scaleMatrix[1][2] = 0
    scaleMatrix[1][3] = 0
    scaleMatrix[1][4] = 0

    scaleMatrix[2][1] = 0
    scaleMatrix[2][2] = scale
    scaleMatrix[2][3] = 0
    scaleMatrix[2][4] = 0

    scaleMatrix[3][1] = 0
    scaleMatrix[3][2] = 0
    scaleMatrix[3][3] = scale
    scaleMatrix[3][4] = 0

    scaleMatrix[4][1] = 0
    scaleMatrix[4][2] = 0
    scaleMatrix[4][3] = 0
    scaleMatrix[4][4] = 1

    return scaleMatrix
end

local function translateModel(x, y, z)
    translateMatrix[1][4] = x
    translateMatrix[2][4] = y
    translateMatrix[3][4] = z
    return translateMatrix
end

local function matrixMultiply(A, B, result)
    for i = 1, 4 do
        for j = 1, 4 do
            result[i][j] = 0
            for k = 1, 4 do
                result[i][j] = result[i][j] + A[i][k] * B[k][j]
            end
        end
    end
    return result
end

local function applyTransformations(scale, x, y, z, angle)
    local rotationMatrix = rotateAroundZ(angle)
    local scaleMatrix = scaleModel(scale)
    local translateMatrix = translateModel(x, y, z)
    return matrixMultiply(translateMatrix, matrixMultiply(rotationMatrix, scaleMatrix, modelMatrix), modelMatrix)
end

local grad2D = function(hash, x, y)
    local h = hash & 7 -- Keep only the lower 3 bits of the hash
    local u = h < 4 and x or y
    local v = h < 4 and y or x
    local u_sign = (h & 1) == 0 and 1 or -1
    local v_sign = (h & 2) == 0 and 1 or -1
    return u * u_sign + v * v_sign
end

local dotGridGradient2D = function(ix, iy, x, y, seed)
    local dx = x - ix
    local dy = y - iy
    local hash = tknMath.lcgRandom(tknMath.cantorPair(tknMath.cantorPair(ix, iy), seed))
    hash = hash & 0xFF
    return grad2D(hash, dx, dy)
end

---comment
---@param seed integer
---@param x number
---@param y number
---@return number
function tknMath.perlinNoise2D(seed, x, y)
    -- Determine grid cell coordinates
    local x0 = math.floor(x)
    local x1 = x0 + 1
    local y0 = math.floor(y)
    local y1 = y0 + 1
    -- Determine interpolation weights
    -- Could also use higher order polynomial/s-curve here
    local sx = x - x0
    local sy = y - y0
    -- Interpolate between grid point gradients
    local n0, n1, ix0, ix1, value
    n0 = dotGridGradient2D(x0, y0, x, y, seed)
    n1 = dotGridGradient2D(x1, y0, x, y, seed)
    ix0 = tknMath.smoothLerp(n0, n1, sx)
    n0 = dotGridGradient2D(x0, y1, x, y, seed)
    n1 = dotGridGradient2D(x1, y1, x, y, seed)
    ix1 = tknMath.smoothLerp(n0, n1, sx)
    value = tknMath.smoothLerp(ix0, ix1, sy)
    return value
end

local grad3D = function(hash, x, y, z)
    local h = hash & 15
    local u = h < 8 and x or y
    local v = h < 4 and y or (h == 12 or h == 14) and x or z
    return ((h & 1) == 0 and u or -u) + ((h & 2) == 0 and v or -v)
end

local dotGridGradient3D = function(ix, iy, iz, x, y, z, seed)
    local dx = x - ix
    local dy = y - iy
    local dz = z - iz
    local hash = tknMath.lcgRandom(tknMath.cantorPair(tknMath.cantorPair(tknMath.cantorPair(ix, iy), iz), seed))
    hash = hash & 0xFF
    return grad3D(hash, dx, dy, dz)
end

---comment
---@param seed number
---@param x number
---@param y number
---@param z number
---@return number
function tknMath.perlinNoise3D(seed, x, y, z)
    -- Determine grid cell coordinates
    local x0 = math.floor(x)
    local x1 = x0 + 1
    local y0 = math.floor(y)
    local y1 = y0 + 1
    local z0 = math.floor(z)
    local z1 = z0 + 1
    -- Determine interpolation weights
    -- Could also use higher order polynomial/s-curve here
    local sx = x - x0
    local sy = y - y0
    local sz = z - z0
    -- Interpolate between grid point gradients
    local x00 = tknMath.smoothLerp(dotGridGradient3D(x0, y0, z0, x, y, z, seed), dotGridGradient3D(x1, y0, z0, x, y, z, seed), sx)
    local x10 = tknMath.smoothLerp(dotGridGradient3D(x0, y1, z0, x, y, z, seed), dotGridGradient3D(x1, y1, z0, x, y, z, seed), sx)
    local x01 = tknMath.smoothLerp(dotGridGradient3D(x0, y0, z1, x, y, z, seed), dotGridGradient3D(x1, y0, z1, x, y, z, seed), sx)
    local x11 = tknMath.smoothLerp(dotGridGradient3D(x0, y1, z1, x, y, z, seed), dotGridGradient3D(x1, y1, z1, x, y, z, seed), sx)

    local y0 = tknMath.smoothLerp(x00, x10, sy)
    local y1 = tknMath.smoothLerp(x01, x11, sy)

    return tknMath.smoothLerp(y0, y1, sz)
end

local rotationMatrix = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}

local scaleMatrix = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}

local translateMatrix = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}}

local function rotateAroundZ(angle)
    local rad = math.rad(angle)
    rotationMatrix[1][1] = math.cos(rad)
    rotationMatrix[1][2] = -math.sin(rad)
    rotationMatrix[1][3] = 0
    rotationMatrix[1][4] = 0

    rotationMatrix[2][1] = math.sin(rad)
    rotationMatrix[2][2] = math.cos(rad)
    rotationMatrix[2][3] = 0
    rotationMatrix[2][4] = 0

    rotationMatrix[3][1] = 0
    rotationMatrix[3][2] = 0
    rotationMatrix[3][3] = 1
    rotationMatrix[3][4] = 0

    rotationMatrix[4][1] = 0
    rotationMatrix[4][2] = 0
    rotationMatrix[4][3] = 0
    rotationMatrix[4][4] = 1

    return rotationMatrix
end

local function scaleModel(scale)
    scaleMatrix[1][1] = scale
    scaleMatrix[1][2] = 0
    scaleMatrix[1][3] = 0
    scaleMatrix[1][4] = 0

    scaleMatrix[2][1] = 0
    scaleMatrix[2][2] = scale
    scaleMatrix[2][3] = 0
    scaleMatrix[2][4] = 0

    scaleMatrix[3][1] = 0
    scaleMatrix[3][2] = 0
    scaleMatrix[3][3] = scale
    scaleMatrix[3][4] = 0

    scaleMatrix[4][1] = 0
    scaleMatrix[4][2] = 0
    scaleMatrix[4][3] = 0
    scaleMatrix[4][4] = 1

    return scaleMatrix
end

local function translateModel(x, y, z)
    translateMatrix[1][1] = 1
    translateMatrix[1][2] = 0
    translateMatrix[1][3] = 0
    translateMatrix[1][4] = x

    translateMatrix[2][1] = 0
    translateMatrix[2][2] = 1
    translateMatrix[2][3] = 0
    translateMatrix[2][4] = y

    translateMatrix[3][1] = 0
    translateMatrix[3][2] = 0
    translateMatrix[3][3] = 1
    translateMatrix[3][4] = z

    translateMatrix[4][1] = 0
    translateMatrix[4][2] = 0
    translateMatrix[4][3] = 0
    translateMatrix[4][4] = 1
    return translateMatrix
end

local function matrixMultiply(a, b, result)
    for i = 1, 4 do
        for j = 1, 4 do
            result[i][j] = 0
            for k = 1, 4 do
                result[i][j] = result[i][j] + a[i][k] * b[k][j]
            end
        end
    end
end

local modelMatrix = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}
function tknMath.applyTransformations(scale, x, y, z, angle, matrix)
    local rotationMatrix = rotateAroundZ(angle)
    local scaleMatrix = scaleModel(scale)
    local translateMatrix = translateModel(x, y, z)
    matrixMultiply(rotationMatrix, scaleMatrix, modelMatrix)
    matrixMultiply(translateMatrix, modelMatrix, matrix)
end

function tknMath.cross2D(ax, ay, bx, by)
    return ax * by - ay * bx
end

function tknMath.cross3D(ax, ay, az, bx, by, bz)
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

function tknMath.normalize3D(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 0.000001 then
        return 0.0, 0.0, 0.0
    end
    return x / len, y / len, z / len
end

function tknMath.normalize2D(x, y)
    local len = math.sqrt(x * x + y * y)
    if len < 0.000001 then
        return 0.0, 0.0
    end
    return x / len, y / len

end

function tknMath.dot3D(ax, ay, az, bx, by, bz)
    return ax * bx + ay * by + az * bz
end

function tknMath.dot2D(ax, ay, bx, by)
    return ax * bx + ay * by
end

return tknMath
