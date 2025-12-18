#import "EngineBinding.h"

@interface AppView : MTKView <MTKViewDelegate>

@property(nonatomic, assign) InputState *keyCodeStates;
@property(nonatomic, assign) InputState *mouseCodeStates;
@property(nonatomic, assign) NSPoint mousePositionNDC;
@property(nonatomic, assign) CGFloat scrollingDeltaX;
@property(nonatomic, assign) CGFloat scrollingDeltaY;

@property(nonatomic, strong) EngineBinding *pEngineBinding;

- (void)updateKeyCode:(NSEvent *)event keyState:(InputState)keyState;

@end
