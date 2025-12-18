#import "tknLua.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <vulkan/vulkan.h>
#import <vulkan/vulkan_macos.h>
static NSString *const AppName = @"Tickernel";

typedef enum {
    KEY_CODE_A = 0,
    KEY_CODE_B = 1,
    KEY_CODE_C = 2,
    KEY_CODE_D = 3,
    KEY_CODE_E = 4,
    KEY_CODE_F = 5,
    KEY_CODE_G = 6,
    KEY_CODE_H = 7,
    KEY_CODE_I = 8,
    KEY_CODE_J = 9,
    KEY_CODE_K = 10,
    KEY_CODE_L = 11,
    KEY_CODE_M = 12,
    KEY_CODE_N = 13,
    KEY_CODE_O = 14,
    KEY_CODE_P = 15,
    KEY_CODE_Q = 16,
    KEY_CODE_R = 17,
    KEY_CODE_S = 18,
    KEY_CODE_T = 19,
    KEY_CODE_U = 20,
    KEY_CODE_V = 21,
    KEY_CODE_W = 22,
    KEY_CODE_X = 23,
    KEY_CODE_Y = 24,
    KEY_CODE_Z = 25,
    KEY_CODE_NUM0 = 26,
    KEY_CODE_NUM1 = 27,
    KEY_CODE_NUM2 = 28,
    KEY_CODE_NUM3 = 29,
    KEY_CODE_NUM4 = 30,
    KEY_CODE_NUM5 = 31,
    KEY_CODE_NUM6 = 32,
    KEY_CODE_NUM7 = 33,
    KEY_CODE_NUM8 = 34,
    KEY_CODE_NUM9 = 35,
    KEY_CODE_ENTER = 36,
    KEY_CODE_ESCAPE = 37,
    KEY_CODE_BACKSPACE = 38,
    KEY_CODE_TAB = 39,
    KEY_CODE_SPACE = 40,
    KEY_CODE_MINUS = 41,
    KEY_CODE_EQUAL = 42,
    KEY_CODE_LEFT_BRACKET = 43,
    KEY_CODE_RIGHT_BRACKET = 44,
    KEY_CODE_BACKSLASH = 45,
    KEY_CODE_SEMICOLON = 46,
    KEY_CODE_APOSTROPHE = 47,
    KEY_CODE_GRAVE = 48,
    KEY_CODE_COMMA = 49,
    KEY_CODE_PERIOD = 50,
    KEY_CODE_SLASH = 51,
    KEY_CODE_CAPS_LOCK = 52,
    KEY_CODE_F1 = 53,
    KEY_CODE_F2 = 54,
    KEY_CODE_F3 = 55,
    KEY_CODE_F4 = 56,
    KEY_CODE_F5 = 57,
    KEY_CODE_F6 = 58,
    KEY_CODE_F7 = 59,
    KEY_CODE_F8 = 60,
    KEY_CODE_F9 = 61,
    KEY_CODE_F10 = 62,
    KEY_CODE_F11 = 63,
    KEY_CODE_F12 = 64,
    KEY_CODE_PRINT_SCREEN = 65,
    KEY_CODE_SCROLL_LOCK = 66,
    KEY_CODE_PAUSE = 67,
    KEY_CODE_INSERT = 68,
    KEY_CODE_HOME = 69,
    KEY_CODE_PAGE_UP = 70,
    KEY_CODE_DELETE = 71,
    KEY_CODE_END = 72,
    KEY_CODE_PAGE_DOWN = 73,
    KEY_CODE_RIGHT = 74,
    KEY_CODE_LEFT = 75,
    KEY_CODE_DOWN = 76,
    KEY_CODE_UP = 77,
    KEY_CODE_NUM_LOCK = 78,
    KEY_CODE_NUMPAD0 = 79,
    KEY_CODE_NUMPAD1 = 80,
    KEY_CODE_NUMPAD2 = 81,
    KEY_CODE_NUMPAD3 = 82,
    KEY_CODE_NUMPAD4 = 83,
    KEY_CODE_NUMPAD5 = 84,
    KEY_CODE_NUMPAD6 = 85,
    KEY_CODE_NUMPAD7 = 86,
    KEY_CODE_NUMPAD8 = 87,
    KEY_CODE_NUMPAD9 = 88,
    KEY_CODE_NUMPAD_DIVIDE = 89,
    KEY_CODE_NUMPAD_MULTIPLY = 90,
    KEY_CODE_NUMPAD_SUBTRACT = 91,
    KEY_CODE_NUMPAD_ADD = 92,
    KEY_CODE_NUMPAD_ENTER = 93,
    KEY_CODE_NUMPAD_DECIMAL = 94,
    KEY_CODE_COUNT = 95
} KeyCode;

typedef enum {
    MOUSE_CODE_LEFT = 0,
    MOUSE_CODE_RIGHT = 1,
    MOUSE_CODE_CENTER = 2,
    MOUSE_CODE_BACK = 4,
    MOUSE_CODE_FORWARD = 5,
    MOUSE_CODE_COUNT = 6,
} MouseCode;

@interface EngineBinding : NSObject

@property(nonatomic, assign) VkSurfaceKHR vkSurface;
@property(nonatomic, assign) TknContext *pTknContext;
@property(nonatomic, assign) VkInstance vkInstance;

- (void)setupEngine:(uint32_t)width
             height:(uint32_t)height
       resourcePath:(NSString *)resourcePath
              pView:(void *)pView;

- (void)teardownEngine;

- (BOOL)updateEngine:(uint32_t)width
              height:(uint32_t)height
       keyCodeStates:(InputState *)keyCodeStates
     mouseCodeStates:(InputState *)mouseCodeStates
     scrollingDeltaX:(CGFloat)scrollingDeltaX
     scrollingDeltaY:(CGFloat)scrollingDeltaY
    mousePositionNDC:(NSPoint)mousePositionNDC;

@end
