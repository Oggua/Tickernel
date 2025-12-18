#ifndef tkn_lua_h
#define tkn_lua_h

#include "lauxlib.h"
#include "vulkan/vulkan.h"
#include <stdbool.h>

// Key state enum for three-state keyboard input
typedef enum {
    INPUT_STATE_IDLE = 0,    // Key is not being pressed
    INPUT_STATE_DOWN = 1,    // Key was just pressed this frame
    INPUT_STATE_UP = 2       // Key was just released this frame
} InputState;

typedef struct TknContext TknContext;

typedef struct
{
    const char *name;
    uint32_t luaRegCount;
    luaL_Reg *luaRegs;
} LuaLibrary;

TknContext *createTknContextPtr(const char *assetsPath, uint32_t luaLibraryCount, LuaLibrary *luaLibraries, int targetSwapchainImageCount, VkSurfaceFormatKHR targetVkSurfaceFormat, VkPresentModeKHR targetVkPresentMode, VkInstance vkInstance, VkSurfaceKHR vkSurface, VkExtent2D swapchainExtent);
void destroyTknContextPtr(TknContext *pTknContext);
bool updateTknContext(TknContext *pTknContext, VkExtent2D swapchainExtent, uint32_t keyCodeStateCount, InputState *keyCodeStates, uint32_t mouseCodeStateCount, InputState *mouseCodeStates, float scrollingDeltaX, float scrollingDeltaY, float mousePositionNDCX, float mousePositionNDCY);
#endif
