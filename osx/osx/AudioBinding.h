#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface AudioBinding : NSObject
// Private properties
@property(nonatomic, strong) AVAudioEngine *audioEngine;
@property(nonatomic, strong) AVAudioEnvironmentNode *environmentNode;
@property(nonatomic, strong)
    NSMutableArray<AVAudioPlayerNode *> *audioPlayerPool;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, AVAudioFile *> *audioFileNameToFile;
@property(nonatomic, strong)
    NSMutableDictionary<NSValue *, AVAudioFile *> *audioPlayerNodeToFile;

- (instancetype)init;
- (void)loadAudio:(NSString *)fileName;
- (void)unloadAudio:(NSString *)fileName;

- (AVAudioPlayerNode *)getAudioPlayer:(NSString *)fileName;
- (void)releaseAudioPlayer:(AVAudioPlayerNode *)audioPlayer;
- (void)playAudio:(AVAudioPlayerNode *)audioPlayer;
- (void)pauseAudio:(AVAudioPlayerNode *)audioPlayer;
- (void)stopAudio:(AVAudioPlayerNode *)audioPlayer;
- (void)setAudioPosition:(AVAudioPlayerNode *)audioPlayer
                       X:(float)x
                       Y:(float)y
                       Z:(float)z;
@end
