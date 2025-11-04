#import "AppView.h"

@implementation AppView

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self.pEngineBinding updateEngine:size.width height:size.height keyStates:self.keyCodeStates];
}

- (void)drawInMTKView:(MTKView *)view {
    NSCAssert([NSThread isMainThread], @"Rendering must be on main thread!");
    
    [self.pEngineBinding updateEngine:view.drawableSize.width
                               height:view.drawableSize.height
                             keyStates:self.keyCodeStates];
    
    // Transition key states: DOWN/UP -> IDLE after frame update
    for (int i = 0; i < KEY_CODE_COUNT; i++) {
        if (self.keyCodeStates[i] == KEY_STATE_UP) {
            self.keyCodeStates[i] = KEY_STATE_IDLE;
        }
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    //    NSLog(@"Key Down: %@", characters);
    [self updateKeyCode:event keyState:KEY_STATE_DOWN];
}

- (void)keyUp:(NSEvent *)event {
    //    NSLog(@"Key Up: %@", characters);
    [self updateKeyCode:event keyState:KEY_STATE_UP];
}

- (void)updateKeyCode:(NSEvent *)event keyState:(KeyState)keyState {
    
    // Map NSEvent key codes to KeyCode enum values
    switch (event.keyCode) {
    case 0:
        self.keyCodeStates[KEY_CODE_A] = keyState;
        break;
    case 1:
        self.keyCodeStates[KEY_CODE_S] = keyState;
        break;
    case 2:
        self.keyCodeStates[KEY_CODE_D] = keyState;
        break;
    case 3:
        self.keyCodeStates[KEY_CODE_F] = keyState;
        break;
    case 4:
        self.keyCodeStates[KEY_CODE_H] = keyState;
        break;
    case 5:
        self.keyCodeStates[KEY_CODE_G] = keyState;
        break;
    case 6:
        self.keyCodeStates[KEY_CODE_Z] = keyState;
        break;
    case 7:
        self.keyCodeStates[KEY_CODE_X] = keyState;
        break;
    case 8:
        self.keyCodeStates[KEY_CODE_C] = keyState;
        break;
    case 9:
        self.keyCodeStates[KEY_CODE_V] = keyState;
        break;
    case 11:
        self.keyCodeStates[KEY_CODE_B] = keyState;
        break;
    case 12:
        self.keyCodeStates[KEY_CODE_Q] = keyState;
        break;
    case 13:
        self.keyCodeStates[KEY_CODE_W] = keyState;
        break;
    case 14:
        self.keyCodeStates[KEY_CODE_E] = keyState;
        break;
    case 15:
        self.keyCodeStates[KEY_CODE_R] = keyState;
        break;
    case 16:
        self.keyCodeStates[KEY_CODE_Y] = keyState;
        break;
    case 17:
        self.keyCodeStates[KEY_CODE_T] = keyState;
        break;
    case 18:
        self.keyCodeStates[KEY_CODE_NUM1] = keyState;
        break;
    case 19:
        self.keyCodeStates[KEY_CODE_NUM2] = keyState;
        break;
    case 20:
        self.keyCodeStates[KEY_CODE_NUM3] = keyState;
        break;
    case 21:
        self.keyCodeStates[KEY_CODE_NUM4] = keyState;
        break;
    case 22:
        self.keyCodeStates[KEY_CODE_NUM6] = keyState;
        break;
    case 23:
        self.keyCodeStates[KEY_CODE_NUM5] = keyState;
        break;
    case 24:
        self.keyCodeStates[KEY_CODE_EQUAL] = keyState;
        break;
    case 25:
        self.keyCodeStates[KEY_CODE_NUM9] = keyState;
        break;
    case 26:
        self.keyCodeStates[KEY_CODE_NUM7] = keyState;
        break;
    case 27:
        self.keyCodeStates[KEY_CODE_MINUS] = keyState;
        break;
    case 28:
        self.keyCodeStates[KEY_CODE_NUM8] = keyState;
        break;
    case 29:
        self.keyCodeStates[KEY_CODE_NUM0] = keyState;
        break;
    case 30:
        self.keyCodeStates[KEY_CODE_RIGHT_BRACKET] = keyState;
        break;
    case 31:
        self.keyCodeStates[KEY_CODE_O] = keyState;
        break;
    case 32:
        self.keyCodeStates[KEY_CODE_U] = keyState;
        break;
    case 33:
        self.keyCodeStates[KEY_CODE_LEFT_BRACKET] = keyState;
        break;
    case 34:
        self.keyCodeStates[KEY_CODE_I] = keyState;
        break;
    case 35:
        self.keyCodeStates[KEY_CODE_P] = keyState;
        break;
    case 36:
        self.keyCodeStates[KEY_CODE_ENTER] = keyState;
        break;
    case 37:
        self.keyCodeStates[KEY_CODE_L] = keyState;
        break;
    case 38:
        self.keyCodeStates[KEY_CODE_J] = keyState;
        break;
    case 39:
        self.keyCodeStates[KEY_CODE_APOSTROPHE] = keyState;
        break;
    case 40:
        self.keyCodeStates[KEY_CODE_K] = keyState;
        break;
    case 41:
        self.keyCodeStates[KEY_CODE_SEMICOLON] = keyState;
        break;
    case 42:
        self.keyCodeStates[KEY_CODE_BACKSLASH] = keyState;
        break;
    case 43:
        self.keyCodeStates[KEY_CODE_COMMA] = keyState;
        break;
    case 44:
        self.keyCodeStates[KEY_CODE_SLASH] = keyState;
        break;
    case 45:
        self.keyCodeStates[KEY_CODE_N] = keyState;
        break;
    case 46:
        self.keyCodeStates[KEY_CODE_M] = keyState;
        break;
    case 47:
        self.keyCodeStates[KEY_CODE_PERIOD] = keyState;
        break;
    case 48:
        self.keyCodeStates[KEY_CODE_TAB] = keyState;
        break;
    case 49:
        self.keyCodeStates[KEY_CODE_SPACE] = keyState;
        break;
    case 50:
        self.keyCodeStates[KEY_CODE_GRAVE] = keyState;
        break;
    case 51:
        self.keyCodeStates[KEY_CODE_BACKSPACE] = keyState;
        break;
    case 53:
        self.keyCodeStates[KEY_CODE_ESCAPE] = keyState;
        break;
    case 65:
        self.keyCodeStates[KEY_CODE_NUMPAD_DECIMAL] = keyState;
        break;
    case 67:
        self.keyCodeStates[KEY_CODE_NUMPAD_MULTIPLY] = keyState;
        break;
    case 69:
        self.keyCodeStates[KEY_CODE_NUMPAD_ADD] = keyState;
        break;
        //        case 71: self.keyCodes[KEY_CODE_NUMPAD_CLEAR] = keyDown;
        //        break;
    case 75:
        self.keyCodeStates[KEY_CODE_NUMPAD_DIVIDE] = keyState;
        break;
    case 76:
        self.keyCodeStates[KEY_CODE_NUMPAD_ENTER] = keyState;
        break;
    case 78:
        self.keyCodeStates[KEY_CODE_NUMPAD_SUBTRACT] = keyState;
        break;
        //        case 81: self.keyCodes[KEY_CODE_NUMPAD_EQUAL] = keyDown;
        //        break;
    case 82:
        self.keyCodeStates[KEY_CODE_NUMPAD0] = keyState;
        break;
    case 83:
        self.keyCodeStates[KEY_CODE_NUMPAD1] = keyState;
        break;
    case 84:
        self.keyCodeStates[KEY_CODE_NUMPAD2] = keyState;
        break;
    case 85:
        self.keyCodeStates[KEY_CODE_NUMPAD3] = keyState;
        break;
    case 86:
        self.keyCodeStates[KEY_CODE_NUMPAD4] = keyState;
        break;
    case 87:
        self.keyCodeStates[KEY_CODE_NUMPAD5] = keyState;
        break;
    case 88:
        self.keyCodeStates[KEY_CODE_NUMPAD6] = keyState;
        break;
    case 89:
        self.keyCodeStates[KEY_CODE_NUMPAD7] = keyState;
        break;
    case 91:
        self.keyCodeStates[KEY_CODE_NUMPAD8] = keyState;
        break;
    case 92:
        self.keyCodeStates[KEY_CODE_NUMPAD9] = keyState;
        break;
    case 96:
        self.keyCodeStates[KEY_CODE_F5] = keyState;
        break;
    case 97:
        self.keyCodeStates[KEY_CODE_F6] = keyState;
        break;
    case 98:
        self.keyCodeStates[KEY_CODE_F7] = keyState;
        break;
    case 99:
        self.keyCodeStates[KEY_CODE_F3] = keyState;
        break;
    case 100:
        self.keyCodeStates[KEY_CODE_F8] = keyState;
        break;
    case 101:
        self.keyCodeStates[KEY_CODE_F9] = keyState;
        break;
    case 103:
        self.keyCodeStates[KEY_CODE_F11] = keyState;
        break;
        //        case 105: self.keyCodes[KEY_CODE_F13] = keyDown; break;
        //        case 106: self.keyCodes[KEY_CODE_F16] = keyDown; break;
        //        case 107: self.keyCodes[KEY_CODE_F14] = keyDown; break;
    case 109:
        self.keyCodeStates[KEY_CODE_F10] = keyState;
        break;
    case 111:
        self.keyCodeStates[KEY_CODE_F12] = keyState;
        break;
        //        case 113: self.keyCodes[KEY_CODE_F15] = keyDown; break;
        //        case 114: self.keyCodes[KEY_CODE_HELP] = keyDown; break;
    case 115:
        self.keyCodeStates[KEY_CODE_HOME] = keyState;
        break;
    case 116:
        self.keyCodeStates[KEY_CODE_PAGE_UP] = keyState;
        break;
    case 117:
        self.keyCodeStates[KEY_CODE_DELETE] = keyState;
        break;
    case 118:
        self.keyCodeStates[KEY_CODE_F4] = keyState;
        break;
    case 119:
        self.keyCodeStates[KEY_CODE_END] = keyState;
        break;
    case 120:
        self.keyCodeStates[KEY_CODE_F2] = keyState;
        break;
    case 121:
        self.keyCodeStates[KEY_CODE_PAGE_DOWN] = keyState;
        break;
    case 122:
        self.keyCodeStates[KEY_CODE_F1] = keyState;
        break;
    case 123:
        self.keyCodeStates[KEY_CODE_LEFT] = keyState;
        break;
    case 124:
        self.keyCodeStates[KEY_CODE_RIGHT] = keyState;
        break;
    case 125:
        self.keyCodeStates[KEY_CODE_DOWN] = keyState;
        break;
    case 126:
        self.keyCodeStates[KEY_CODE_UP] = keyState;
        break;
    default:
        break;
    }
}

- (instancetype)initWithFrame:(CGRect)frameRect device:(id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    self.delegate = self;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    self.preferredFramesPerSecond = 1;
    self.keyCodeStates = calloc(KEY_CODE_COUNT, sizeof(KeyState));
    self.pEngineBinding = [[EngineBinding alloc] init];

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    [self.pEngineBinding setupEngine:self.drawableSize.width
                              height:self.drawableSize.height
                        resourcePath:resourcePath
                               pView:(__bridge void *)self];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:nil];
    return self;
}

- (void)windowWillClose:(NSNotification *)notification {
    [self.pEngineBinding teardownEngine];
    free(self.keyCodeStates);
}

@end
