#if __has_include(<UIKit/UIKit.h>)
#import "SimpleAudioEngine.h"
@implementation CDSoundSource {
    BOOL _playing;
}
- (BOOL)isPlaying {
    return _playing;
}
- (void)play {
    _playing = YES;
}
- (void)stop {
    _playing = NO;
}
@end
@implementation SimpleAudioEngine
+ (instancetype)sharedEngine {
    static SimpleAudioEngine *e;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        e = [self new];
    });
    return e;
}
- (CDSoundSource *)soundSourceForFile:(NSString *)file {
    return [[[CDSoundSource alloc] init] autorelease];
}
- (void)pauseBackgroundMusic {
}
@end
#endif
