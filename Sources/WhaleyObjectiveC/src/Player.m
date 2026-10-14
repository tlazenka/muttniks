//
//  Created by Francis Lazenka on 8/2/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Player.h"

@implementation Player

@synthesize spoutAction;

@synthesize airMode;
@synthesize isMovingLaterally;
@synthesize isDead;
@synthesize hasWon;
@synthesize jumpDiff;
@synthesize yAdd;
@synthesize xAdd;
@synthesize groundYpos;
@synthesize desiredPos;
@synthesize moveAction;

+ (Player *)initDefaults:(NSString *)file {
    return [Player
                 initWithFile:file
                  withAirMode:GROUNDED
        withIsMovingLaterally:NO
                 withJumpDiff:2
                     withYadd:NormYspd
                     withXadd:NormXspd
               withGroundYpos:0
               withDesiredPos:ccp(0, 0)];
}

+ (Player *)initWithFile:(NSString *)file
              withAirMode:(BOOL)airmode
    withIsMovingLaterally:(BOOL)movinglaterally
             withJumpDiff:(BOOL)jumpdiff
                 withYadd:(BOOL)yadd
                 withXadd:(BOOL)xadd
           withGroundYpos:(CGFloat)groundypos
           withDesiredPos:(CGPoint)desiredpos {
    Player *player = [Player spriteWithSpriteFrameName:file];

    if (player) {
        player.airMode = airmode;
        player.isMovingLaterally = movinglaterally;
        player.jumpDiff = jumpdiff;
        player.yAdd = yadd;
        player.xAdd = xadd;
        player.groundYpos = groundypos;
        player.desiredPos = desiredpos;
        player.anchorPoint = ccp(0, 0);
        player.isDead = NO;
        player.hasWon = NO;

        NSString *playerImage = ([GameState gameState].levelsAchieved > NumLevels) ? (@"player-win") : (@"player");

        NSMutableArray *moveAnimFrames = [NSMutableArray array];
        for (NSInteger i = 1; i <= 3; ++i) {
            [moveAnimFrames addObject:
                                [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:
                                                                                 [NSString stringWithFormat:@"%@%d.png", playerImage, i]]];
        }
        CCAnimation *moveAnim = [CCAnimation animationWithSpriteFrames:moveAnimFrames delay:0.25f];
        moveAnim.restoreOriginalFrame = NO;
        player.moveAction = [CCRepeatForever actionWithAction:
                                                 [CCAnimate actionWithAnimation:moveAnim]];
        [player runAction:player.moveAction];
    }

    return player;
}

- (BOOL)sqcky:(CGPoint)position withTileMap:(CCTMXTiledMap *)tileMap {
    NSInteger y = (NSInteger)position.y;
    NSInteger height = (NSInteger)tileMap.tileSize.height;

    switch (self.yAdd) {
        case 1:
            return ((y % height) == 0);
        case 2:
            return ((y % height) == 0)
                   || (((y - 1) % height) == 0);
        case 3:
            return ((y % height) == 0)
                   || (((y - 1) % height) == 0)
                   || (((y - 2) % height) == 0);
    }
    return NO;
}

- (void)dealloc {
    self.moveAction = nil;
    self.spoutAction = nil;
    [[CCSpriteFrameCache sharedSpriteFrameCache] removeUnusedSpriteFrames];

    [super dealloc];
}
@end
#endif
