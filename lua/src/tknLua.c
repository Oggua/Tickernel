#include "tknLuaBinding.h"

struct TknContext
{
    lua_State *pLuaState;
    TknGfxContext *pTknGfxContext;
};

static int errorHandler(lua_State *L)
{
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL)
        msg = "unknown error";
    luaL_traceback(L, L, msg, 1);
    return 1;
}

static void assertLuaResult(lua_State *pLuaState, int result)
{
    if (LUA_OK != result)
    {
        const char *fullError = lua_tostring(pLuaState, -1);
        if (fullError == NULL)
            fullError = "unknown error";
        tknError("Lua error: %s (result: %d)", fullError, result);
        lua_pop(pLuaState, 1);
    }
}

TknContext *createTknContextPtr(const char *assetsPath, uint32_t luaLibraryCount, LuaLibrary *luaLibraries, int targetSwapchainImageCount, VkSurfaceFormatKHR targetVkSurfaceFormat, VkPresentModeKHR targetVkPresentMode, VkInstance vkInstance, VkSurfaceKHR vkSurface, VkExtent2D swapchainExtent)
{
    TknContext *pTknContext = tknMalloc(sizeof(TknContext));

    char globalVertSpvPath[FILENAME_MAX];
    char globalFragSpvPath[FILENAME_MAX];
    snprintf(globalVertSpvPath, FILENAME_MAX, "%s/shaders/global.vert.spv", assetsPath);
    snprintf(globalFragSpvPath, FILENAME_MAX, "%s/shaders/global.frag.spv", assetsPath);

    const char *spvPaths[] = {
        globalVertSpvPath,
        globalFragSpvPath,
    };

    TknGfxContext *pTknGfxContext = tknCreateGfxContextPtr(targetSwapchainImageCount, targetVkSurfaceFormat, targetVkPresentMode, vkInstance, vkSurface, swapchainExtent, TKN_ARRAY_COUNT(spvPaths), spvPaths);

    lua_State *pLuaState = luaL_newstate();
    tknAssert(pLuaState, "Failed to create Lua state");
    luaL_openlibs(pLuaState);

    char packagePath[FILENAME_MAX];
    snprintf(packagePath, FILENAME_MAX, "%s/lua/?.lua", assetsPath);
    lua_getglobal(pLuaState, "package");
    lua_pushstring(pLuaState, packagePath);
    lua_setfield(pLuaState, -2, "path");
    lua_pop(pLuaState, 1);

    bindFunctions(pLuaState);
    for (uint32_t luaLibraryIndex = 0; luaLibraryIndex < luaLibraryCount; luaLibraryIndex++)
    {
        LuaLibrary luaLibrary = luaLibraries[luaLibraryIndex];
        lua_createtable(pLuaState, 0, luaLibrary.luaRegCount - 1);
        luaL_setfuncs(pLuaState, luaLibrary.luaRegs, 0);
        lua_setglobal(pLuaState, luaLibrary.name);
    }

    char tknEngineLuaPath[FILENAME_MAX];
    snprintf(tknEngineLuaPath, FILENAME_MAX, "%s/lua/tknEngine.lua", assetsPath);
    int result = luaL_dofile(pLuaState, tknEngineLuaPath);
    assertLuaResult(pLuaState, result);

    lua_getfield(pLuaState, -1, "start");
    lua_pushlightuserdata(pLuaState, pTknGfxContext);
    lua_pushstring(pLuaState, assetsPath);
    lua_pushcfunction(pLuaState, errorHandler);
    lua_insert(pLuaState, -4);
    assertLuaResult(pLuaState, lua_pcall(pLuaState, 2, 0, -4));
    lua_pop(pLuaState, 1);

    TknContext TknContext = {
        .pTknGfxContext = pTknGfxContext,
        .pLuaState = pLuaState,
    };
    *pTknContext = TknContext;
    return pTknContext;
}

void destroyTknContextPtr(TknContext *pTknContext)
{
    if (!pTknContext)
        return;

    TknGfxContext *pTknGfxContext = pTknContext->pTknGfxContext;
    lua_State *pLuaState = pTknContext->pLuaState;

    lua_pushcfunction(pLuaState, errorHandler);
    lua_getglobal(pLuaState, "tknEngine");
    lua_getfield(pLuaState, -1, "stop");
    lua_pushlightuserdata(pLuaState, pTknGfxContext);
    assertLuaResult(pLuaState, lua_pcall(pLuaState, 1, 0, -4));
    lua_pop(pLuaState, 2);

    tknDestroyGfxContextPtr(pTknGfxContext);
    lua_close(pLuaState);
    tknFree(pTknContext);
}

bool updateTknContext(TknContext *pTknContext, VkExtent2D swapchainExtent, uint32_t keyCodeStateCount, InputState *keyCodeStates, uint32_t mouseCodeStateCount, InputState *mouseCodeStates, float scrollingDeltaX, float scrollingDeltaY, float mousePositionNDCX, float mousePositionNDCY)
{
    lua_State *pLuaState = pTknContext->pLuaState;
    bool shouldQuit = false;

    // Update input states first
    if (keyCodeStates && keyCodeStateCount > 0)
    {
        lua_getglobal(pLuaState, "require");
        lua_pushstring(pLuaState, "input");
        lua_call(pLuaState, 1, 1);

        lua_getfield(pLuaState, -1, "keyCodeStates");
        // Use the actual keyCodeStateCount parameter for safety
        for (uint32_t i = 0; i < keyCodeStateCount; i++)
        {
            lua_pushinteger(pLuaState, i);
            lua_pushinteger(pLuaState, keyCodeStates[i]);
            lua_settable(pLuaState, -3);
        }
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "mouseCodeStates");
        for (uint32_t i = 0; i < mouseCodeStateCount; i++)
        {
            lua_pushinteger(pLuaState, i);
            lua_pushinteger(pLuaState, mouseCodeStates[i]);
            lua_settable(pLuaState, -3);
        }
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "scrollingDelta");
        lua_pushnumber(pLuaState, scrollingDeltaX);
        lua_setfield(pLuaState, -2, "x");
        lua_pushnumber(pLuaState, scrollingDeltaY);
        lua_setfield(pLuaState, -2, "y");
        lua_pop(pLuaState, 1);

        lua_getfield(pLuaState, -1, "mousePositionNDC");
        lua_pushnumber(pLuaState, mousePositionNDCX);
        lua_setfield(pLuaState, -2, "x");
        lua_pushnumber(pLuaState, mousePositionNDCY);
        lua_setfield(pLuaState, -2, "y");
        lua_pop(pLuaState, 2);
    }

    TknGfxContext *pTknGfxContext = pTknContext->pTknGfxContext;

    // Push error handler once at the beginning
    lua_pushcfunction(pLuaState, errorHandler);
    lua_getglobal(pLuaState, "tknEngine");

    // Call update with pTknGfxContext, width, height - Lua controls when to waitRenderFence
    lua_getfield(pLuaState, -1, "update");
    lua_pushlightuserdata(pLuaState, pTknGfxContext);
    lua_pushinteger(pLuaState, swapchainExtent.width);
    lua_pushinteger(pLuaState, swapchainExtent.height);
    assertLuaResult(pLuaState, lua_pcall(pLuaState, 3, 1, -6));

    // Get return value if present
    if (lua_isboolean(pLuaState, -1))
    {
        shouldQuit = lua_toboolean(pLuaState, -1);
    }
    lua_pop(pLuaState, 3); // Pop return value, errorHandler and tknEngine table
    tknUpdateGfxContextPtr(pTknGfxContext, swapchainExtent);

    return shouldQuit;
}
