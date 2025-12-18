#import "EngineBinding.h"
#import "AudioBinding.h"

static int luaLoadAudio(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    const char *fileName = luaL_checkstring(L, -1);
    [pAudioBinding loadAudio:[NSString stringWithUTF8String:fileName]];
    return 0;
}
static int luaUnloadAudio(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    const char *fileName = luaL_checkstring(L, -1);
    [pAudioBinding unloadAudio:[NSString stringWithUTF8String:fileName]];
    return 0;
}
static int luaGetAudioPlayer(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    const char *fileName = luaL_checkstring(L, -1);
    AVAudioPlayerNode *audioPlayer =
        [pAudioBinding getAudioPlayer:[NSString stringWithUTF8String:fileName]];
    lua_pushlightuserdata(L, (__bridge void *)audioPlayer);
    return 1;
}
static int luaReleaseAudioPlayer(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    AVAudioPlayerNode *audioPlayer =
        (__bridge AVAudioPlayerNode *)(lua_touserdata(L, -1));
    [pAudioBinding releaseAudioPlayer:audioPlayer];
    return 0;
}
static int luaPlayAudio(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    AVAudioPlayerNode *audioPlayer =
        (__bridge AVAudioPlayerNode *)(lua_touserdata(L, -1));
    if (audioPlayer) {
        [pAudioBinding playAudio:audioPlayer];
    }
    return 0;
}
static int luaPauseAudio(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    AVAudioPlayerNode *audioPlayer =
        (__bridge AVAudioPlayerNode *)(lua_touserdata(L, -1));
    if (audioPlayer) {
        [pAudioBinding pauseAudio:audioPlayer];
    }
    return 0;
}
static int luaStopAudio(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    AVAudioPlayerNode *audioPlayer =
        (__bridge AVAudioPlayerNode *)(lua_touserdata(L, -1));
    if (audioPlayer) {
        [pAudioBinding stopAudio:audioPlayer];
    }
    return 0;
}
static int luaSetAudioPosition(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pAudioBinding");
    AudioBinding *pAudioBinding =
        (__bridge AudioBinding *)(lua_touserdata(L, -1));
    lua_pop(L, 1);
    AVAudioPlayerNode *audioPlayer =
        (__bridge AVAudioPlayerNode *)(lua_touserdata(L, -4));
    float x = luaL_checknumber(L, -3);
    float y = luaL_checknumber(L, -2);
    float z = luaL_checknumber(L, -1);
    if (audioPlayer) {
        [pAudioBinding setAudioPosition:audioPlayer X:x Y:y Z:z];
    }
    return 0;
}

@implementation EngineBinding

VKAPI_ATTR VkBool32 VKAPI_CALL
debugCallback(VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
              VkDebugUtilsMessageTypeFlagsEXT messageType,
              const VkDebugUtilsMessengerCallbackDataEXT *pCallbackData,
              void *pUserData) {
    NSLog(@"[Vulkan Validation] %s", pCallbackData->pMessage);
    return VK_FALSE;
}

- (void)createVkInstance {
    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = [AppName UTF8String];
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "Tickernel Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_3;

    VkInstanceCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.flags = VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;

#ifdef DEBUG
    const char *layers[] = {
        "VK_LAYER_KHRONOS_validation",
    };
    createInfo.enabledLayerCount = sizeof(layers) / sizeof(layers[0]);
    createInfo.ppEnabledLayerNames = layers;

    VkDebugUtilsMessengerCreateInfoEXT debugCreateInfo = {};
    debugCreateInfo.sType =
        VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    debugCreateInfo.messageSeverity =
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    debugCreateInfo.messageType =
        VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
        VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
        VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    debugCreateInfo.pfnUserCallback = debugCallback;
    createInfo.pNext = &debugCreateInfo;
#else
    createInfo.enabledLayerCount = 0;
    createInfo.ppEnabledLayerNames = NULL;
    createInfo.pNext = NULL;
#endif

    const char *extensions[] = {
        "VK_KHR_surface",
        "VK_MVK_macos_surface",
        "VK_KHR_portability_enumeration",
#ifdef DEBUG
        "VK_EXT_debug_utils",
#endif
    };
    createInfo.enabledExtensionCount =
        sizeof(extensions) / sizeof(extensions[0]);
    createInfo.ppEnabledExtensionNames = extensions;

    if (vkCreateInstance(&createInfo, NULL, &_vkInstance) != VK_SUCCESS) {
        NSLog(@"Failed to create Vulkan instance!");
        exit(EXIT_FAILURE);
    }
    NSLog(@"Vulkan instance created successfully!");
}

- (void)createVkSurface:(const void *)pView {
    VkMacOSSurfaceCreateInfoMVK surfaceCreateInfo = {};
    surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_MACOS_SURFACE_CREATE_INFO_MVK;
    surfaceCreateInfo.pView = pView;

    if (vkCreateMacOSSurfaceMVK(_vkInstance, &surfaceCreateInfo, NULL,
                                &_vkSurface) != VK_SUCCESS) {
        NSLog(@"Failed to create Vulkan surface!");
        exit(EXIT_FAILURE);
    }
    NSLog(@"Vulkan surface created successfully!");
}

- (void)destroyVkInstance {
    if (_vkInstance != VK_NULL_HANDLE) {
        vkDestroyInstance(_vkInstance, NULL);
        _vkInstance = VK_NULL_HANDLE;
    }
}

- (void)destroyVkSurface {
    if (_vkSurface != VK_NULL_HANDLE) {
        vkDestroySurfaceKHR(_vkInstance, _vkSurface, NULL);
        _vkSurface = VK_NULL_HANDLE;
    }
}

- (void)setupEngine:(uint32_t)width
             height:(uint32_t)height
       resourcePath:(NSString *)resourcePath
              pView:(void *)pView;
{
    [self createVkInstance];
    [self createVkSurface:pView];

    VkSurfaceFormatKHR vkSurfaceFormatKHR = {
        .format = VK_FORMAT_B8G8R8A8_SRGB,
        .colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
    };
    VkExtent2D swapchainExtent = {
        .width = width,
        .height = height,
    };

    luaL_Reg luaRegs[] = {
        {"loadAudio", luaLoadAudio},
        {"unloadAudio", luaUnloadAudio},
        {"getAudioPlayer", luaGetAudioPlayer},
        {"releaseAudioPlayer", luaReleaseAudioPlayer},
        {"playAudio", luaPlayAudio},
        {"pauseAudio", luaPauseAudio},
        {"stopAudio", luaStopAudio},
        {"setAudioPosition", luaSetAudioPosition},
        {NULL, NULL},
    };

    LuaLibrary audioLibrary = {
        .name = "audio",
        .luaRegCount = sizeof(luaRegs) / sizeof(luaRegs[0]),
        .luaRegs = luaRegs,
    };

    LuaLibrary luaLibraries[] = {
        audioLibrary,
    };

    NSString *assetsPath =
        [resourcePath stringByAppendingPathComponent:@"assets"];
    self.pTknContext = createTknContextPtr(
        [assetsPath UTF8String], sizeof(luaLibraries) / sizeof(luaLibraries[0]),
        luaLibraries, 2, vkSurfaceFormatKHR, VK_PRESENT_MODE_FIFO_KHR,
        _vkInstance, _vkSurface, swapchainExtent);
}

- (void)teardownEngine {
    destroyTknContextPtr(self.pTknContext);
    [self destroyVkSurface];
    [self destroyVkInstance];
}

- (BOOL)updateEngine:(uint32_t)width
              height:(uint32_t)height
       keyCodeStates:(InputState *)keyCodeStates
     mouseCodeStates:(InputState *)mouseCodeStates
     scrollingDeltaX:(CGFloat)scrollingDeltaX
     scrollingDeltaY:(CGFloat)scrollingDeltaY
    mousePositionNDC:(NSPoint)mousePositionNDC;
{
    VkExtent2D swapchainExtent = {
        .width = width,
        .height = height,
    };
    return updateTknContext(self.pTknContext, swapchainExtent, KEY_CODE_COUNT,
                            keyCodeStates, MOUSE_CODE_COUNT, mouseCodeStates,
                            scrollingDeltaX, scrollingDeltaY,
                            mousePositionNDC.x, mousePositionNDC.y);
}

@end
