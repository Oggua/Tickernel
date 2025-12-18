#import "AudioBinding.h"
@import AVFoundation;

@implementation AudioBinding

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize the audio engine.
        self.audioEngine = [[AVAudioEngine alloc] init];

        // Create and attach a persistent environment node for 3D audio.
        self.environmentNode = [[AVAudioEnvironmentNode alloc] init];
        [self.audioEngine attachNode:self.environmentNode];
        // Connect the environment node to the main mixer.
        [self.audioEngine connect:self.environmentNode
                               to:self.audioEngine.mainMixerNode
                           format:nil];

        self.audioPlayerPool = [NSMutableArray array];
        self.audioFileNameToFile = [NSMutableDictionary dictionary];
        self.audioPlayerNodeToFile = [NSMutableDictionary dictionary];

        NSError *error = nil;
        if (![self.audioEngine startAndReturnError:&error]) {
            NSLog(@"Failed to start audio engine: %@",
                  error.localizedDescription);
        }
    }
    return self;
}

- (void)dealloc {
    // Stop and detach all players in the pool.
    for (AVAudioPlayerNode *player in self.audioPlayerPool) {
        [player stop];
        [self.audioEngine detachNode:player];
    }
    [self.audioPlayerPool removeAllObjects];

    [self.audioFileNameToFile removeAllObjects];
    [self.audioPlayerNodeToFile removeAllObjects];

    // Detach the environment node and stop the engine.
    [self.audioEngine detachNode:self.environmentNode];
    [self.audioEngine stop];
}

- (void)loadAudio:(NSString *)fileName {
    if (self.audioFileNameToFile[fileName]) {
        return;
    }

    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:fileName
                                             withExtension:nil];
    if (!fileURL) {
        NSLog(@"Audio file not found: %@", fileName);
        return;
    }

    NSError *error;
    AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:fileURL
                                                           error:&error];
    if (error) {
        NSLog(@"Failed to load audio file: %@", error.localizedDescription);
        return;
    }

    self.audioFileNameToFile[fileName] = audioFile;
}

- (void)unloadAudio:(NSString *)fileName {
    if (!self.audioFileNameToFile[fileName]) {
        return;
    }
    [self.audioFileNameToFile removeObjectForKey:fileName];
}

- (AVAudioPlayerNode *)getAudioPlayer:(NSString *)fileName {
    AVAudioFile *audioFile = self.audioFileNameToFile[fileName];
    if (!audioFile) {
        NSLog(@"Audio file not loaded: %@", fileName);
        return nil;
    }

    AVAudioPlayerNode *audioPlayer = nil;
    // Reuse an available player from the pool.
    if (self.audioPlayerPool.count > 0) {
        audioPlayer = [self.audioPlayerPool lastObject];
        [self.audioPlayerPool removeLastObject];
    } else {
        // Create a new player and attach it.
        audioPlayer = [[AVAudioPlayerNode alloc] init];
        [self.audioEngine attachNode:audioPlayer];
        // Connect the player node to the persistent environment node.
        [self.audioEngine connect:audioPlayer
                               to:self.environmentNode
                           format:nil];
    }

    // Save the mapping between the player and its audio file.
    NSValue *key = [NSValue valueWithNonretainedObject:audioPlayer];
    self.audioPlayerNodeToFile[key] = audioFile;
    return audioPlayer;
}

- (void)releaseAudioPlayer:(AVAudioPlayerNode *)audioPlayer {
    if (!audioPlayer) {
        return;
    }

    [audioPlayer stop];

    NSValue *key = [NSValue valueWithNonretainedObject:audioPlayer];
    [self.audioPlayerNodeToFile removeObjectForKey:key];
    [self.audioPlayerPool addObject:audioPlayer];
}

- (void)playAudio:(AVAudioPlayerNode *)audioPlayer {
    if (!audioPlayer) {
        return;
    }

    NSValue *key = [NSValue valueWithNonretainedObject:audioPlayer];
    AVAudioFile *audioFile = self.audioPlayerNodeToFile[key];
    if (!audioFile) {
        NSLog(@"No audio file associated with the audio player");
        return;
    }

    // Schedule the file to play and release the player once done.
    [audioPlayer scheduleFile:audioFile atTime:nil completionHandler:nil];
    [audioPlayer play];
}

- (void)pauseAudio:(AVAudioPlayerNode *)audioPlayer {
    if (!audioPlayer) {
        return;
    }
    [audioPlayer pause];
}

- (void)stopAudio:(AVAudioPlayerNode *)audioPlayer {
    if (!audioPlayer) {
        return;
    }
    [audioPlayer stop];
    [self releaseAudioPlayer:audioPlayer];
}

- (void)setAudioPosition:(AVAudioPlayerNode *)audioPlayer
                       X:(float)x
                       Y:(float)y
                       Z:(float)z {
    if (!audioPlayer) {
        return;
    }

    // Use AVAudioMixing protocol to set up the 3D position if supported.
    if ([audioPlayer conformsToProtocol:@protocol(AVAudioMixing)]) {
        id<AVAudioMixing> mixer = (id<AVAudioMixing>)audioPlayer;
        mixer.renderingAlgorithm = AVAudio3DMixingRenderingAlgorithmHRTF;
        mixer.position = AVAudioMake3DPoint(x, y, z);
    } else {
        NSLog(@"Audio player does not support 3D mixing");
    }
}

@end
