//
//  Created by Francis Lazenka on 7/25/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "WhaleyScene.h"
#import "GameState.h"

static NSMutableArray *WhaleyTrajectoryTimes = nil;
static NSMutableArray *WhaleyTrajectoryPositions = nil;
static NSTimeInterval WhaleySemanticElapsedTime = 0;

void WhaleySrcTrajectoryReset(void) {
    [WhaleyTrajectoryTimes release];
    [WhaleyTrajectoryPositions release];
    WhaleyTrajectoryTimes = [[NSMutableArray alloc] init];
    WhaleyTrajectoryPositions = [[NSMutableArray alloc] init];
    WhaleySemanticElapsedTime = 0;
}

static void WhaleySrcTrajectoryRecord(Player *player, ccTime dt) {
    if (!player) {
        return;
    }
    if (!WhaleyTrajectoryTimes) {
        WhaleySrcTrajectoryReset();
    }
    WhaleySemanticElapsedTime += MAX(0, dt);
    [WhaleyTrajectoryTimes addObject:@(WhaleySemanticElapsedTime)];
    [WhaleyTrajectoryPositions addObject:[NSValue valueWithCGPoint:player.position]];
    const NSUInteger maximumSamples = 36000;
    if (WhaleyTrajectoryTimes.count > maximumSamples) {
        [WhaleyTrajectoryTimes removeObjectAtIndex:0];
        [WhaleyTrajectoryPositions removeObjectAtIndex:0];
    }
}

NSUInteger WhaleySrcTrajectorySampleCount(void) { return WhaleyTrajectoryTimes.count; }
NSTimeInterval WhaleySrcTrajectoryFirstTime(void) { return WhaleyTrajectoryTimes.count ? [WhaleyTrajectoryTimes[0] doubleValue] : 0; }
NSTimeInterval WhaleySrcTrajectoryLastTime(void) { return WhaleyTrajectoryTimes.count ? [[WhaleyTrajectoryTimes lastObject] doubleValue] : 0; }
NSTimeInterval WhaleySrcSemanticTime(void) { return WhaleySemanticElapsedTime; }

BOOL WhaleySrcTrajectoryProjectPlayer(Player *player, NSTimeInterval seconds) {
    NSUInteger count = WhaleyTrajectoryTimes.count;
    if (!player || count == 0) {
        return NO;
    }
    NSTimeInterval target = MAX(0, seconds);
    if (target <= [WhaleyTrajectoryTimes[0] doubleValue]) {
        player.position = [WhaleyTrajectoryPositions[0] CGPointValue];
        return YES;
    }
    if (target >= [[WhaleyTrajectoryTimes lastObject] doubleValue]) {
        player.position = [[WhaleyTrajectoryPositions lastObject] CGPointValue];
        return YES;
    }
    for (NSUInteger i = 1; i < count; ++i) {
        NSTimeInterval upperTime = [WhaleyTrajectoryTimes[i] doubleValue];
        if (upperTime < target) {
            continue;
        }
        NSTimeInterval lowerTime = [WhaleyTrajectoryTimes[i - 1] doubleValue];
        CGPoint lower = [WhaleyTrajectoryPositions[i - 1] CGPointValue];
        CGPoint upper = [WhaleyTrajectoryPositions[i] CGPointValue];
        double span = upperTime - lowerTime;
        double fraction = span > 0 ? (target - lowerTime) / span : 0;
        player.position = CGPointMake(lower.x + (upper.x - lower.x) * fraction,
                                      lower.y + (upper.y - lower.y) * fraction);
        return YES;
    }
    return NO;
}

@implementation Whaley

@synthesize tileMap = _tileMap;
@synthesize background = _background;
@synthesize meta = _meta;
@synthesize player = _player;
@synthesize hazards = _hazards;
@synthesize projectiles = _projectiles;
@synthesize collectibles = _collectibles;
@synthesize hud = _hud;
@synthesize winScreen = _winScreen;
@synthesize isPaused = _isPaused;
@synthesize goal = _goal;
@synthesize level = _level;
@synthesize tmxFile = _tmxFile;

@synthesize bounceSound = _bounceSound;
@synthesize flameSound = _flameSound;
@synthesize jumpSound = _jumpSound;
@synthesize collectibleSound = _collectibleSound;
@synthesize goalSound = _goalSound;
@synthesize bgSound = _bgSound;

@synthesize spoutSpriteSheet = _spoutSpriteSheet;
@synthesize spout = _spout;
@synthesize bubbleFileName = _bubbleFileName;

const BOOL UseRelativeProjectileOffset = YES;
const BOOL UseProjectileOffset = NO;
const BOOL AllowMiddleBounce = NO;
const BOOL AllowRichochet = YES;

const NSInteger ReallySmallScale = 0.1;
const NSInteger CloseBubbleDivisor = 16;

const NSInteger ProjectileOffset = 4;
const NSInteger TouchBubbleFudgeOffset = 5;

const NSInteger BackgroundZorder = 1;
const NSInteger CoinZorder = 0;
const NSInteger FlameZorder = 3;
const NSInteger PlayerZorder = 2;
const NSInteger BubbleZorder = 4;

const NSInteger MAX_BUBBLES = 500;
const NSInteger FLAME_DIMMED = 100;
const NSInteger FLAME_OPAQUE = 230;

const CGFloat CEILING_Y_POS = 90.0;

const NSInteger WaterLevelStart = 4;

const BOOL SHOW_SCANLINES = YES;

const NSInteger MIDDLE_BOUNCE_RANGE = 6;

+ (id)scene:(Level *)level withGameMode:(NSInteger)gameMode {
    CCScene *scene = [CCScene node];

    NSString *playerImage = ([GameState gameState].levelsAchieved > NumLevels) ? (@"player-win") : (@"player");
    [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:[NSString stringWithFormat:@"%@.plist", playerImage]];

    [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"coin.plist"];

    Whaley *gameLayer = [[[Whaley alloc] initWithLevel:level withGameMode:gameMode] autorelease];

    NSString *backgroundFileName = nil;
    if ([Helpers isiPhone5]) {
        backgroundFileName = @"level%d-568h.png";
    } else {
        backgroundFileName = @"level%d.png";
    }

    CCSprite *background = [CCSprite spriteWithFile:[NSString stringWithFormat:backgroundFileName, gameLayer.level.num]];
    background.ignoreAnchorPointForPosition = NO;
    background.anchorPoint = ccp(0, 0);

    CGSize s = [[CCDirector sharedDirector] winSize];

    background.scaleX = s.width / background.contentSize.width;
    background.scaleY = s.height / background.contentSize.height;
    background.opacity = 190;

    background.position = ccp(gameLayer.tileMap.position.x,
                              gameLayer.tileMap.position.y);
    [scene addChild:background];

    [scene addChild:gameLayer];

    WhaleyHud *hud = [WhaleyHud initAsColorLayer:gameLayer];
    [scene addChild:hud];

    WhaleyWinScreen *winScreen = [WhaleyWinScreen initAsColorLayer:gameLayer];
    [scene addChild:winScreen];

    gameLayer.hud = hud;
    gameLayer.winScreen = winScreen;

    if ([Helpers isiPhone5]) {
        if ((level.num == 2) || (level.num == 5)) {
            CCLayerColor *overlay = [CCLayerColor layerWithColor:ccc4(0, 0, 0, 255)
                                                           width:s.width
                                                          height:24];
            overlay.anchorPoint = ccp(0, 0);
            overlay.position = ccp(0, 0);
            [scene addChild:overlay];
        }
    }

    if (level.num >= WaterLevelStart) {
        CCLayerColor *layer = [CCLayerColor layerWithColor:ccc4(102, 102, 255, 0x80) width:s.width height:s.height];
        layer.anchorPoint = ccp(0, 0);
        layer.position = ccp(gameLayer.tileMap.position.x,
                             gameLayer.tileMap.position.y);
        [scene addChild:layer];
    } else if ((SHOW_SCANLINES)
               && (level.num != 3)) {
        NSString *backgroundFileName = nil;
        if ([Helpers isiPhone5]) {
            backgroundFileName = @"scanlines-568h.png";
        } else {
            backgroundFileName = @"scanlines.png";
        }
        CCSprite *layer = [CCSprite spriteWithFile:backgroundFileName];
        layer.anchorPoint = ccp(0, 0);
        layer.position = ccp(gameLayer.tileMap.position.x,
                             gameLayer.tileMap.position.y);
        [scene addChild:layer];
    }

    return scene;
}

- (id)initWithLevel:(Level *)level withGameMode:(NSInteger)gameMode {
    if ((self = [super init])) {
        self.level = level;

        _waterLevel = (self.level.num >= WaterLevelStart);

        [[SimpleAudioEngine sharedEngine] pauseBackgroundMusic];
        self.isTouchEnabled = YES;
        _touchSustained = NO;
        _isPaused = NO;
        WhaleySrcTrajectoryReset();
        _phase = 0;
        _currentLocation = ccp(-1, -1);

        if (level.checkpointIndex == -1) {
            self.level.gameMode = gameMode;
        }
        _defaultBounces = (self.level.gameMode == ExtraBounce) ? (3) : (2);
        _allowMiddleBounce = (self.level.gameMode == ExtraBounce);

        if ([GameState gameState].levelsAchieved > NumLevels) {
            _hasInfiniteBubbles = YES;
            _allowMiddleBounce = YES;
        } else {
            _hasInfiniteBubbles = NO;
        }

        NSString *tmxFileName = nil;
        if ([Helpers isiPhone5]) {
            tmxFileName = @"level%d-568h.tmx";
        } else {
            tmxFileName = @"level%d.tmx";
        }

        self.tileMap = [CCTMXTiledMap tiledMapWithTMXFile:[NSString stringWithFormat:tmxFileName, level.num]];
        // self.background = [self.tileMap layerNamed:@"Background"];
        self.meta = [self.tileMap layerNamed:@"Meta"];
        self.tileMap.anchorPoint = ccp(0, 0);
        self.tileMap.position = ccp(0, 0);
        [self addChild:self.tileMap z:BackgroundZorder];

        self.meta.visible = NO;

        CCTMXObjectGroup *objects = [self.tileMap objectGroupNamed:@"Objects"];
        NSAssert(objects != nil, @"'Objects' object group not found");
        NSMutableDictionary *playerOrigin = [objects objectNamed:@"PlayerOrigin"];
        NSAssert(playerOrigin.count > 0, @"PlayerOrigin object missing");

        NSString *playerImage = (_hasInfiniteBubbles) ? (@"player-win") : (@"player");

        CCSpriteBatchNode *playerSpriteSheet = [CCSpriteBatchNode batchNodeWithFile:[NSString stringWithFormat:@"%@.png", playerImage]];
        [self addChild:playerSpriteSheet z:PlayerZorder];

        self.player = [Player initDefaults:[NSString stringWithFormat:@"%@1.png", playerImage]];
        self.player.position = ccp([[playerOrigin valueForKey:@"x"] intValue],
                                   [[playerOrigin valueForKey:@"y"] intValue]);

        [playerSpriteSheet addChild:self.player];

        _numBubbles = 0;
        self.level.totalCollectibles = 0;

        self.projectiles = [[NSMutableArray new] autorelease];
        self.collectibles = [[NSMutableArray new] autorelease];

        CCSpriteBatchNode *collectibleSpriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"coin.png"];
        [self addChild:collectibleSpriteSheet z:CoinZorder];

        NSInteger collectibleIndex = 0;

        self.bubbleFileName = (_hasInfiniteBubbles) ? (@"infinite_bubble.png") : (@"bubble01.png");

        for (NSMutableDictionary *dict in [objects objects]) {
            if (/*(level.checkpointIndex == -1)
                     &&*/
                ([[dict valueForKey:@"IsBubble"] intValue] == 1)) {
                NSInteger bubbleX = [[dict valueForKey:@"x"] intValue];
                NSInteger bubbleY = [[dict valueForKey:@"y"] intValue];
                Projectile *bubble = [Projectile
                        initWithFile:self.bubbleFileName
                        withIsFrozen:YES
                        withSizeMode:SmallSize
                    withIsBeingMoved:NO
                     withBouncesLeft:_defaultBounces];

                bubble.position = ccp(bubbleX + (bubble.scaledWidth / 2), bubbleY + (bubble.scaledHeight / 2));
                if (!(_hasInfiniteBubbles)) {
                    bubble.color = Purple;
                }
                [self addChild:bubble z:BubbleZorder];

                _numBubbles++;

                [self.projectiles addObject:bubble];
            } else if ([[dict valueForKey:@"IsCoin"] intValue] == 1) {
                NSInteger collectibleX = [[dict valueForKey:@"x"] intValue];
                NSInteger collectibleY = [[dict valueForKey:@"y"] intValue];

                if (self.level.checkpointIndex == collectibleIndex) {
                    self.player.position = ccp(collectibleX, collectibleY);
                } else {
                    BOOL alreadyCollected = NO;
                    for (NSNumber *number in self.level.collectiblesCaptured) {
                        if ([number intValue] == collectibleIndex) {
                            alreadyCollected = YES;
                            break;
                        }
                    }
                    if (!(alreadyCollected)) {
                        Collectible *collectible = [Collectible initWithFile:@"coin1.png"];
                        collectible.position = ccp(collectibleX + (collectible.scaledWidth / 2), collectibleY + (collectible.scaledHeight / 2));

                        [collectibleSpriteSheet addChild:collectible];

                        [self.collectibles addObject:collectible];
                        collectible.tag = collectibleIndex;
                    }
                }
                collectibleIndex++;
            }
        }

        self.hazards = [[NSMutableArray new] autorelease];

        CCTMXObjectGroup *flames = [self.tileMap objectGroupNamed:@"Flames"];
        NSAssert(flames != nil, @"'Flames' object group not found");

        for (NSMutableDictionary *dict in [flames objects]) {
            Hazard *hazard = [Hazard spriteWithFile:((_waterLevel) ? (@"flame02.png") : (@"flame01.png"))];
            hazard.phase = [[dict valueForKey:@"Phase"] intValue];
            hazard.isActive = NO;
            NSInteger hazardX = [[dict valueForKey:@"x"] intValue] + (hazard.scaledWidth / 2);
            NSInteger hazardY = [[dict valueForKey:@"y"] intValue] + (hazard.scaledHeight / 2);
            hazard.position = ccp(hazardX, hazardY);
            [self.hazards addObject:hazard];
            // hazard.visible = NO;
            hazard.opacity = FLAME_DIMMED;
            hazard.color = ccBLACK;

            if (hazard.phase == -1) {
                // hazard.visible = YES;
                hazard.opacity = FLAME_OPAQUE;
                hazard.color = ccWHITE;
                hazard.isActive = YES;
            }

            id action = [CCRotateBy actionWithDuration:0 angle:30];
            [hazard runAction:[CCRepeatForever actionWithAction:[CCSequence actions:
                                                                                [CCDelayTime actionWithDuration:0.5f],
                                                                                action,
                                                                                nil]]];

            [self addChild:hazard z:FlameZorder];
        }

        NSMutableDictionary *goal = [objects objectNamed:@"Goal"];
        NSAssert(goal.count > 0, @"Goal object missing");

        self.goal = [GameObject spriteWithFile:@"goal01.png"];
        self.goal.position = ccp([[goal valueForKey:@"x"] intValue] + (self.goal.scaledWidth / 2),
                                 [[goal valueForKey:@"y"] intValue] + (self.goal.scaledHeight / 2));

        [self addChild:self.goal z:CoinZorder];

        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"spout.plist"];
        self.spoutSpriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"spout.png"];
        [self addChild:self.spoutSpriteSheet z:PlayerZorder];
        self.spoutSpriteSheet.visible = NO;
        NSMutableArray *spoutAnimFrames = [NSMutableArray array];
        for (NSInteger i = 1; i <= 4; ++i) {
            [spoutAnimFrames addObject:
                                 [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:
                                                                                  [NSString stringWithFormat:@"spout%d.png", i]]];
        }
        CCAnimation *spoutAnim = [CCAnimation animationWithSpriteFrames:spoutAnimFrames delay:0.1f];
        spoutAnim.restoreOriginalFrame = NO;
        self.player.spoutAction = [CCRepeatForever actionWithAction:
                                                       [CCAnimate actionWithAnimation:spoutAnim]];

        self.spout = [CCSprite spriteWithSpriteFrameName:@"spout1.png"];
        self.spout.anchorPoint = ccp(0, 0);
        [self.spout runAction:self.player.spoutAction];
        [self.spoutSpriteSheet addChild:self.spout];

        self.bounceSound = [[SimpleAudioEngine sharedEngine] soundSourceForFile:@"bounce01.wav"];
        self.flameSound = [[SimpleAudioEngine sharedEngine] soundSourceForFile:@"flame01.wav"];
        self.jumpSound = [[SimpleAudioEngine sharedEngine] soundSourceForFile:@"jump01.wav"];
        self.collectibleSound = [[SimpleAudioEngine sharedEngine] soundSourceForFile:@"coin01.wav"];
        self.goalSound = [[SimpleAudioEngine sharedEngine] soundSourceForFile:@"goal01.wav"];
        self.bgSound = [[SimpleAudioEngine sharedEngine] soundSourceForFile:@"bg01.mp3"];

        [Helpers setViewpointCenter:[Helpers spriteCenter:self.player]
                          withLayer:self
                        withTileMap:self.tileMap
                        withDamping:NO
                            adjustY:YES
                        forceCenter:YES];

        [self switchPhase:0];
        [self schedule:@selector(gameLoop:)];
        [self schedule:@selector(switchPhase:) interval:2.0f];
        if ((self.level.num == 1)
            || (self.level.num == 4)) {
            [self schedule:@selector(playBg:) interval:10.0f];
        }

        self.player.airMode = FALLING;

        if ([self playerIsRestingOnGroundTile]) {
            self.player.airMode = GROUNDED;
        }

        _ceilingFactor = 1;
    }
    return self;
}

- (void)playBg:(ccTime)dt {
    if (!(self.bgSound.isPlaying)) {
        [self.bgSound play];
    }
}

- (BOOL)isAtGround:(CGPoint)position {
    NSMutableArray *tempResult = [Helpers isAt:position
                                   withTileMap:self.tileMap
                                     withLayer:self.meta
                                       withKey:@"IsGround"
                                     withValue:@"True"
                                        withDx:0
                                        withDy:0];
    BOOL result = ([tempResult count] > 0);
    return result;
}

- (BOOL)isAtWall:(CGPoint)position withDx:(NSInteger)dx withDy:(NSInteger)dy {
    NSMutableArray *tempResult = [Helpers isAt:position
                                   withTileMap:self.tileMap
                                     withLayer:self.meta
                                       withKey:@"IsWall"
                                     withValue:@"True"
                                        withDx:dx
                                        withDy:dy];
    BOOL result = ([tempResult count] > 0);
    return result;
    ;
}

- (BOOL)isAtFlame:(CGPoint)position withDx:(NSInteger)dx withDy:(NSInteger)dy withPhase:(NSString *)phase {
    CGRect playerRect = [Helpers spriteRectangle:self.player];
    for (Hazard *hazard in self.hazards) {
        if (!hazard.visible) {
            continue;
        }
        if ((hazard.isActive)
            && ([Helpers rectIntersectsCircle:playerRect
                                    forCircle:[Helpers spriteRectangle:hazard]
                             withRadiusOffset:-4
                          withRectWidthOffset:-2
                         withRectHeightOffset:-2])) {
            // NSLog(@"%f, %f\n%f, %f", self.player.position.x, self.player.position.y, hazard.position.x - (hazard.scaledWidth / 2), hazard.position.y - (hazard.scaledHeight / 2));
            return YES;
        }
    }
    return NO;
}

- (BOOL)isProjectileAtFlame:(Projectile *)projectile {
    CGRect projectileRect = [Helpers spriteRectangle:projectile];
    for (Hazard *hazard in self.hazards) {
        if (!hazard.visible) {
            continue;
        }
        if (/*(hazard.isActive)
                 && */
            ([Helpers circleIntersectsCircle:projectileRect
                                  forCircle2:[Helpers spriteRectangle:hazard]
                           withRadius1Offset:0
                           withRadius2Offset:0
                                     inRange:0])) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)ableToMoveLeft:(NSInteger)dx {
    return (!([self isAtWall:self.player.position withDx:-dx withDy:0]));
}

- (BOOL)ableToMoveRight:(NSInteger)dx {
    return (!([self isAtWall:self.player.position withDx:dx withDy:0]));
}

- (BOOL)ableToMoveUp:(NSInteger)dy {
    return (!([self isAtWall:self.player.position withDx:0 withDy:dy]));
}

- (BOOL)ableToMoveDown:(NSInteger)dy {
    return (!([self isAtWall:self.player.position withDx:0 withDy:-dy]));
}

- (BOOL)playerIsRestingOnGroundTile {
    return ((([self isAtGround:self.player.position])
             || (!([self ableToMoveDown:self.player.yAdd])))
            && ([Helpers isYposExactlyOnTile:self.player.position withTileMap:self.tileMap]));
}

- (void)projectileMoveDone:(id)sender {
    Projectile *projectile = (Projectile *)sender;
    projectile.isFrozen = YES;
}

- (void)shrinkProjectile:(CCSprite *)projectile withDestination:(CGPoint)projectileDestination {
    [projectile runAction:[CCSequence actions:
                                          [CCScaleTo actionWithDuration:0.1f
                                                                  scale:SmallSize],
                                          nil]];
}

- (void)removeProjectile:(Projectile *)projectile {
    [self removeChild:projectile cleanup:YES];
    _numBubbles--;
    [self.projectiles removeObject:projectile];
}

- (void)enlargeProjectileOrRemove:(id)sender {
    Projectile *projectile = (Projectile *)sender;
    if (!(projectile.isBeingMoved)) {
        [self removeProjectile:projectile];
    }
}

- (void)removeCollectible:(Collectible *)collectible {
    collectible.visible = NO;
    if (collectible.parent) {
        [collectible removeFromParent];
    } else if (collectible.batchNode) {
        [collectible.batchNode removeChild:collectible cleanup:YES];
    }
    [self.collectibles removeObject:collectible];
}

- (void)activateHazard:(id)sender {
    Hazard *hazard = (Hazard *)sender;
    // hazard.visible = YES;
    hazard.isActive = YES;
}

- (void)deactivateHazard:(id)sender {
    Hazard *hazard = (Hazard *)sender;
    // hazard.visible = NO;
    // hazard.color = ccBLACK;
    hazard.isActive = NO;
}

- (void)makeHazardBlack:(id)sender {
    ((Hazard *)sender).color = ccBLACK;
}

- (void)switchPhase:(ccTime)dt {
    if (_isPaused) {
        return;
    }
    if (_phase == 0) {
        _phase = 180;
    } else {
        _phase = 0;
    }

    for (Hazard *hazard in self.hazards) {
        if (!hazard.visible) {
            hazard.isActive = NO;
            continue;
        }
        if (hazard.phase == _phase) {
            //[self addChild:hazard];
            hazard.color = ccWHITE;
            id action = [CCCallFuncN actionWithTarget:self selector:@selector(activateHazard:)];
            [hazard runAction:[CCSequence actions:
                                              //[CCDelayTime actionWithDuration:0.5f], action, nil]];
                                              [CCFadeTo actionWithDuration:0.25f
                                                                   opacity:FLAME_OPAQUE],
                                              action,
                                              nil]];
        } else if (hazard.phase != -1) {
            //[self removeChild:hazard cleanup:NO];
            id action = [CCCallFuncN actionWithTarget:self selector:@selector(deactivateHazard:)];
            [hazard runAction:[CCSequence actions:
                                              //[CCDelayTime actionWithDuration:0.5f], action, nil]];
                                              action,
                                              [CCFadeTo actionWithDuration:0.25f
                                                                   opacity:FLAME_DIMMED],
                                              [CCCallFuncN actionWithTarget:self
                                                                   selector:@selector(makeHazardBlack:)],
                                              nil]];
        }
    }
}

- (BOOL)checkTouchedProjectile:(CGPoint)touchLocation {
    BOOL result = NO;
    CGRect touchRect = CGRectMake(touchLocation.x,
                                  touchLocation.y,
                                  1,
                                  1);

    NSMutableArray *tempFrozenProjectiles = [NSMutableArray new];
    for (Projectile *projectile in self.projectiles) {
        if (projectile.isFrozen) {
            [tempFrozenProjectiles addObject:projectile];
        }
    }

    for (Projectile *projectile in tempFrozenProjectiles) {
        if (!(projectile.isBeingMoved)) {
            CGRect projectileRect = [Helpers spriteRectangle:projectile];

            if ([Helpers rectIntersectsCircle:touchRect
                                    forCircle:projectileRect
                             withRadiusOffset:TouchBubbleFudgeOffset
                          withRectWidthOffset:0
                         withRectHeightOffset:0]) {
                if (projectile.bouncesLeft < 0) {
                    projectile.bouncesLeft = 2;
                }

                projectile.isBeingMoved = YES;

                if (UseRelativeProjectileOffset) {
                    projectile.relativeOffset = ccp((touchLocation.x - projectile.position.x) / SmallSize,
                                                    (touchLocation.y - projectile.position.y) / SmallSize);
                    CGPoint projectileDestination = ccp(touchLocation.x - projectile.relativeOffset.x,
                                                        touchLocation.y - projectile.relativeOffset.y);
                    CCFiniteTimeAction *moveAction = [CCMoveTo actionWithDuration:0.1f position:projectileDestination];
                    [projectile runAction:moveAction];
                } else if (UseProjectileOffset) {
                    CGPoint projectileDestination = ccp(touchLocation.x,
                                                        touchLocation.y + ((projectile.contentSize.height * NormalSize) / ProjectileOffset));
                    CCFiniteTimeAction *moveAction = [CCMoveTo actionWithDuration:0.1f position:projectileDestination];
                    [projectile runAction:moveAction];
                }

                id action = [CCCallFuncN actionWithTarget:self selector:@selector(enlargeProjectileOrRemove:)];

                [projectile runAction:[CCSequence actions:
                                                      [CCScaleTo actionWithDuration:0.1f
                                                                              scale:NormalSize],
                                                      action, nil]];

                result = YES;

                break;
            }
        }
    }
    if (tempFrozenProjectiles) {
        [tempFrozenProjectiles release];
        tempFrozenProjectiles = nil;
    }
    return result;
}

- (void)registerWithTouchDispatcher {
    [[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint absoluteTouchLocation = [touch locationInView:[touch view]];
    absoluteTouchLocation = [[CCDirector sharedDirector] convertToGL:absoluteTouchLocation];
    CGPoint touchLocation = [self convertToNodeSpace:absoluteTouchLocation];

    CGRect selfRect = CGRectMake(self.hud.position.x - (self.hud.contentSize.width / 2),
                                 self.hud.position.y - (self.hud.contentSize.height / 2),
                                 self.hud.contentSize.width,
                                 self.hud.contentSize.height);

    if (CGRectContainsPoint(selfRect, absoluteTouchLocation)) {
        if (!(_isPaused)) {
            [self.hud pauseGame:self];
        } else if ((!(self.player.isDead))
                   && (!(self.player.hasWon))) {
            [self.hud resumeLevel:self];
        }

        return NO;
    }

    if (_isPaused) {
        return NO;
    }

    _touchSustained = YES;

    _currentLocation = touchLocation;

    BOOL touchSwallowed = [self checkTouchedProjectile:touchLocation];

    CGPoint playerCenter = [Helpers spriteCenter:self.player];

    if (/*(!(self.player.isDead))
             &&*/
        (!(touchSwallowed))
        && (touchLocation.y < (self.player.position.y + self.player.scaledHeight))) {
        Projectile *projectile = [Projectile
                initWithFile:self.bubbleFileName
                withIsFrozen:NO
                withSizeMode:SmallSize
            withIsBeingMoved:NO
             withBouncesLeft:_defaultBounces];

        projectile.sizeMode = SmallSize;

        CGFloat projectileDestinationY = touchLocation.y;

        NSInteger yOffset = ((self.player.airMode == JUMPING_DOWN) || (self.player.airMode == FALLING)) ? (-1 - self.player.yAdd) : (-1);

        BOOL animate = YES;

        /*if ((projectileDestinationY + projectile.scaledHeight)  > self.player.position.y) {
         projectileDestinationY = self.player.position.y - (projectile.scaledHeight / 2) - 1;
         }*/

        if ((projectileDestinationY + (projectile.scaledHeight / 1)) > (self.player.position.y + yOffset)) {
            projectileDestinationY = self.player.position.y + yOffset - ((projectile.scaledHeight / 2) * ReallySmallScale);
            animate = NO;
        }

        if (projectileDestinationY < 0) {
            projectileDestinationY = 0;
        }

        CGFloat projectileDestinationX;

        if (_allowMiddleBounce) {
            if ((playerCenter.x - touchLocation.x) > ((self.player.scaledWidth / 2) + MIDDLE_BOUNCE_RANGE)) {
                projectileDestinationX = self.player.position.x;
                self.player.flipX = NO;
            } else if ((touchLocation.x - playerCenter.x) > ((self.player.scaledWidth / 2) + MIDDLE_BOUNCE_RANGE)) {
                projectileDestinationX = self.player.position.x + self.player.scaledWidth + 1;
                self.player.flipX = YES;
            } else {
                projectileDestinationX = playerCenter.x;
            }
        } else {
            // if (absoluteTouchLocation.x < [touch view].center.x)
            if ((touchLocation.x - playerCenter.x) < 0) {
                projectileDestinationX = self.player.position.x;
                self.player.flipX = NO;
            } else {
                projectileDestinationX = self.player.position.x + self.player.scaledWidth + 1;
                self.player.flipX = YES;
            }
        }

        projectile.position = ccp(projectileDestinationX, self.player.position.y);
        projectile.scaleX = ReallySmallScale;
        projectile.scaleY = ReallySmallScale;

        if (_numBubbles >= MAX_BUBBLES) {
            [self removeProjectile:[self.projectiles objectAtIndex:0]];
        }

        if (!(_hasInfiniteBubbles)) {
            projectile.color = Purple;
        }

        [self addChild:projectile z:BubbleZorder];

        CGPoint projectileDestination = ccp(projectileDestinationX, projectileDestinationY);

        id action = [CCCallFuncN actionWithTarget:self selector:@selector(projectileMoveDone:)];

        if (animate) {
            [projectile runAction:[CCSequence actions:[CCScaleTo actionWithDuration:0.1f scale:SmallSize],
                                                      [CCMoveTo actionWithDuration:0.1f
                                                                          position:projectileDestination],
                                                      action,
                                                      nil]];
        } else {
            [projectile runAction:[CCScaleTo actionWithDuration:0.1f scale:SmallSize]];
            projectile.position = projectileDestination;
            [self projectileMoveDone:projectile];
        }
        _numBubbles++;
        self.level.bubblesUsed++;
        //[self.hud updateScore];
        [self.projectiles addObject:projectile];
    }

    /*
        CGRect playerRect = [Helpers spriteRectangle:self.player];
        CGRect touchRect = CGRectMake(touchLocation.x,
                                                                  touchLocation.y,
                                                                  1,
                                                                  1);

        if (CGRectIntersectsRect(playerRect, touchRect)) {
                if ((self.player.isMovingLaterally)
                        && (self.player.airMode == GROUNDED)) {

                        self.player.desiredPos = ccp(playerCenter.x, self.player.desiredPos.y);

                        self.player.xAdd = SlowXspd;
                }
                else if (((self.player.airMode == JUMPING_UP)
                                  || (self.player.airMode == JUMPING_DOWN))
                                 && (!([self isAtGround:self.player.position]))
                                 && ([self ableToMoveDown:self.player.yAdd])) {
                        self.player.airMode = FALLING;
                        self.player.isMovingLaterally = NO;
                        self.player.yAdd = SlowYspd;
                }
        }
     */

    return YES;
}

- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
    _touchSustained = NO;
    CGPoint touchLocation = [touch locationInView:[touch view]];
    touchLocation = [[CCDirector sharedDirector] convertToGL:touchLocation];
    touchLocation = [self convertToNodeSpace:touchLocation];

    BOOL foundProjectileBeingMoved = NO;

    for (Projectile *projectile in self.projectiles) {
        if ((projectile.isFrozen) && (projectile.isBeingMoved)) {
            if (UseRelativeProjectileOffset) {
                projectile.position = ccp(touchLocation.x - projectile.relativeOffset.x,
                                          touchLocation.y - projectile.relativeOffset.y);
            } else if (UseProjectileOffset) {
                projectile.position = ccp(touchLocation.x,
                                          touchLocation.y + (projectile.scaledHeight / ProjectileOffset));
            } else {
                projectile.position = ccp(touchLocation.x, touchLocation.y);
            }
            foundProjectileBeingMoved = YES;

            break;
        }
    }

    if (!(foundProjectileBeingMoved)) {
        [self checkTouchedProjectile:touchLocation];
    }
}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    _touchSustained = NO;

    for (Projectile *projectile in self.projectiles) {
        if ((projectile.isFrozen) && (projectile.isBeingMoved)) {
            CGPoint projectileDestination;

            if (UseRelativeProjectileOffset) {
                projectileDestination = ccp(projectile.position.x + (projectile.relativeOffset.x * (NormalSize - SmallSize)),
                                            projectile.position.y + (projectile.relativeOffset.y * (NormalSize - SmallSize)));
                CCFiniteTimeAction *moveAction = [CCMoveTo actionWithDuration:0.1f position:projectileDestination];
                [projectile runAction:moveAction];
            } else {
                CGPoint absoluteTouchLocation = [touch locationInView:[touch view]];
                CGPoint touchLocation = [[CCDirector sharedDirector] convertToGL:absoluteTouchLocation];
                touchLocation = [self convertToNodeSpace:touchLocation];

                projectileDestination = ccp(touchLocation.x, touchLocation.y);
            }

            projectile.isBeingMoved = NO;

            [self.hud setWarning:NO];

            [self shrinkProjectile:projectile withDestination:projectileDestination];

            // break;
        }
    }
}

- (void)doProjectiles {
    for (Projectile *projectile in self.projectiles) {
        if ((projectile.isFrozen)
            && (!(projectile.isBeingMoved))
            && (projectile.position.y < ((self.tileMap.mapSize.height * self.tileMap.tileSize.height) - projectile.scaledHeight - 1))) {
            projectile.position = ccp(projectile.position.x, projectile.position.y + 0.5);
        }
    }

    for (Projectile *projectile1 in self.projectiles) {
        if ((projectile1.isFrozen) && (!(projectile1.isBeingMoved))) {
            for (Projectile *projectile2 in self.projectiles) {
                if ((projectile1 != projectile2) && (projectile2.isFrozen) && (!(projectile2.isBeingMoved))) {
                    [Projectile projectileCollides:projectile1
                                    withProjectile:projectile2
                                        withOffset:(projectile1.scaledWidth - 2)
                                       withTileMap:self.tileMap];
                }
            }
        }
    }
}

- (void)playerDead:(id)sender {
    [self.hud replayLevel:self];
}

- (NSInteger)calculateScore {
    return (NSInteger)((self.level.totalCollectibles * 100)
                       + (5000 / (self.level.bubblesUsed + 1))
                       + (30000 / (self.level.totalTime + .1)));
}

- (void)playerWon:(id)sender {
    [self.winScreen winLevel:self];
}

- (void)gameLoop:(ccTime)dt {
    if (_isPaused) {
        return;
    }
    self.level.totalTime += dt;
    if (([self isAtFlame:self.player.position withDx:0 withDy:0 withPhase:[[NSNumber numberWithInt:_phase] stringValue]])
        && (!(self.player.isDead))) {
        if (!(self.flameSound.isPlaying)) {
            [self.flameSound play];
        }
        self.player.color = ccRED;
        if (self.player.airMode != GROUNDED) {
            self.player.airMode = FALLING;
        }
        // self.player.isMovingLaterally = NO;
        self.player.isDead = YES;
        self.player.flipY = YES;
        self.player.yAdd = SlowYspd;
        self.player.xAdd = SlowXspd;
        self.isTouchEnabled = NO;

        id action = [CCCallFuncN actionWithTarget:self selector:@selector(playerDead:)];
        [self.player runAction:[CCSequence actions:[CCDelayTime actionWithDuration:2.0f], action, nil]];
    }
    /*else {
     self.player.color = ccGREEN;
     }*/

    CGPoint playerCenter = [Helpers spriteCenter:self.player];

    if ((self.player.isMovingLaterally)
        && ((!(self.player.isDead)) || (self.player.airMode == GROUNDED))) {
        CGPoint playerPos = self.player.position;

        CGFloat diffx = self.player.desiredPos.x - playerCenter.x;
        BOOL movedLeft = NO;
        BOOL movedRight = NO;

        for (NSInteger i = self.player.xAdd; i > 0; i--) {
            if ((diffx > 0) && ([self ableToMoveRight:i])) {
                playerPos.x += i;
                movedRight = YES;
                break;
            } else if ((diffx <= 0) && ([self ableToMoveLeft:i])) {
                playerPos.x -= i;
                movedLeft = YES;
                break;
            }
        }

        if ((!(movedLeft)) && (!(movedRight))) {
            self.player.isMovingLaterally = NO;
        }

        if ((playerPos.x <= ((self.tileMap.mapSize.width * self.tileMap.tileSize.width) - self.player.scaledWidth))
            && (playerPos.y <= ((self.tileMap.mapSize.height * self.tileMap.tileSize.height) - self.player.scaledHeight))
            && (playerPos.y >= 0)
            && (playerPos.x >= 0)) {
            self.player.position = playerPos;
        } else {
            self.player.isMovingLaterally = NO;
        }

        if ((ABS(diffx) < self.player.xAdd)
            || (playerPos.x == ((self.tileMap.mapSize.width * self.tileMap.tileSize.width) - self.player.scaledWidth))
            || (playerPos.x == 0)) {
            self.player.isMovingLaterally = NO;
        }
    }

    if (self.player.airMode != GROUNDED) {
        self.player.xAdd = SlowXspd;
        if (((self.player.position.y + self.tileMap.tileSize.height) >= (self.tileMap.mapSize.height * self.tileMap.tileSize.height))
            || (!([self ableToMoveUp:self.player.yAdd]))) {
            if ((AllowRichochet)
                && ((self.player.airMode == JUMPING_UP)
                    /*|| (self.player.airMode == JUMPING_DOWN)*/)) {
                self.player.airMode = JUMPING_DOWN;
                self.player.yAdd = SlowYspd;
                _ceilingFactor = ((self.player.position.y - self.player.groundYpos) / CEILING_Y_POS);
                if (_ceilingFactor < (1 / 3.0)) {
                    self.player.airMode = FALLING;
                }
                // NSLog(@"%f", _ceilingFactor);
            } else if ((!(AllowRichochet))
                       || (self.player.airMode != JUMPING_DOWN)) {
                self.player.airMode = FALLING;
            }
        }

        if (self.player.airMode == FALLING) {
            self.player.yAdd = SlowYspd;
        }

        CGPoint newLocation = CGPointMake(self.player.position.x, self.player.position.y);

        if (_waterLevel) {
            _ceilingFactor = 0.5;
            self.player.yAdd = SlowYspd;
        }

        if (self.player.airMode == JUMPING_UP) {
            if ([self ableToMoveUp:self.player.yAdd]) {
                newLocation.y += self.player.yAdd;
            }
        } else {
            if ([self ableToMoveDown:self.player.yAdd]) {
                newLocation.y -= self.player.yAdd;
            }
        }

        self.player.position = newLocation;

        if (self.player.airMode != FALLING) {
            CGFloat pos = (self.player.position.y - self.player.groundYpos) * self.player.jumpDiff;
            if (pos <= 0) {
                self.player.airMode = FALLING;
            } else if (pos <= (45 * _ceilingFactor)) {
                self.player.yAdd = FastYspd;
            } else if (pos <= (48 * _ceilingFactor)) {
                self.player.yAdd = NormYspd;
            } else if (pos <= (75 * _ceilingFactor)) {
                self.player.yAdd = NormYspd;
            } else if ((pos <= (87 * _ceilingFactor))
                       && (_ceilingFactor >= (4 / 5.0))) {
                self.player.yAdd = NormYspd;
            } else if (pos <= (CEILING_Y_POS * _ceilingFactor)) {
                self.player.yAdd = SlowYspd;
            } else {
                self.player.yAdd = SlowYspd;
                self.player.airMode = JUMPING_DOWN;
            }

            /*switch ((NSInteger)((self.player.position.y - self.player.groundYpos) * self.player.jumpDiff)) {
             case 0:
             self.player.airMode = FALLING;
             break;
             case 45:
             self.player.yAdd = FastYspd;
             break;
             case 48:
             self.player.yAdd = NormYspd;
             break;
             case 87:
             self.player.yAdd = NormYspd;
             break;
             case 90:
             self.player.yAdd = SlowYspd;
             break;
             case 96:
             self.player.airMode = JUMPING_DOWN;
             break;
             default:
             break;
             }*/
        } else {
            self.player.yAdd = SlowYspd;
        }

        if ((self.player.airMode != JUMPING_UP)
            && (([self isAtGround:self.player.position])
                || (!([self ableToMoveDown:self.player.yAdd])))) {
            if ([Helpers isYposExactlyOnTile:self.player.position withTileMap:self.tileMap]) {
                self.player.airMode = GROUNDED;
                self.player.xAdd = NormXspd;
                self.player.desiredPos = ccp(playerCenter.x, self.player.desiredPos.y);
                self.player.groundYpos = self.player.position.y;
            } else {
                self.player.airMode = FALLING;
            }
        }
    }

    if ((self.player.airMode != JUMPING_UP)
        && (self.player.airMode != JUMPING_DOWN)
        && (!([self isAtGround:self.player.position]))
        && ([self ableToMoveDown:self.player.yAdd])) {
        self.player.airMode = FALLING;
        self.player.isMovingLaterally = NO;
        self.player.yAdd = SlowYspd;
    }

    if (/*!(self.player.isMovingLaterally)
             &&*/
        (!(self.player.isDead))
        && (self.player.airMode != JUMPING_UP)) {
        CGRect playerRect = [Helpers spriteRectangle:self.player];

        NSMutableArray *tempFrozenProjectiles = [NSMutableArray new];
        for (Projectile *projectile in self.projectiles) {
            if (projectile.isFrozen) {
                [tempFrozenProjectiles addObject:projectile];
            }
        }

        for (Projectile *projectile in tempFrozenProjectiles) {
            CGRect projectileRect = [Helpers spriteRectangle:projectile];

            CGPoint playerCenter = [Helpers spriteCenter:self.player];
            CGPoint projectileCenter = ccp(projectile.position.x, projectile.position.y);

            CGFloat diffx = playerCenter.x - projectileCenter.x;
            CGFloat diffy = playerCenter.y - projectileCenter.y;

            if ([Helpers rectIntersectsCircle:playerRect
                                    forCircle:projectileRect
                             withRadiusOffset:-1
                          withRectWidthOffset:-1
                         withRectHeightOffset:0]) {
                if (/*(!(projectile.isBeingMoved))
                         && */
                    (ABS(diffx) <= (self.player.scaledWidth / CloseBubbleDivisor))
                    && (ABS(diffy) <= (self.player.scaledHeight / CloseBubbleDivisor))) {
                    [self removeProjectile:projectile];
                } else {
                    BOOL wasJump = NO;
                    CGFloat playerDesiredX = playerCenter.x;
                    if (diffy >= (projectile.scaledHeight / 2)) {
                        if (!(self.jumpSound.isPlaying)) {
                            [self.jumpSound play];
                        }
                        self.player.airMode = JUMPING_UP;
                        _ceilingFactor = 1;
                        self.player.groundYpos = self.player.position.y;
                        self.player.yAdd = FastYspd;

                        wasJump = YES;

                        if (ABS(diffx) >= (projectile.scaledWidth / 4)) {
                            self.player.isMovingLaterally = YES;
                            self.player.xAdd = NormXspd;
                            self.player.jumpDiff = 1;
                        } else {
                            self.player.isMovingLaterally = NO;
                            self.player.jumpDiff = 1;
                        }

                        CGFloat desiredXoffset = ((self.tileMap.tileSize.width * 3) / 2);

                        if (projectileCenter.x < playerCenter.x) {
                            playerDesiredX += desiredXoffset;
                        } else {
                            playerDesiredX -= desiredXoffset;
                        }
                        self.player.desiredPos = ccp(playerDesiredX, self.player.position.y);
                    } else {
                        if (!(self.bounceSound.isPlaying)) {
                            [self.bounceSound play];
                        }
                        self.player.isMovingLaterally = YES;
                        self.player.xAdd = NormXspd;
                        if (projectileCenter.x < playerCenter.x) {
                            playerDesiredX = (self.tileMap.mapSize.width * self.tileMap.tileSize.width) - self.player.scaledWidth;
                        } else {
                            playerDesiredX = 0;
                        }
                        self.player.desiredPos = ccp(playerDesiredX, self.player.position.y);
                    }
                    if ((!(_hasInfiniteBubbles))
                        && (((!(projectile.isBeingMoved))
                             /*&& ((projectile.position.y + ((projectile.scaledHeight) / 2)) <= self.player.position.y)*/)
                            || (wasJump))) {
                        projectile.bouncesLeft = projectile.bouncesLeft - 1;
                        switch (projectile.bouncesLeft) {
                            case 2:
                                projectile.color = Magenta;
                                break;
                            case 1:
                                projectile.color = Red;
                                break;
                        }
                    }
                }
            }
        }

        BOOL foundProjectileBeingMoved = NO;

        for (Projectile *projectile in tempFrozenProjectiles) {
            if (projectile.isBeingMoved) {
                foundProjectileBeingMoved = YES;
                if ([self isProjectileAtFlame:projectile]) {
                    [self.hud setWarning:YES];
                } else {
                    [self.hud setWarning:NO];
                }
            }
            if (projectile.bouncesLeft == 0) {
                if (projectile.isBeingMoved) {
                    [self.hud setWarning:NO];
                }
                [self removeProjectile:projectile];
            }
        }

        if (tempFrozenProjectiles) {
            [tempFrozenProjectiles release];
            tempFrozenProjectiles = nil;
        }

        if ((_touchSustained)
            && (!(foundProjectileBeingMoved))) {
            [self checkTouchedProjectile:_currentLocation];
        }
    }

    if (!(self.player.isDead)) {
        CGRect playerRect = [Helpers spriteRectangle:self.player];

        NSMutableArray *tempFrozenCollectibles = [NSMutableArray new];
        for (Collectible *collectible in self.collectibles) {
            [tempFrozenCollectibles addObject:collectible];
        }

        for (Collectible *collectible in tempFrozenCollectibles) {
            CGRect collectibleRect = [Helpers spriteRectangle:collectible];

            if ([Helpers rectIntersectsCircle:playerRect
                                    forCircle:collectibleRect
                             withRadiusOffset:-1
                          withRectWidthOffset:-1
                         withRectHeightOffset:0]) {
                // if (!(self.collectibleSound.isPlaying)) {
                [self.collectibleSound play];
                //}
                self.level.totalCollectibles++;
                [self.level.collectiblesCaptured addObject:[NSNumber numberWithInt:collectible.tag]];
                self.level.checkpointIndex = collectible.tag;
                [GameState saveGameStateToFile];
                [self removeCollectible:collectible];
                [self.hud updateScore];
            }
        }

        if (tempFrozenCollectibles) {
            [tempFrozenCollectibles release];
            tempFrozenCollectibles = nil;
        }

        CGRect goalRect = [Helpers spriteRectangle:self.goal];
        if ([Helpers rectIntersectsCircle:playerRect
                                forCircle:goalRect
                         withRadiusOffset:-1
                      withRectWidthOffset:-1
                     withRectHeightOffset:0]) {
            self.spout.position = ccp(self.player.position.x,
                                      self.player.position.y + self.player.scaledHeight - 1);
            self.spoutSpriteSheet.visible = YES;
            self.player.hasWon = YES;
            [self unschedule:@selector(gameLoop:)];
            [self unschedule:@selector(switchPhase:)];
            self.isTouchEnabled = NO;
            [self removeChild:self.goal cleanup:NO];
            if (!(self.goalSound.isPlaying)) {
                [self.goalSound play];
            }
            id action = [CCCallFuncN actionWithTarget:self selector:@selector(playerWon:)];
            [self.player runAction:[CCSequence actions:[CCDelayTime actionWithDuration:0.5f], action, nil]];
        }

        [Helpers setViewpointCenter:[Helpers spriteCenter:self.player]
                          withLayer:self
                        withTileMap:self.tileMap
                        withDamping:YES
                            adjustY:YES
                        forceCenter:YES];
    }

    if (!(_isPaused)) {
        WhaleySrcTrajectoryRecord(self.player, dt);
    }
}

- (void)releaseRetained {
    self.hud = nil;
    self.winScreen = nil;
}

- (void)dealloc {
    [[CCSpriteFrameCache sharedSpriteFrameCache] removeUnusedSpriteFrames];
    [self.goalSound stop];
    [self.collectibleSound stop];
    [self.bounceSound stop];
    [self.jumpSound stop];
    [self.flameSound stop];
    [self.bgSound stop];

    self.goalSound = nil;
    self.collectibleSound = nil;
    self.bounceSound = nil;
    self.jumpSound = nil;
    self.flameSound = nil;
    self.bgSound = nil;

    self.tileMap = nil;
    self.background = nil;
    self.meta = nil;
    self.player = nil;
    self.tmxFile = nil;
    self.level = nil;
    self.spoutSpriteSheet = nil;
    self.spout = nil;

    [self.collectibles removeAllObjects];
    [self.hazards removeAllObjects];
    [self.projectiles removeAllObjects];

    self.collectibles = nil;
    self.hazards = nil;
    self.projectiles = nil;
    self.goal = nil;
    [super dealloc];
}

@end
#endif
