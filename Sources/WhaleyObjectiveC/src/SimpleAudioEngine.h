#if __has_include(<UIKit/UIKit.h>)
#import <Foundation/Foundation.h>
@interface CDSoundSource : NSObject
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
- (void)play;
- (void)stop;
@end
@interface SimpleAudioEngine : NSObject
+ (instancetype)sharedEngine;
- (CDSoundSource *)soundSourceForFile:(NSString *)file;
- (void)pauseBackgroundMusic;
@end
#endif
