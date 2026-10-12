//
//  Created by Francis Lazenka on 9/8/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "WhaleyHud.h"
#import "WhaleyBootstrap.h"
@implementation WhaleyWinScreen
+ (instancetype)initAsColorLayer:(Whaley *)gameLayer {
    WhaleyWinScreen *v = [[[self alloc] init] autorelease];
    v.gameLayer = gameLayer;
    return v;
}
- (void)winLevel:(id)sender {
    WhaleySrcAdvanceAfterWin();
}
@end
@implementation WhaleyHud
+ (instancetype)initAsColorLayer:(Whaley *)gameLayer {
    WhaleyHud *v = [[[self alloc] init] autorelease];
    v.gameLayer = gameLayer;
    return v;
}
- (void)pauseGame:(id)sender {
}
- (void)resumeLevel:(id)sender {
}
- (void)replayLevel:(id)sender {
    WhaleySrcReplayCurrentLevel();
}
- (void)setWarning:(BOOL)value {
}
- (void)updateScore {
}
@end
#endif
