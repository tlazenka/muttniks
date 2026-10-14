//
//  Created by Francis Lazenka on 7/25/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Collectible.h"
#import "GameObject.h"
#import "GameState.h"
#import "Hazard.h"
#import "Helpers.h"
#import "Level.h"
#import "MainMenu.h"
#import "Player.h"
#import "Projectile.h"
#import "SimpleAudioEngine.h"
#import "WhaleyHud.h"
#import "cocos2d.h"

@class WhaleyHud;
@class WhaleyWinScreen;

FOUNDATION_EXPORT const NSInteger FLAME_DIMMED;
FOUNDATION_EXPORT const NSInteger FLAME_OPAQUE;
FOUNDATION_EXPORT const NSInteger TouchBubbleFudgeOffset;

FOUNDATION_EXPORT void WhaleySrcTrajectoryReset(void);
FOUNDATION_EXPORT NSUInteger WhaleySrcTrajectorySampleCount(void);
FOUNDATION_EXPORT NSTimeInterval WhaleySrcTrajectoryFirstTime(void);
FOUNDATION_EXPORT NSTimeInterval WhaleySrcTrajectoryLastTime(void);
FOUNDATION_EXPORT NSTimeInterval WhaleySrcSemanticTime(void);
FOUNDATION_EXPORT BOOL WhaleySrcTrajectoryProjectPlayer(Player *player, NSTimeInterval seconds);

@interface Whaley : CCLayer {
    NSInteger _numBubbles;
    CGFloat _ceilingFactor;
    BOOL _waterLevel;
    BOOL _touchSustained;
    NSInteger _phase;
    BOOL _hasInfiniteBubbles;
    NSInteger _defaultBounces;
    CGPoint _currentLocation;
    BOOL _allowMiddleBounce;
}

@property (nonatomic, retain) CCTMXTiledMap *tileMap;
@property (nonatomic, retain) CCTMXLayer *background;
@property (nonatomic, retain) CCTMXLayer *meta;
@property (nonatomic, retain) Player *player;
@property (nonatomic, retain) NSMutableArray *hazards;
@property (nonatomic, retain) NSMutableArray *projectiles;
@property (nonatomic, retain) NSMutableArray *collectibles;
@property (nonatomic, retain) WhaleyHud *hud;
@property (nonatomic, retain) WhaleyWinScreen *winScreen;
@property (nonatomic, readwrite) BOOL isPaused;
@property (nonatomic, retain) GameObject *goal;
@property (nonatomic, retain) Level *level;

@property (nonatomic, retain) NSString *tmxFile;

@property (nonatomic, retain) CDSoundSource *bounceSound;
@property (nonatomic, retain) CDSoundSource *flameSound;
@property (nonatomic, retain) CDSoundSource *jumpSound;
@property (nonatomic, retain) CDSoundSource *collectibleSound;
@property (nonatomic, retain) CDSoundSource *goalSound;
@property (nonatomic, retain) CDSoundSource *bgSound;

@property (nonatomic, retain) CCSpriteBatchNode *spoutSpriteSheet;
@property (nonatomic, retain) CCSprite *spout;
@property (nonatomic, retain) NSString *bubbleFileName;

- (BOOL)playerIsRestingOnGroundTile;

- (void)releaseRetained;

+ (id)scene:(Level *)level withGameMode:(NSInteger)gameMode;

- (id)initWithLevel:(Level *)level withGameMode:(NSInteger)gameMode;

- (void)switchPhase:(ccTime)dt;

- (NSInteger)calculateScore;

@end
#endif
