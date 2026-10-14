//
//  Created by Francis Lazenka on 8/11/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Collectible.h"

@implementation Collectible

@synthesize shineAction;

+ (Collectible *)initWithFile:(NSString *)file {
    Collectible *collectible = [Collectible spriteWithSpriteFrameName:file];

    if (collectible) {
        //[[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"coin.plist"];
        NSMutableArray *shineAnimFrames = [NSMutableArray array];
        for (NSInteger i = 1; i <= 8; ++i) {
            [shineAnimFrames addObject:
                                 [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:
                                                                                  [NSString stringWithFormat:@"coin%d.png", i]]];
        }
        CCAnimation *shineAnim = [CCAnimation animationWithSpriteFrames:shineAnimFrames delay:0.1f];
        shineAnim.restoreOriginalFrame = NO;
        collectible.shineAction = [CCRepeatForever actionWithAction:
                                                       [CCAnimate actionWithAnimation:shineAnim]];
        [collectible runAction:collectible.shineAction];
    }

    return collectible;
}

- (void)dealloc {
    self.shineAction = nil;
    [[CCSpriteFrameCache sharedSpriteFrameCache] removeUnusedSpriteFrames];
    [super dealloc];
}

@end
#endif
