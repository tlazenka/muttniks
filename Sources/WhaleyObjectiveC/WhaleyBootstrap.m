#if __has_include(<UIKit/UIKit.h>)
#import "WhaleyBootstrap.h"
static NSBundle *WhaleyConfiguredResourceBundle;
void WhaleySrcSetResourceBundle(NSBundle *bundle) {
    @synchronized([NSBundle class]) {
        if (WhaleyConfiguredResourceBundle != bundle) {
            [WhaleyConfiguredResourceBundle release];
            WhaleyConfiguredResourceBundle = [bundle retain];
        }
    }
}
NSBundle *WhaleySrcResourceBundle(void) {
    @synchronized([NSBundle class]) {
        return WhaleyConfiguredResourceBundle ?: NSBundle.mainBundle;
    }
}
NSURL *WhaleySrcResourceURL(NSString *filename) {
    NSString *base = filename.stringByDeletingPathExtension;
    NSString *ext = filename.pathExtension;
    NSBundle *bundle = WhaleySrcResourceBundle();
    NSURL *url = [bundle URLForResource:base withExtension:ext.length ? ext : nil];
    if (!url) {
        url = [bundle URLForResource:base withExtension:ext.length ? ext : nil subdirectory:@"Resources"];
    }
    return url;
}
SKTexture *WhaleySrcTexture(NSString *filename) {
    NSURL *url = WhaleySrcResourceURL(filename);
    UIImage *image = url ? [UIImage imageWithContentsOfFile:url.path] : nil;
    return image ? [SKTexture textureWithImage:image] : [SKTexture textureWithImageNamed:filename];
}

#import "cocos2d.h"
#import "src/Constants.h"
#import "src/GameState.h"
#import "src/Helpers.h"
#import "src/Level.h"
#import "src/WhaleyScene.h"

static Whaley *WhaleyCurrentGame = nil;
static NSArray<NSNumber *> *WhaleySuppressedFlameIndices = nil;

void WhaleySrcSetSuppressedFlames(NSArray<NSNumber *> *indices) {
    WhaleySuppressedFlameIndices = [indices copy];
    Whaley *game = WhaleyCurrentGame;
    if (!game) {
        return;
    }
    NSUInteger index = 0;
    for (Hazard *hazard in game.hazards) {
        BOOL suppressed = [WhaleySuppressedFlameIndices containsObject:@(index++)];
        hazard.visible = !suppressed;
        if (suppressed) {
            hazard.isActive = NO;
        }
    }
}

NSArray<NSValue *> *WhaleySrcFlamePositions(void) {
    NSMutableArray<NSValue *> *positions = [NSMutableArray array];
    for (Hazard *hazard in WhaleyCurrentGame.hazards) {
        [positions addObject:[NSValue valueWithCGPoint:hazard.position]];
    }
    return positions;
}

NSDictionary<NSString *, id> *WhaleySrcSceneSnapshotElements(void) {
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.tileMap || !game.meta) {
        return @{@"elements" : @[]};
    }
    CGSize tile = game.tileMap.tileSize;
    NSInteger width = (NSInteger)game.tileMap.mapSize.width;
    NSInteger height = (NSInteger)game.tileMap.mapSize.height;
    if (tile.width <= 0 || tile.height <= 0) {
        return @{@"elements" : @[]};
    }
    CGPoint player = WhaleySrcPlayerPosition();
    NSInteger cx = (NSInteger)floor(player.x / tile.width);
    NSInteger cy = (NSInteger)floor(player.y / tile.height);
    NSMutableArray *elements = [NSMutableArray array];
    NSInteger minX = MAX(0, cx - 18), maxX = MIN(width - 1, cx + 18);
    NSInteger minY = MAX(0, cy - 18), maxY = MIN(height - 1, cy + 18);
    for (NSInteger y = minY; y <= maxY; ++y) {
        for (NSInteger x = minX; x <= maxX; ++x) {
            NSInteger gid = [game.meta tileGIDAt:CGPointMake(x, height - 1 - y)];
            if (!gid) {
                continue;
            }
            NSDictionary *properties = [game.tileMap propertiesForGID:gid];
            NSString *kind = [properties[@"IsWall"] isEqualToString:@"True"] ? @"wall" : ([properties[@"IsGround"] isEqualToString:@"True"] ? @"ground" : nil);
            if (kind) {
                [elements addObject:@{@"kind" : kind,
                                      @"x" : @(x),
                                      @"y" : @(y)}];
            }
        }
    }
    void (^addObjects)(NSArray *, NSString *) = ^(NSArray *objects, NSString *kind) {
        for (GameObject *object in objects) {
            if (!object.visible || !object.parent) {
                continue;
            }
            CGPoint point = object.position;
            NSInteger x = (NSInteger)floor(point.x / tile.width);
            NSInteger y = (NSInteger)floor(point.y / tile.height);
            if (labs(x - cx) <= 18 && labs(y - cy) <= 18) {
                [elements addObject:@{@"kind" : kind,
                                      @"x" : @(x),
                                      @"y" : @(y)}];
            }
        }
    };
    addObjects(game.projectiles, @"bubble");
    addObjects(game.collectibles, @"coin");
    addObjects(game.hazards, @"flame");
    if (game.goal) {
        addObjects(@[ game.goal ], @"goal");
    }
    return @{@"elements" : elements,
             @"tileWidth" : @(tile.width),
             @"tileHeight" : @(tile.height)};
}

static CGPoint WhaleyLivePlayerBeforeTimeProjection;
static BOOL WhaleyHasLivePlayerBeforeTimeProjection = NO;

static Whaley *WhaleyFindGameLayer(SKNode *node) {
    if ([node isKindOfClass:[Whaley class]]) {
        return (Whaley *)node;
    }
    for (SKNode *child in node.children) {
        Whaley *found = WhaleyFindGameLayer(child);
        if (found) {
            return found;
        }
    }
    return nil;
}

static SKShapeNode *WhaleyDebugRect(CGRect rect, UIColor *color) {
    SKShapeNode *shape = [SKShapeNode shapeNodeWithRect:rect];
    shape.strokeColor = color;
    shape.lineWidth = 1.5;
    shape.fillColor = UIColor.clearColor;
    shape.zPosition = 20001;
    return shape;
}

static SKShapeNode *WhaleyDebugCircle(CGRect semanticCircle, UIColor *color) {
    CGFloat radius = semanticCircle.size.width / 2.0;
    CGRect circleBounds = CGRectMake(semanticCircle.origin.x - radius,
                                     semanticCircle.origin.y - radius,
                                     radius * 2.0, radius * 2.0);
    SKShapeNode *shape = [SKShapeNode shapeNodeWithEllipseInRect:circleBounds];
    shape.strokeColor = color;
    shape.lineWidth = 1.5;
    shape.fillColor = UIColor.clearColor;
    shape.zPosition = 20001;
    return shape;
}

static void WhaleyInstallMechanicsStatus(SKScene *host, CCScene *srcScene) {
#if DEBUG
    Whaley *game = WhaleyFindGameLayer(srcScene);
    if (!game) {
        return;
    }

    NSUInteger startingCoins = game.collectibles.count;
    NSUInteger hazardCount = game.hazards.count;

    SKLabelNode *status = [SKLabelNode labelNodeWithFontNamed:@"Menlo-Bold"];
    status.name = @"WhaleyMechanicsStatus";
    status.fontSize = 9;
    status.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    status.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    status.position = CGPointMake(6, host.size.height - 20);
    status.zPosition = 30001;
    [host addChild:status];

    __block NSInteger previousCoins = -1;
    __block NSInteger previousActiveHazards = -1;
    __block BOOL previousDead = NO;
    __block BOOL previousWon = NO;
    [status runAction:[SKAction repeatActionForever:[SKAction sequence:@[
                                    [SKAction runBlock:^{
                                        NSInteger remaining = (NSInteger)game.collectibles.count;
                                        NSInteger collected = (NSInteger)startingCoins - remaining;
                                        NSInteger active = 0;
                                        for (Hazard *hazard in game.hazards) {
                                            if (hazard.isActive) {
                                                ++active;
                                            }
                                        }
                                        BOOL dead = game.player.isDead;
                                        BOOL won = game.player.hasWon;
                                        status.text = [NSString stringWithFormat:@"COINS %ld/%lu  HAZARDS %ld/%lu  GOAL %@",
                                                                                 (long)collected, (unsigned long)startingCoins,
                                                                                 (long)active, (unsigned long)hazardCount,
                                                                                 won ? @"WON" : @"READY"];

                                        if (collected != previousCoins) {
                                            [CCCompatTrace record:@"mechanic.coins" detail:[NSString stringWithFormat:@"%ld/%lu", (long)collected, (unsigned long)startingCoins]];
                                            previousCoins = collected;
                                        }
                                        if (active != previousActiveHazards) {
                                            [CCCompatTrace record:@"mechanic.hazards" detail:[NSString stringWithFormat:@"active=%ld/%lu", (long)active, (unsigned long)hazardCount]];
                                            previousActiveHazards = active;
                                        }
                                        if (dead && !previousDead) {
                                            [CCCompatTrace record:@"mechanic.hazardHit" detail:@"player.isDead = YES"];
                                        }
                                        if (won && !previousWon) {
                                            [CCCompatTrace record:@"mechanic.goal" detail:@"player.hasWon = YES"];
                                            SKShapeNode *panel = [SKShapeNode shapeNodeWithRect:CGRectMake(32, 244, 256, 80) cornerRadius:12];
                                            panel.name = @"WhaleyWinConfirmation";
                                            panel.fillColor = [UIColor colorWithWhite:0 alpha:0.78];
                                            panel.strokeColor = UIColor.whiteColor;
                                            panel.zPosition = 31000;
                                            SKLabelNode *label = [SKLabelNode labelNodeWithFontNamed:@"Menlo-Bold"];
                                            label.text = @"LEVEL COMPLETE";
                                            label.fontSize = 20;
                                            label.position = CGPointMake(128, 31);
                                            label.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
                                            label.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
                                            [panel addChild:label];
                                            [host addChild:panel];
                                        }
                                        previousDead = dead;
                                        previousWon = won;
                                    }],
                                    [SKAction waitForDuration:1.0 / 15.0]
                                ]]]];
#endif
}

static void WhaleyInstallCollisionOverlay(SKScene *host, CCScene *srcScene) {
#if DEBUG
    Whaley *game = WhaleyFindGameLayer(srcScene);
    if (!game || !game.tileMap || !game.meta) {
        [CCCompatTrace record:@"DebugOverlay.install" detail:@"missing Whaley/tileMap/meta"];
        return;
    }

    SKNode *sceneOverlay = [SKNode node];
    sceneOverlay.name = @"WhaleyCollisionOverlay";
    sceneOverlay.zPosition = 20000;
    [game addChild:sceneOverlay];

    NSUInteger occupied = 0, walls = 0, grounds = 0, other = 0;
    NSInteger width = (NSInteger)game.tileMap.mapSize.width;
    NSInteger height = (NSInteger)game.tileMap.mapSize.height;
    CGSize tileSize = game.tileMap.tileSize;
    for (NSInteger row = 0; row < height; ++row) {
        for (NSInteger col = 0; col < width; ++col) {
            NSInteger gid = [game.meta tileGIDAt:CGPointMake(col, row)];
            if (!gid) {
                continue;
            }
            ++occupied;
            NSDictionary *properties = [game.tileMap propertiesForGID:gid];
            BOOL wall = [[properties objectForKey:@"IsWall"] isEqualToString:@"True"];
            BOOL ground = [[properties objectForKey:@"IsGround"] isEqualToString:@"True"];
            UIColor *color;
            if (wall) {
                color = UIColor.systemRedColor;
                ++walls;
            } else if (ground) {
                color = UIColor.systemGreenColor;
                ++grounds;
            } else {
                color = UIColor.systemYellowColor;
                ++other;
            }
            CGRect rect = CGRectMake(col * tileSize.width,
                                     (height - 1 - row) * tileSize.height,
                                     tileSize.width, tileSize.height);
            SKShapeNode *cell = [SKShapeNode shapeNodeWithRect:rect];
            cell.strokeColor = color;
            cell.fillColor = [color colorWithAlphaComponent:0.18];
            cell.lineWidth = 0.5;
            [sceneOverlay addChild:cell];
        }
    }

    SKNode *geometry = [SKNode node];
    geometry.name = @"WhaleyGeometry";
    geometry.zPosition = 20002;
    [game addChild:geometry];
    [geometry runAction:[SKAction repeatActionForever:[SKAction sequence:@[
                                      [SKAction runBlock:^{
                                          [geometry removeAllChildren];
                                          if (game.player) {
                                              [geometry addChild:WhaleyDebugRect([Helpers spriteRectangle:game.player], UIColor.systemCyanColor)];
                                          }
                                          for (Projectile *bubble in game.projectiles) {
                                              if (bubble.parent) {
                                                  [geometry addChild:WhaleyDebugCircle([Helpers spriteRectangle:bubble], UIColor.systemBlueColor)];
                                              }
                                          }
                                          for (Collectible *coin in game.collectibles) {
                                              if (coin.parent) {
                                                  [geometry addChild:WhaleyDebugCircle([Helpers spriteRectangle:coin], UIColor.systemOrangeColor)];
                                              }
                                          }
                                          for (Hazard *hazard in game.hazards) {
                                              if (hazard.parent && hazard.visible) {
                                                  [geometry addChild:WhaleyDebugCircle([Helpers spriteRectangle:hazard], UIColor.systemPurpleColor)];
                                              }
                                          }
                                      }],
                                      [SKAction waitForDuration:1.0 / 30.0]
                                  ]]]];

    SKLabelNode *legend = [SKLabelNode labelNodeWithFontNamed:@"Menlo-Bold"];
    legend.name = @"WhaleyCollisionLegend";
    legend.text = [NSString stringWithFormat:@"META %lu  wall %lu  ground %lu  other %lu",
                                             (unsigned long)occupied, (unsigned long)walls,
                                             (unsigned long)grounds, (unsigned long)other];
    legend.fontSize = 9;
    legend.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    legend.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    legend.position = CGPointMake(6, host.size.height - 6);
    legend.zPosition = 30000;
    [host addChild:legend];

    [CCCompatTrace record:@"DebugOverlay.install"
                   detail:[NSString stringWithFormat:@"Meta occupied=%lu walls=%lu ground=%lu other=%lu",
                                                     (unsigned long)occupied, (unsigned long)walls,
                                                     (unsigned long)grounds, (unsigned long)other]];
#endif
}

static void WhaleyInstallSrcSceneInHost(SKScene *host, Level *level) {
    CCScene *srcScene = [Whaley scene:level withGameMode:level.gameMode];
    WhaleyCurrentGame = WhaleyFindGameLayer(srcScene);
    WhaleySrcSetSuppressedFlames(WhaleySuppressedFlameIndices);
    WhaleyHasLivePlayerBeforeTimeProjection = NO;
    [host removeAllChildren];
    [host addChild:srcScene];
    WhaleyInstallCollisionOverlay(host, srcScene);
    WhaleyInstallMechanicsStatus(host, srcScene);
}

static Level *WhaleyPersistentLevel(NSInteger number) {
    GameState *state = [GameState gameState];
    if (number >= 1 && number <= (NSInteger)state.levels.count) {
        return [state.levels objectAtIndex:number - 1];
    }
    return [Level levelWithNum:number withGameMode:NormalBubble];
}

static void WhaleyResetLevelForFreshRun(Level *level) {
    level.checkpointIndex = -1;
    [level.collectiblesCaptured removeAllObjects];
    level.bubblesUsed = 0;
    level.totalTime = 0;
    level.totalCollectibles = 0;
}

void WhaleySrcReplayCurrentLevel(void) {
    Whaley *game = WhaleyCurrentGame;
    SKScene *host = (SKScene *)game.parent.parent;
    if (!game || !host || !game.level) {
        return;
    }
    [GameState saveGameStateToFile];
    WhaleyInstallSrcSceneInHost(host, game.level);
}

void WhaleySrcAdvanceAfterWin(void) {
    Whaley *game = WhaleyCurrentGame;
    SKScene *host = (SKScene *)game.parent.parent;
    if (!game || !host || !game.level) {
        return;
    }
    GameState *state = [GameState gameState];
    NSInteger completed = game.level.num;
    WhaleyResetLevelForFreshRun(game.level);
    NSInteger next = completed + 1;
    if (completed >= NumLevels) {
        state.levelsAchieved = MAX(state.levelsAchieved, NumLevels + 1);
        next = 1;
        for (Level *level in state.levels) {
            WhaleyResetLevelForFreshRun(level);
        }
    } else {
        state.levelsAchieved = MAX(state.levelsAchieved, next);
    }
    Level *nextLevel = WhaleyPersistentLevel(next);
    WhaleyResetLevelForFreshRun(nextLevel);
    [GameState saveGameStateToFile];
    WhaleyInstallSrcSceneInHost(host, nextLevel);
}

SKScene *WhaleyCreateSrcLevelScene(NSInteger levelNumber) {
    NSCAssert(levelNumber >= 1 && levelNumber <= 6, @"Original Whaley level must be 1...6");
    [CCCompatTrace setEnabled:YES];

    CGSize logicalSize = CGSizeMake(320.0, 568.0);
    [[CCDirector sharedDirector] setCompatWinSize:logicalSize];

    Level *level = WhaleyPersistentLevel(levelNumber);
    CCScene *srcScene = [Whaley scene:level withGameMode:NormalBubble];
    WhaleyCurrentGame = WhaleyFindGameLayer(srcScene);
    WhaleySrcSetSuppressedFlames(WhaleySuppressedFlameIndices);
    WhaleyHasLivePlayerBeforeTimeProjection = NO;

    SKScene *host = [SKScene sceneWithSize:logicalSize];
    host.scaleMode = SKSceneScaleModeAspectFill;
    host.anchorPoint = CGPointZero;
    host.backgroundColor = UIColor.blackColor;
    [host addChild:srcScene];
    WhaleyInstallCollisionOverlay(host, srcScene);
    WhaleyInstallMechanicsStatus(host, srcScene);

    [CCCompatTrace record:@"bootstrap.original"
                   detail:[NSString stringWithFormat:@"WhaleyScene.m original level %ld", (long)levelNumber]];
    return host;
}

SKScene *WhaleyCreateSrcLevelOneScene(void) {
    return WhaleyCreateSrcLevelScene(1);
}

SKScene *WhaleyCreateSrcLevelTwoScene(void) {
    return WhaleyCreateSrcLevelScene(2);
}

void WhaleySrcSetCompatViewSize(CGSize size) {
    [[CCDirector sharedDirector] setCompatViewSize:size];
}

BOOL WhaleySrcTouchBegan(UITouch *touch, UIEvent *event) {
    return [[[CCDirector sharedDirector] touchDispatcher] dispatchTouchBegan:touch withEvent:event];
}
void WhaleySrcTouchMoved(UITouch *touch, UIEvent *event) {
    [[[CCDirector sharedDirector] touchDispatcher] dispatchTouchMoved:touch withEvent:event];
}
void WhaleySrcTouchEnded(UITouch *touch, UIEvent *event) {
    [[[CCDirector sharedDirector] touchDispatcher] dispatchTouchEnded:touch withEvent:event];
}
void WhaleySrcTouchCancelled(UITouch *touch, UIEvent *event) {
    [[[CCDirector sharedDirector] touchDispatcher] dispatchTouchCancelled:touch withEvent:event];
}

void WhaleySrcSetSceneScrubPaused(BOOL paused) {
    WhaleyCurrentGame.isPaused = paused;
}

void WhaleySrcBeginTimeProjection(void) {
    Whaley *game = WhaleyCurrentGame;
    WhaleyHasLivePlayerBeforeTimeProjection = NO;
    if (!game || !game.player) {
        return;
    }
    WhaleyLivePlayerBeforeTimeProjection = game.player.position;
    WhaleyHasLivePlayerBeforeTimeProjection = YES;
}

BOOL WhaleySrcProjectTime(NSTimeInterval seconds) {
    Whaley *game = WhaleyCurrentGame;
    if (!game) {
        return NO;
    }
    NSInteger interval = (NSInteger)floor(MAX(0.0, seconds) / 2.0);
    NSInteger projectedPhase = (interval % 2 == 0) ? 180 : 0;
    for (Hazard *hazard in game.hazards) {
        BOOL active = hazard.phase == -1 || hazard.phase == projectedPhase;
        hazard.isActive = active;
        hazard.opacity = active ? FLAME_OPAQUE : FLAME_DIMMED;
        hazard.color = active ? ccWHITE : ccBLACK;
    }
    return WhaleySrcTrajectoryProjectPlayer(game.player, seconds);
}

void WhaleySrcRestoreLiveProjection(void) {
    Whaley *game = WhaleyCurrentGame;
    if (!game) {
        return;
    }
    if (WhaleyHasLivePlayerBeforeTimeProjection && game.player) {
        game.player.position = WhaleyLivePlayerBeforeTimeProjection;
        WhaleyHasLivePlayerBeforeTimeProjection = NO;
    }
    NSInteger livePhase = [[game valueForKey:@"_phase"] integerValue];
    for (Hazard *hazard in game.hazards) {
        BOOL active = hazard.phase == -1 || hazard.phase == livePhase;
        hazard.isActive = active;
        hazard.opacity = active ? FLAME_OPAQUE : FLAME_DIMMED;
        hazard.color = active ? ccWHITE : ccBLACK;
    }
}

#pragma mark - Live Scene Shift acquisition

typedef NS_ENUM(NSInteger, WhaleySceneScrubTargetKind) {
    WhaleySceneScrubTargetNone = 0,
    WhaleySceneScrubTargetObject = 1,
    WhaleySceneScrubTargetTile = 2,
};

static WhaleySceneScrubTargetKind WhaleySceneScrubKind = WhaleySceneScrubTargetNone;
static GameObject *WhaleySceneScrubObject = nil;
static CGPoint WhaleySceneScrubOriginPosition;
static CGFloat WhaleySceneScrubOriginScaleX = 1.0;
static CGFloat WhaleySceneScrubOriginScaleY = 1.0;
static NSInteger WhaleySceneScrubImageIndex = 0;
static CGPoint WhaleySceneScrubTileCoordinate;
static SKShapeNode *WhaleySceneScrubTileOverlay = nil;
static NSMutableArray<NSNumber *> *WhaleySceneScrubTileRowSnapshot = nil;
static NSInteger WhaleySceneScrubTileInitialRun = 1;
static NSInteger WhaleySceneScrubTileAnchorGID = 0;

static NSArray *WhaleySceneScrubCandidates(Whaley *game) {
    if (!game) {
        return @[];
    }
    NSMutableArray *objects = [NSMutableArray array];
    if (game.player) {
        [objects addObject:game.player];
    }
    if (game.goal) {
        [objects addObject:game.goal];
    }
    [objects addObjectsFromArray:game.hazards ?: @[]];
    [objects addObjectsFromArray:game.collectibles ?: @[]];
    return objects;
}

static CGPoint WhaleySceneScrubScenePoint(CGPoint viewPoint) {
    Whaley *game = WhaleyCurrentGame;
    SKScene *host = game.scene;
    return host ? [host convertPointFromView:viewPoint] : CGPointZero;
}

static GameObject *WhaleySceneScrubHitObject(CGPoint scenePoint) {
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.scene) {
        return nil;
    }
    NSArray *objects = WhaleySceneScrubCandidates(game);
    for (GameObject *object in [objects reverseObjectEnumerator]) {
        if (!object.visible || !object.parent) {
            continue;
        }
        CGPoint parentPoint = [object.parent convertPoint:scenePoint fromNode:game.scene];
        if (CGRectContainsPoint([object boundingBox], parentPoint)) {
            return object;
        }
    }
    return nil;
}

static BOOL WhaleySceneScrubHitTile(CGPoint scenePoint, CGPoint *tileCoordinate) {
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.meta || !game.tileMap) {
        return NO;
    }
    CGPoint local = [game.meta convertPoint:scenePoint fromNode:game.scene];
    CGSize tile = game.tileMap.tileSize;
    NSInteger width = (NSInteger)game.tileMap.mapSize.width;
    NSInteger height = (NSInteger)game.tileMap.mapSize.height;
    if (tile.width <= 0 || tile.height <= 0 || local.x < 0 || local.y < 0) {
        return NO;
    }
    NSInteger column = (NSInteger)floor(local.x / tile.width);
    NSInteger bottomRow = (NSInteger)floor(local.y / tile.height);
    NSInteger row = height - 1 - bottomRow;  // TMX is top-left row order
    if (column < 0 || column >= width || row < 0 || row >= height) {
        return NO;
    }
    if ([game.meta tileGIDAt:CGPointMake(column, row)] == 0) {
        return NO;
    }
    if (tileCoordinate) {
        *tileCoordinate = CGPointMake(column, row);
    }
    return YES;
}

static void WhaleySceneScrubShowTileOverlayRun(CGPoint coordinate, NSInteger cells) {
    [WhaleySceneScrubTileOverlay removeFromParent];
    WhaleySceneScrubTileOverlay = nil;
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.meta || !game.scene) {
        return;
    }
    CGSize tile = game.tileMap.tileSize;
    NSInteger height = (NSInteger)game.tileMap.mapSize.height;
    CGPoint localOrigin = CGPointMake(coordinate.x * tile.width,
                                      (height - 1 - coordinate.y) * tile.height);
    CGPoint hostOrigin = [game.scene convertPoint:localOrigin fromNode:game.meta];
    CGPoint hostFar = [game.scene convertPoint:CGPointMake(localOrigin.x + tile.width * MAX(1, cells),
                                                           localOrigin.y + tile.height)
                                      fromNode:game.meta];
    CGRect rect = CGRectMake(MIN(hostOrigin.x, hostFar.x), MIN(hostOrigin.y, hostFar.y),
                             fabs(hostFar.x - hostOrigin.x), fabs(hostFar.y - hostOrigin.y));
    SKShapeNode *shape = [SKShapeNode shapeNodeWithRect:rect];
    shape.strokeColor = UIColor.systemYellowColor;
    shape.fillColor = [UIColor.systemYellowColor colorWithAlphaComponent:0.18];
    shape.lineWidth = 3;
    shape.zPosition = 40000;
    [game.scene addChild:shape];
    WhaleySceneScrubTileOverlay = shape;
}

BOOL WhaleySrcHitBubble(CGPoint viewPoint) {
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.scene) {
        return NO;
    }
    CGPoint scenePoint = WhaleySceneScrubScenePoint(viewPoint);
    for (Projectile *bubble in [game.projectiles reverseObjectEnumerator]) {
        if (!bubble.visible || !bubble.parent) {
            continue;
        }
        CGPoint parentPoint = [bubble.parent convertPoint:scenePoint fromNode:game.scene];
        CGRect hit = CGRectInset([bubble boundingBox], -TouchBubbleFudgeOffset, -TouchBubbleFudgeOffset);
        if (CGRectContainsPoint(hit, parentPoint)) {
            return YES;
        }
    }
    return NO;
}

static GameObject *WhaleySceneScrubAccessibleObject(NSUInteger index) {
    NSArray *objects = WhaleySceneScrubCandidates(WhaleyCurrentGame);
    return index < objects.count ? objects[index] : nil;
}

NSUInteger WhaleySrcSceneScrubAccessibleObjectCount(void) {
    return WhaleySceneScrubCandidates(WhaleyCurrentGame).count;
}

NSString *WhaleySrcSceneScrubAccessibleObjectLabel(NSUInteger index) {
    GameObject *object = WhaleySceneScrubAccessibleObject(index);
    if (!object) {
        return @"Game object";
    }
    Whaley *game = WhaleyCurrentGame;
    if (object == game.player) {
        return @"Whaley";
    }
    if (object == game.goal) {
        return @"Goal bubble";
    }
    if ([object isKindOfClass:[Hazard class]]) {
        NSUInteger ordinal = [game.hazards indexOfObjectIdenticalTo:object];
        return [NSString stringWithFormat:@"Hazard %lu", (unsigned long)(ordinal == NSNotFound ? index + 1 : ordinal + 1)];
    }
    if ([object isKindOfClass:[Collectible class]]) {
        NSUInteger ordinal = [game.collectibles indexOfObjectIdenticalTo:object];
        return [NSString stringWithFormat:@"Collectible %lu", (unsigned long)(ordinal == NSNotFound ? index + 1 : ordinal + 1)];
    }
    return [NSString stringWithFormat:@"Game object %lu", (unsigned long)(index + 1)];
}

CGRect WhaleySrcSceneScrubAccessibleObjectFrame(NSUInteger index) {
    GameObject *object = WhaleySceneScrubAccessibleObject(index);
    Whaley *game = WhaleyCurrentGame;
    if (!object || !object.visible || !object.parent || !game.scene) {
        return CGRectZero;
    }
    CGRect box = [object boundingBox];
    CGPoint corners[4] = {
        CGPointMake(CGRectGetMinX(box), CGRectGetMinY(box)),
        CGPointMake(CGRectGetMaxX(box), CGRectGetMinY(box)),
        CGPointMake(CGRectGetMinX(box), CGRectGetMaxY(box)),
        CGPointMake(CGRectGetMaxX(box), CGRectGetMaxY(box))};
    CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
    for (NSInteger i = 0; i < 4; i++) {
        CGPoint scenePoint = [game.scene convertPoint:corners[i] fromNode:object.parent];
        CGPoint viewPoint = [game.scene convertPointToView:scenePoint];
        minX = MIN(minX, viewPoint.x);
        minY = MIN(minY, viewPoint.y);
        maxX = MAX(maxX, viewPoint.x);
        maxY = MAX(maxY, viewPoint.y);
    }
    return CGRectMake(minX, minY, MAX(1, maxX - minX), MAX(1, maxY - minY));
}

CGRect WhaleySrcSceneScrubActiveObjectFrame(void) {
    Whaley *game = WhaleyCurrentGame;
    GameObject *object = WhaleySceneScrubObject;
    if (!object || !object.visible || !object.parent || !game.scene) {
        return CGRectZero;
    }
    CGRect box = [object boundingBox];
    CGPoint corners[4] = {
        CGPointMake(CGRectGetMinX(box), CGRectGetMinY(box)),
        CGPointMake(CGRectGetMaxX(box), CGRectGetMinY(box)),
        CGPointMake(CGRectGetMinX(box), CGRectGetMaxY(box)),
        CGPointMake(CGRectGetMaxX(box), CGRectGetMaxY(box))};
    CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
    for (NSInteger i = 0; i < 4; i++) {
        CGPoint scenePoint = [game.scene convertPoint:corners[i] fromNode:object.parent];
        CGPoint viewPoint = [game.scene convertPointToView:scenePoint];
        minX = MIN(minX, viewPoint.x);
        minY = MIN(minY, viewPoint.y);
        maxX = MAX(maxX, viewPoint.x);
        maxY = MAX(maxY, viewPoint.y);
    }
    return CGRectMake(minX, minY, MAX(1, maxX - minX), MAX(1, maxY - minY));
}

BOOL WhaleySrcSceneScrubBeginAccessibleObject(NSUInteger index) {
    GameObject *object = WhaleySceneScrubAccessibleObject(index);
    if (!object || !object.visible || !object.parent) {
        return NO;
    }
    WhaleySceneScrubKind = WhaleySceneScrubTargetObject;
    WhaleySceneScrubObject = object;
    WhaleySceneScrubOriginPosition = object.position;
    WhaleySceneScrubOriginScaleX = object.scaleX;
    WhaleySceneScrubOriginScaleY = object.scaleY;
    WhaleySceneScrubImageIndex = 0;
    WhaleyCurrentGame.isPaused = YES;
    return YES;
}

static Projectile *WhaleyAccessibleBubble = nil;
static CGPoint WhaleyAccessibleBubbleOrigin = {0, 0};

static NSArray *WhaleyAccessibleBubbles(void) {
    Whaley *game = WhaleyCurrentGame;
    if (!game) {
        return @[];
    }
    NSMutableArray *result = [NSMutableArray array];
    for (Projectile *bubble in game.projectiles) {
        BOOL accessibilityOwnsBubble = (bubble == WhaleyAccessibleBubble);
        if (bubble.isFrozen && bubble.visible && bubble.parent && (!bubble.isBeingMoved || accessibilityOwnsBubble)) {
            [result addObject:bubble];
        }
    }
    return result;
}

static Projectile *WhaleyAccessibleBubbleAtIndex(NSUInteger index) {
    NSArray *bubbles = WhaleyAccessibleBubbles();
    return index < bubbles.count ? bubbles[index] : nil;
}

NSUInteger WhaleySrcAccessibleBubbleCount(void) {
    return WhaleyAccessibleBubbles().count;
}

NSString *WhaleySrcAccessibleBubbleLabel(NSUInteger index) {
    return [NSString stringWithFormat:@"Bubble %lu", (unsigned long)(index + 1)];
}

CGRect WhaleySrcAccessibleBubbleFrame(NSUInteger index) {
    Projectile *bubble = WhaleyAccessibleBubbleAtIndex(index);
    Whaley *game = WhaleyCurrentGame;
    if (!bubble || !game.scene) {
        return CGRectZero;
    }
    CGRect box = [bubble boundingBox];
    CGPoint corners[4] = {
        CGPointMake(CGRectGetMinX(box), CGRectGetMinY(box)),
        CGPointMake(CGRectGetMaxX(box), CGRectGetMinY(box)),
        CGPointMake(CGRectGetMinX(box), CGRectGetMaxY(box)),
        CGPointMake(CGRectGetMaxX(box), CGRectGetMaxY(box))};
    CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
    for (NSInteger i = 0; i < 4; i++) {
        CGPoint scenePoint = [game.scene convertPoint:corners[i] fromNode:bubble.parent];
        CGPoint viewPoint = [game.scene convertPointToView:scenePoint];
        minX = MIN(minX, viewPoint.x);
        minY = MIN(minY, viewPoint.y);
        maxX = MAX(maxX, viewPoint.x);
        maxY = MAX(maxY, viewPoint.y);
    }
    return CGRectMake(minX, minY, MAX(1, maxX - minX), MAX(1, maxY - minY));
}

BOOL WhaleySrcAccessibleBubbleBegin(NSUInteger index) {
    Projectile *bubble = WhaleyAccessibleBubbleAtIndex(index);
    Whaley *game = WhaleyCurrentGame;
    if (!bubble || !game) {
        return NO;
    }
    WhaleySrcSceneScrubEnd();
    WhaleyAccessibleBubble = bubble;
    WhaleyAccessibleBubbleOrigin = bubble.position;
    if (bubble.bouncesLeft < 0) {
        bubble.bouncesLeft = 2;
    }
    bubble.isBeingMoved = YES;
    bubble.relativeOffset = CGPointZero;
    bubble.scaleX = NormalSize;
    bubble.scaleY = NormalSize;
    game.isPaused = YES;
    return YES;
}

BOOL WhaleySrcAccessibleBubbleMove(CGFloat deltaX, CGFloat deltaY) {
    Projectile *bubble = WhaleyAccessibleBubble;
    Whaley *game = WhaleyCurrentGame;
    if (!bubble || !bubble.parent || !game) {
        return NO;
    }
    bubble.position = CGPointMake(WhaleyAccessibleBubbleOrigin.x + deltaX,
                                  WhaleyAccessibleBubbleOrigin.y + deltaY);
    return YES;
}

void WhaleySrcAccessibleBubbleEnd(void) {
    Projectile *bubble = WhaleyAccessibleBubble;
    Whaley *game = WhaleyCurrentGame;
    if (bubble) {
        CGFloat delta = NormalSize - SmallSize;
        bubble.position = CGPointMake(bubble.position.x + bubble.relativeOffset.x * delta,
                                      bubble.position.y + bubble.relativeOffset.y * delta);
        bubble.isBeingMoved = NO;
        bubble.scaleX = SmallSize;
        bubble.scaleY = SmallSize;
    }
    WhaleyAccessibleBubble = nil;
    if (game) {
        game.isPaused = NO;
    }
}

BOOL WhaleySrcSceneScrubCanAcquire(CGPoint viewPoint) {
    CGPoint scenePoint = WhaleySceneScrubScenePoint(viewPoint);
    if (WhaleySceneScrubHitObject(scenePoint)) {
        return YES;
    }
    return WhaleySceneScrubHitTile(scenePoint, NULL);
}

BOOL WhaleySrcSceneScrubBegin(CGPoint viewPoint) {
    CGPoint scenePoint = WhaleySceneScrubScenePoint(viewPoint);
    GameObject *object = WhaleySceneScrubHitObject(scenePoint);
    if (object) {
        WhaleySceneScrubKind = WhaleySceneScrubTargetObject;
        WhaleySceneScrubObject = object;
        WhaleySceneScrubOriginPosition = object.position;
        WhaleySceneScrubOriginScaleX = object.scaleX;
        WhaleySceneScrubOriginScaleY = object.scaleY;
        WhaleySceneScrubImageIndex = 0;
        WhaleyCurrentGame.isPaused = YES;
        return YES;
    }
    CGPoint tile;
    if (WhaleySceneScrubHitTile(scenePoint, &tile)) {
        WhaleySceneScrubKind = WhaleySceneScrubTargetTile;
        WhaleySceneScrubTileCoordinate = tile;
        NSInteger width = (NSInteger)WhaleyCurrentGame.tileMap.mapSize.width;
        [WhaleySceneScrubTileRowSnapshot release];
        WhaleySceneScrubTileRowSnapshot = [[NSMutableArray alloc] initWithCapacity:width];
        for (NSInteger column = 0; column < width; column++) {
            [WhaleySceneScrubTileRowSnapshot addObject:@([WhaleyCurrentGame.meta tileGIDAt:CGPointMake(column, tile.y)])];
        }
        WhaleySceneScrubTileAnchorGID = [WhaleyCurrentGame.meta tileGIDAt:tile];
        WhaleySceneScrubTileInitialRun = 1;
        for (NSInteger column = (NSInteger)tile.x + 1; column < width; column++) {
            if ([WhaleyCurrentGame.meta tileGIDAt:CGPointMake(column, tile.y)] == 0) {
                break;
            }
            WhaleySceneScrubTileInitialRun++;
        }
        WhaleyCurrentGame.isPaused = YES;
        WhaleySceneScrubShowTileOverlayRun(tile, WhaleySceneScrubTileInitialRun);
        return YES;
    }
    return NO;
}

static void WhaleySceneScrubApplyImage(GameObject *object, NSInteger steps) {
    NSInteger index = MAX(0, WhaleySceneScrubImageIndex + steps);
    SKSpriteNode *presentation = object.spriteKitNode;
    if (!presentation) {
        return;
    }
    NSString *name = nil;
    if ([object isKindOfClass:[Collectible class]]) {
        index = index % 8;
        name = [NSString stringWithFormat:@"coin%ld.png", (long)index + 1];
    } else if ([object isKindOfClass:[Player class]]) {
        index = index % 3;
        name = [NSString stringWithFormat:@"player%ld.png", (long)index + 1];
    } else if ([object isKindOfClass:[Hazard class]]) {
        index = index % 2;
        name = index == 0 ? @"flame01.png" : @"flame02.png";
        presentation.texture = WhaleySrcTexture(name);
        return;
    } else {
        return;
    }
    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:name];
    if (!frame || frame.atlasFile.length == 0) {
        return;
    }
    CGRect r = frame.frameRect;
    CGSize a = frame.atlasSize;
    SKTexture *atlas = WhaleySrcTexture(frame.atlasFile);
    CGRect normalized = CGRectMake(r.origin.x / a.width, 1.0 - (r.origin.y + r.size.height) / a.height, r.size.width / a.width, r.size.height / a.height);
    presentation.texture = [SKTexture textureWithRect:normalized inTexture:atlas];
}

void WhaleySrcSceneScrubApply(NSInteger category, NSInteger scalarSteps) {
    if (WhaleySceneScrubKind == WhaleySceneScrubTargetObject) {
        GameObject *object = WhaleySceneScrubObject;
        if (!object) {
            return;
        }
        switch (category) {
            case 0:
                object.position = CGPointMake(WhaleySceneScrubOriginPosition.x + scalarSteps * 32.0,
                                              WhaleySceneScrubOriginPosition.y);
                break;
            case 1: {
                CGFloat width = MAX(32.0, object.contentSize.width * WhaleySceneScrubOriginScaleX + scalarSteps * 32.0);
                CGFloat factor = object.contentSize.width > 0 ? width / object.contentSize.width : WhaleySceneScrubOriginScaleX;
                object.scaleX = factor;
                object.scaleY = factor;
                break;
            }
            case 2:
                WhaleySceneScrubApplyImage(object, scalarSteps);
                break;
            default:
                break;
        }
        return;
    }

    if (WhaleySceneScrubKind == WhaleySceneScrubTargetTile) {
        NSInteger width = (NSInteger)WhaleyCurrentGame.tileMap.mapSize.width;
        NSInteger row = (NSInteger)WhaleySceneScrubTileCoordinate.y;
        if (category == 0) {
            NSInteger column = MAX(0, MIN(width - 1, (NSInteger)WhaleySceneScrubTileCoordinate.x + scalarSteps));
            WhaleySceneScrubShowTileOverlayRun(CGPointMake(column, row), WhaleySceneScrubTileInitialRun);
        } else if (category == 1 && WhaleySceneScrubTileRowSnapshot) {
            for (NSInteger column = 0; column < width; column++) {
                [WhaleyCurrentGame.meta setTileGID:WhaleySceneScrubTileRowSnapshot[column].integerValue at:CGPointMake(column, row)];
            }
            NSInteger anchor = (NSInteger)WhaleySceneScrubTileCoordinate.x;
            NSInteger cells = MAX(1, MIN(width - anchor, WhaleySceneScrubTileInitialRun + scalarSteps));
            NSInteger affected = MAX(WhaleySceneScrubTileInitialRun, cells);
            for (NSInteger offset = 0; offset < affected && anchor + offset < width; offset++) {
                NSInteger gid = offset < cells ? WhaleySceneScrubTileAnchorGID : 0;
                [WhaleyCurrentGame.meta setTileGID:gid at:CGPointMake(anchor + offset, row)];
            }
            WhaleySceneScrubShowTileOverlayRun(WhaleySceneScrubTileCoordinate, cells);
        }
    }
}

void WhaleySrcSceneScrubEnd(void) {
    [WhaleySceneScrubTileOverlay removeFromParent];
    WhaleySceneScrubTileOverlay = nil;
    WhaleySceneScrubObject = nil;
    [WhaleySceneScrubTileRowSnapshot release];
    WhaleySceneScrubTileRowSnapshot = nil;
    WhaleySceneScrubKind = WhaleySceneScrubTargetNone;
    WhaleyCurrentGame.isPaused = NO;
}

CGPoint WhaleySrcPlayerPosition(void) {
    return WhaleyCurrentGame.player ? WhaleyCurrentGame.player.position : CGPointZero;
}

NSInteger WhaleySrcCurrentLevelNumber(void) {
    return WhaleyCurrentGame.level ? WhaleyCurrentGame.level.num : 0;
}

void WhaleySrcProjectPlayerPosition(CGPoint position) {
    if (WhaleyCurrentGame.player) {
        WhaleyCurrentGame.player.position = position;
    }
}

NSTimeInterval WhaleySrcGameTime(void) { return WhaleySrcSemanticTime(); }
NSUInteger WhaleySrcPlayerHistorySampleCount(void) { return WhaleySrcTrajectorySampleCount(); }
NSTimeInterval WhaleySrcPlayerHistoryFirstTime(void) { return WhaleySrcTrajectoryFirstTime(); }
NSTimeInterval WhaleySrcPlayerHistoryLastTime(void) { return WhaleySrcTrajectoryLastTime(); }

@interface WhaleyAdventureSyntheticTouch : NSObject
@property (nonatomic) CGPoint point;
@property (nonatomic, assign) UIView *hostView;
@end
@implementation WhaleyAdventureSyntheticTouch
- (CGPoint)locationInView:(UIView *)view {
    return self.point;
}
- (UIView *)view {
    return self.hostView;
}
@end

BOOL WhaleySrcAdventurePerformAction(WhaleyAdventureAction action) {
    Whaley *game = WhaleyCurrentGame;
    CCDirector *director = [CCDirector sharedDirector];
    CGSize viewport = director.compatViewSize;
    if (!game || viewport.width <= 0 || viewport.height <= 0 || game.player.isDead || game.player.hasWon) {
        return NO;
    }

    CGPoint center = [Helpers spriteCenter:game.player];
    CGFloat dx = game.tileMap.tileSize.width * 0.45;
    CGFloat dy = game.tileMap.tileSize.height * 0.80;
    CGPoint sceneTarget = center;
    switch (action) {
        case WhaleyAdventureActionShootLeft:
            sceneTarget = CGPointMake(center.x - dx, center.y - dy);
            break;
        case WhaleyAdventureActionShootRight:
            sceneTarget = CGPointMake(center.x + dx, center.y - dy);
            break;
        case WhaleyAdventureActionShootBelow:
            sceneTarget = CGPointMake(center.x, center.y - dy);
            break;
    }

    CGSize logical = director.winSize;
    CGFloat scale = MAX(viewport.width / logical.width, viewport.height / logical.height);
    CGFloat ox = (viewport.width - logical.width * scale) / 2.0;
    CGFloat oy = (viewport.height - logical.height * scale) / 2.0;
    CGPoint uiPoint = CGPointMake(sceneTarget.x * scale + ox,
                                  (logical.height - sceneTarget.y) * scale + oy);
    WhaleyAdventureSyntheticTouch *touch = [WhaleyAdventureSyntheticTouch new];
    touch.point = uiPoint;
    touch.hostView = nil;
    BOOL accepted = [game ccTouchBegan:(UITouch *)touch withEvent:nil];
    if (accepted) {
        [game ccTouchEnded:(UITouch *)touch withEvent:nil];
    }
    return accepted;
}

BOOL WhaleySrcAdventurePlayerIsDead(void) {
    return WhaleyCurrentGame ? WhaleyCurrentGame.player.isDead : NO;
}

CGPoint WhaleySrcAdventureViewPoint(CGPoint normalizedLevelPoint) {
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.scene || !game.meta || !game.tileMap) {
        return CGPointMake(NAN, NAN);
    }
    CGSize tile = game.tileMap.tileSize;
    CGSize map = game.tileMap.mapSize;
    CGFloat width = tile.width * map.width;
    CGFloat height = tile.height * map.height;
    CGPoint local = CGPointMake(normalizedLevelPoint.x * width,
                                (1.0 - normalizedLevelPoint.y) * height);
    CGPoint scenePoint = [game.scene convertPoint:local fromNode:game.meta];
    return [game.scene convertPointToView:scenePoint];
}

BOOL WhaleySrcAdventurePrepareCheckpoint(CGPoint normalizedLevelPoint) {
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.level || !game.tileMap) {
        return NO;
    }

    WhaleySrcReplayCurrentLevel();
    game = WhaleyCurrentGame;
    if (!game || !game.player || !game.tileMap) {
        return NO;
    }

    CGSize tile = game.tileMap.tileSize;
    CGSize map = game.tileMap.mapSize;
    CGFloat width = tile.width * map.width;
    CGFloat height = tile.height * map.height;
    if (width <= 0 || height <= 0) {
        return NO;
    }

    CGPoint position = CGPointMake(normalizedLevelPoint.x * width,
                                   (1.0 - normalizedLevelPoint.y) * height);
    game.player.position = position;
    game.player.desiredPos = position;
    game.player.isDead = NO;
    game.player.hasWon = NO;
    game.player.isMovingLaterally = NO;
    game.player.xAdd = 0;
    game.player.yAdd = 0;
    return YES;
}

CGSize WhaleySrcAdventureLevelSize(void) {
    Whaley *game = WhaleyCurrentGame;
    if (!game || !game.tileMap) {
        return CGSizeZero;
    }
    CGSize tile = game.tileMap.tileSize;
    CGSize map = game.tileMap.mapSize;
    return CGSizeMake(tile.width * map.width, tile.height * map.height);
}
#endif
