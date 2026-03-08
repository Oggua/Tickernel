#import "EngineBinding.h"

@interface AppView : MTKView <MTKViewDelegate, NSTextInputClient>

@property(nonatomic, assign) InputState *keyCodeStates;
@property(nonatomic, assign) InputState *mouseCodeStates;
@property(nonatomic, assign) NSPoint mousePositionNDC;
@property(nonatomic, assign) CGFloat scrollingDeltaX;
@property(nonatomic, assign) CGFloat scrollingDeltaY;

@property(nonatomic, strong) EngineBinding *pEngineBinding;
@property(nonatomic, strong) NSMutableString *inputText;
@property(nonatomic, assign) BOOL imeEnabled;

- (void)updateKeyCode:(NSEvent *)event keyState:(InputState)keyState;

@end
