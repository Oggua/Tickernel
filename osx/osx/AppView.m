#import "AppView.h"

@implementation AppView

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    BOOL shouldQuit = [self.pEngineBinding updateEngine:size.width
                                                 height:size.height
                                          keyCodeStates:self.keyCodeStates
                                        mouseCodeStates:self.mouseCodeStates
                                        scrollingDeltaX:self.scrollingDeltaX
                                        scrollingDeltaY:self.scrollingDeltaY
                                       mousePositionNDC:self.mousePositionNDC];
    if (shouldQuit) {
        [self.window close];
    }
}

- (void)drawInMTKView:(MTKView *)view {
    NSCAssert([NSThread isMainThread], @"Rendering must be on main thread!");

    BOOL shouldQuit = [self.pEngineBinding updateEngine:view.drawableSize.width
                                                 height:view.drawableSize.height
                                          keyCodeStates:self.keyCodeStates
                                        mouseCodeStates:self.mouseCodeStates
                                        scrollingDeltaX:self.scrollingDeltaX
                                        scrollingDeltaY:self.scrollingDeltaY
                                       mousePositionNDC:self.mousePositionNDC];
    if (shouldQuit) {
        [self.window close];
        return;
    }

    for (int i = 0; i < KEY_CODE_COUNT; i++) {
        if (self.keyCodeStates[i] == INPUT_STATE_UP) {
            self.keyCodeStates[i] = INPUT_STATE_IDLE;
        }
    }
    for (int i = 0; i < MOUSE_CODE_COUNT; i++) {
        if (self.mouseCodeStates[i] == INPUT_STATE_UP) {
            self.mouseCodeStates[i] = INPUT_STATE_IDLE;
        }
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (NSPoint)convertToNDC:(NSPoint)viewPoint {
    NSRect bounds = self.bounds;
    float normalizedX = 1 - viewPoint.x / bounds.size.width;
    float normalizedY = 1 - viewPoint.y / bounds.size.height;
    float ndcX = normalizedX * 2.0f - 1.0f;
    float ndcY = normalizedY * 2.0f - 1.0f;
    return NSMakePoint(ndcX, ndcY);
}

- (NSPoint)convertToNDCWithTopOrigin:(NSPoint)viewPoint {
    NSRect bounds = self.bounds;
    float normalizedX = viewPoint.x / bounds.size.width;
    float normalizedY = 1.0f - (viewPoint.y / bounds.size.height);
    float ndcX = normalizedX * 2.0f - 1.0f;
    float ndcY = normalizedY * 2.0f - 1.0f;
    return NSMakePoint(ndcX, ndcY);
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint viewPoint = [self convertPoint:location fromView:nil];
    self.mousePositionNDC = [self convertToNDC:viewPoint];
    [super mouseMoved:event];
}

- (void)mouseDragged:(NSEvent *)event{
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint viewPoint = [self convertPoint:location fromView:nil];
    self.mousePositionNDC = [self convertToNDC:viewPoint];
    [super mouseDragged:event];
}

- (void)rightMouseDragged:(NSEvent *)event{
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint viewPoint = [self convertPoint:location fromView:nil];
    self.mousePositionNDC = [self convertToNDC:viewPoint];
    [super rightMouseDragged:event];
}

- (void)otherMouseDragged:(NSEvent *)event{
    NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
    NSPoint viewPoint = [self convertPoint:location fromView:nil];
    self.mousePositionNDC = [self convertToNDC:viewPoint];
    [super otherMouseDragged:event];
}

- (void)mouseDown:(NSEvent *)event {
    self.mouseCodeStates[event.buttonNumber] = INPUT_STATE_DOWN;
    [super mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event {
    self.mouseCodeStates[event.buttonNumber] = INPUT_STATE_UP;
    [super mouseUp:event];
}

- (void)rightMouseDown:(NSEvent *)event {
    self.mouseCodeStates[event.buttonNumber] = INPUT_STATE_DOWN;
    [super rightMouseDown:event];
}

- (void)rightMouseUp:(NSEvent *)event {
    self.mouseCodeStates[event.buttonNumber] = INPUT_STATE_UP;
    [super rightMouseDown:event];
}

- (void)otherMouseDown:(NSEvent *)event {
    NSAssert(event.buttonNumber < MOUSE_CODE_COUNT && event.buttonNumber > 0,
             @"event.buttonNumber: %d is out of range!",
             (int)event.buttonNumber);
    self.mouseCodeStates[event.buttonNumber] = INPUT_STATE_DOWN;
    [super otherMouseDown:event];
}

- (void)otherMouseUp:(NSEvent *)event {
    NSAssert(event.buttonNumber < MOUSE_CODE_COUNT && event.buttonNumber > 0,
             @"event.buttonNumber: %d is out of range!",
             (int)event.buttonNumber);
    self.mouseCodeStates[event.buttonNumber] = INPUT_STATE_UP;
    [super otherMouseUp:event];
}

- (void)scrollWheel:(NSEvent *)event {
    self.scrollingDeltaX = event.scrollingDeltaX;
    self.scrollingDeltaY = event.scrollingDeltaY;
    [super scrollWheel:event];
}

- (void)keyDown:(NSEvent *)event {
    [self updateKeyCode:event keyState:INPUT_STATE_DOWN];
    [super keyDown:event];
}

- (void)keyUp:(NSEvent *)event {
    [self updateKeyCode:event keyState:INPUT_STATE_UP];
    [super keyUp:event];
}

- (void)updateKeyCode:(NSEvent *)event keyState:(InputState)inputState {

    // Map NSEvent key codes to KeyCode enum values
    switch (event.keyCode) {
    case 0:
        self.keyCodeStates[KEY_CODE_A] = inputState;
        break;
    case 1:
        self.keyCodeStates[KEY_CODE_S] = inputState;
        break;
    case 2:
        self.keyCodeStates[KEY_CODE_D] = inputState;
        break;
    case 3:
        self.keyCodeStates[KEY_CODE_F] = inputState;
        break;
    case 4:
        self.keyCodeStates[KEY_CODE_H] = inputState;
        break;
    case 5:
        self.keyCodeStates[KEY_CODE_G] = inputState;
        break;
    case 6:
        self.keyCodeStates[KEY_CODE_Z] = inputState;
        break;
    case 7:
        self.keyCodeStates[KEY_CODE_X] = inputState;
        break;
    case 8:
        self.keyCodeStates[KEY_CODE_C] = inputState;
        break;
    case 9:
        self.keyCodeStates[KEY_CODE_V] = inputState;
        break;
    case 11:
        self.keyCodeStates[KEY_CODE_B] = inputState;
        break;
    case 12:
        self.keyCodeStates[KEY_CODE_Q] = inputState;
        break;
    case 13:
        self.keyCodeStates[KEY_CODE_W] = inputState;
        break;
    case 14:
        self.keyCodeStates[KEY_CODE_E] = inputState;
        break;
    case 15:
        self.keyCodeStates[KEY_CODE_R] = inputState;
        break;
    case 16:
        self.keyCodeStates[KEY_CODE_Y] = inputState;
        break;
    case 17:
        self.keyCodeStates[KEY_CODE_T] = inputState;
        break;
    case 18:
        self.keyCodeStates[KEY_CODE_NUM1] = inputState;
        break;
    case 19:
        self.keyCodeStates[KEY_CODE_NUM2] = inputState;
        break;
    case 20:
        self.keyCodeStates[KEY_CODE_NUM3] = inputState;
        break;
    case 21:
        self.keyCodeStates[KEY_CODE_NUM4] = inputState;
        break;
    case 22:
        self.keyCodeStates[KEY_CODE_NUM6] = inputState;
        break;
    case 23:
        self.keyCodeStates[KEY_CODE_NUM5] = inputState;
        break;
    case 24:
        self.keyCodeStates[KEY_CODE_EQUAL] = inputState;
        break;
    case 25:
        self.keyCodeStates[KEY_CODE_NUM9] = inputState;
        break;
    case 26:
        self.keyCodeStates[KEY_CODE_NUM7] = inputState;
        break;
    case 27:
        self.keyCodeStates[KEY_CODE_MINUS] = inputState;
        break;
    case 28:
        self.keyCodeStates[KEY_CODE_NUM8] = inputState;
        break;
    case 29:
        self.keyCodeStates[KEY_CODE_NUM0] = inputState;
        break;
    case 30:
        self.keyCodeStates[KEY_CODE_RIGHT_BRACKET] = inputState;
        break;
    case 31:
        self.keyCodeStates[KEY_CODE_O] = inputState;
        break;
    case 32:
        self.keyCodeStates[KEY_CODE_U] = inputState;
        break;
    case 33:
        self.keyCodeStates[KEY_CODE_LEFT_BRACKET] = inputState;
        break;
    case 34:
        self.keyCodeStates[KEY_CODE_I] = inputState;
        break;
    case 35:
        self.keyCodeStates[KEY_CODE_P] = inputState;
        break;
    case 36:
        self.keyCodeStates[KEY_CODE_ENTER] = inputState;
        break;
    case 37:
        self.keyCodeStates[KEY_CODE_L] = inputState;
        break;
    case 38:
        self.keyCodeStates[KEY_CODE_J] = inputState;
        break;
    case 39:
        self.keyCodeStates[KEY_CODE_APOSTROPHE] = inputState;
        break;
    case 40:
        self.keyCodeStates[KEY_CODE_K] = inputState;
        break;
    case 41:
        self.keyCodeStates[KEY_CODE_SEMICOLON] = inputState;
        break;
    case 42:
        self.keyCodeStates[KEY_CODE_BACKSLASH] = inputState;
        break;
    case 43:
        self.keyCodeStates[KEY_CODE_COMMA] = inputState;
        break;
    case 44:
        self.keyCodeStates[KEY_CODE_SLASH] = inputState;
        break;
    case 45:
        self.keyCodeStates[KEY_CODE_N] = inputState;
        break;
    case 46:
        self.keyCodeStates[KEY_CODE_M] = inputState;
        break;
    case 47:
        self.keyCodeStates[KEY_CODE_PERIOD] = inputState;
        break;
    case 48:
        self.keyCodeStates[KEY_CODE_TAB] = inputState;
        break;
    case 49:
        self.keyCodeStates[KEY_CODE_SPACE] = inputState;
        break;
    case 50:
        self.keyCodeStates[KEY_CODE_GRAVE] = inputState;
        break;
    case 51:
        self.keyCodeStates[KEY_CODE_BACKSPACE] = inputState;
        break;
    case 53:
        self.keyCodeStates[KEY_CODE_ESCAPE] = inputState;
        break;
    case 65:
        self.keyCodeStates[KEY_CODE_NUMPAD_DECIMAL] = inputState;
        break;
    case 67:
        self.keyCodeStates[KEY_CODE_NUMPAD_MULTIPLY] = inputState;
        break;
    case 69:
        self.keyCodeStates[KEY_CODE_NUMPAD_ADD] = inputState;
        break;
        //        case 71: self.keyCodes[KEY_CODE_NUMPAD_CLEAR] = keyDown;
        //        break;
    case 75:
        self.keyCodeStates[KEY_CODE_NUMPAD_DIVIDE] = inputState;
        break;
    case 76:
        self.keyCodeStates[KEY_CODE_NUMPAD_ENTER] = inputState;
        break;
    case 78:
        self.keyCodeStates[KEY_CODE_NUMPAD_SUBTRACT] = inputState;
        break;
        //        case 81: self.keyCodes[KEY_CODE_NUMPAD_EQUAL] = keyDown;
        //        break;
    case 82:
        self.keyCodeStates[KEY_CODE_NUMPAD0] = inputState;
        break;
    case 83:
        self.keyCodeStates[KEY_CODE_NUMPAD1] = inputState;
        break;
    case 84:
        self.keyCodeStates[KEY_CODE_NUMPAD2] = inputState;
        break;
    case 85:
        self.keyCodeStates[KEY_CODE_NUMPAD3] = inputState;
        break;
    case 86:
        self.keyCodeStates[KEY_CODE_NUMPAD4] = inputState;
        break;
    case 87:
        self.keyCodeStates[KEY_CODE_NUMPAD5] = inputState;
        break;
    case 88:
        self.keyCodeStates[KEY_CODE_NUMPAD6] = inputState;
        break;
    case 89:
        self.keyCodeStates[KEY_CODE_NUMPAD7] = inputState;
        break;
    case 91:
        self.keyCodeStates[KEY_CODE_NUMPAD8] = inputState;
        break;
    case 92:
        self.keyCodeStates[KEY_CODE_NUMPAD9] = inputState;
        break;
    case 96:
        self.keyCodeStates[KEY_CODE_F5] = inputState;
        break;
    case 97:
        self.keyCodeStates[KEY_CODE_F6] = inputState;
        break;
    case 98:
        self.keyCodeStates[KEY_CODE_F7] = inputState;
        break;
    case 99:
        self.keyCodeStates[KEY_CODE_F3] = inputState;
        break;
    case 100:
        self.keyCodeStates[KEY_CODE_F8] = inputState;
        break;
    case 101:
        self.keyCodeStates[KEY_CODE_F9] = inputState;
        break;
    case 103:
        self.keyCodeStates[KEY_CODE_F11] = inputState;
        break;
        //        case 105: self.keyCodes[KEY_CODE_F13] = keyDown; break;
        //        case 106: self.keyCodes[KEY_CODE_F16] = keyDown; break;
        //        case 107: self.keyCodes[KEY_CODE_F14] = keyDown; break;
    case 109:
        self.keyCodeStates[KEY_CODE_F10] = inputState;
        break;
    case 111:
        self.keyCodeStates[KEY_CODE_F12] = inputState;
        break;
        //        case 113: self.keyCodes[KEY_CODE_F15] = keyDown; break;
        //        case 114: self.keyCodes[KEY_CODE_HELP] = keyDown; break;
    case 115:
        self.keyCodeStates[KEY_CODE_HOME] = inputState;
        break;
    case 116:
        self.keyCodeStates[KEY_CODE_PAGE_UP] = inputState;
        break;
    case 117:
        self.keyCodeStates[KEY_CODE_DELETE] = inputState;
        break;
    case 118:
        self.keyCodeStates[KEY_CODE_F4] = inputState;
        break;
    case 119:
        self.keyCodeStates[KEY_CODE_END] = inputState;
        break;
    case 120:
        self.keyCodeStates[KEY_CODE_F2] = inputState;
        break;
    case 121:
        self.keyCodeStates[KEY_CODE_PAGE_DOWN] = inputState;
        break;
    case 122:
        self.keyCodeStates[KEY_CODE_F1] = inputState;
        break;
    case 123:
        self.keyCodeStates[KEY_CODE_LEFT] = inputState;
        break;
    case 124:
        self.keyCodeStates[KEY_CODE_RIGHT] = inputState;
        break;
    case 125:
        self.keyCodeStates[KEY_CODE_DOWN] = inputState;
        break;
    case 126:
        self.keyCodeStates[KEY_CODE_UP] = inputState;
        break;
    default:
        break;
    }
}

- (instancetype)initWithFrame:(CGRect)frameRect device:(id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    self.delegate = self;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    self.preferredFramesPerSecond = 10;

    NSTrackingArea *trackingArea = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:(NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited |
                      NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect)
               owner:self
            userInfo:nil];
    [self addTrackingArea:trackingArea];

    self.keyCodeStates = calloc(KEY_CODE_COUNT, sizeof(InputState));
    self.mouseCodeStates = calloc(MOUSE_CODE_COUNT, sizeof(InputState));

    self.pEngineBinding = [[EngineBinding alloc] init];

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    [self.pEngineBinding setupEngine:self.drawableSize.width
                              height:self.drawableSize.height
                        resourcePath:resourcePath
                               pView:(__bridge void *)self];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(windowWillClose:)
               name:NSWindowWillCloseNotification
             object:nil];
    return self;
}

- (void)windowWillClose:(NSNotification *)notification {
    [self.pEngineBinding teardownEngine];
    free(self.keyCodeStates);
    free(self.mouseCodeStates);
}

@end
