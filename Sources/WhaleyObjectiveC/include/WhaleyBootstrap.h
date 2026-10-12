#if __has_include(<UIKit/UIKit.h>)
#import <SpriteKit/SpriteKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

void WhaleySrcSetResourceBundle(NSBundle *bundle);
NSBundle *WhaleySrcResourceBundle(void);
NSURL *_Nullable WhaleySrcResourceURL(NSString *filename);
SKTexture *WhaleySrcTexture(NSString *filename);

SKScene *WhaleyCreateSrcLevelScene(NSInteger levelNumber);
SKScene *WhaleyCreateSrcLevelOneScene(void);
SKScene *WhaleyCreateSrcLevelTwoScene(void);

void WhaleySrcSetCompatViewSize(CGSize size);
void WhaleySrcSetSuppressedFlames(NSArray<NSNumber *> *indices);
NSArray<NSValue *> *WhaleySrcFlamePositions(void);
NSDictionary<NSString *, id> *WhaleySrcSceneSnapshotElements(void);

void WhaleySrcReplayCurrentLevel(void);
void WhaleySrcAdvanceAfterWin(void);

BOOL WhaleySrcTouchBegan(UITouch *touch, UIEvent *_Nullable event);
void WhaleySrcTouchMoved(UITouch *touch, UIEvent *_Nullable event);
void WhaleySrcTouchEnded(UITouch *touch, UIEvent *_Nullable event);
void WhaleySrcTouchCancelled(UITouch *touch, UIEvent *_Nullable event);

void WhaleySrcSetSceneScrubPaused(BOOL paused);
void WhaleySrcBeginTimeProjection(void);
BOOL WhaleySrcProjectTime(NSTimeInterval seconds);
void WhaleySrcRestoreLiveProjection(void);
CGPoint WhaleySrcPlayerPosition(void);
NSInteger WhaleySrcCurrentLevelNumber(void);
void WhaleySrcProjectPlayerPosition(CGPoint position);
NSTimeInterval WhaleySrcGameTime(void);
NSUInteger WhaleySrcPlayerHistorySampleCount(void);
NSTimeInterval WhaleySrcPlayerHistoryFirstTime(void);
NSTimeInterval WhaleySrcPlayerHistoryLastTime(void);

BOOL WhaleySrcHitBubble(CGPoint viewPoint);
BOOL WhaleySrcSceneScrubCanAcquire(CGPoint viewPoint);
BOOL WhaleySrcSceneScrubBegin(CGPoint viewPoint);
NSUInteger WhaleySrcSceneScrubAccessibleObjectCount(void);
NSString *WhaleySrcSceneScrubAccessibleObjectLabel(NSUInteger index);
CGRect WhaleySrcSceneScrubAccessibleObjectFrame(NSUInteger index);
CGRect WhaleySrcSceneScrubActiveObjectFrame(void);
BOOL WhaleySrcSceneScrubBeginAccessibleObject(NSUInteger index);

NSUInteger WhaleySrcAccessibleBubbleCount(void);
NSString *WhaleySrcAccessibleBubbleLabel(NSUInteger index);
CGRect WhaleySrcAccessibleBubbleFrame(NSUInteger index);
BOOL WhaleySrcAccessibleBubbleBegin(NSUInteger index);
BOOL WhaleySrcAccessibleBubbleMove(CGFloat deltaX, CGFloat deltaY);
void WhaleySrcAccessibleBubbleEnd(void);
void WhaleySrcSceneScrubApply(NSInteger category, NSInteger scalarSteps);
void WhaleySrcSceneScrubEnd(void);

NS_ASSUME_NONNULL_END

typedef NS_ENUM(NSInteger, WhaleyAdventureAction) {
    WhaleyAdventureActionShootLeft = 0,
    WhaleyAdventureActionShootRight = 1,
    WhaleyAdventureActionShootBelow = 2,
};
BOOL WhaleySrcAdventurePerformAction(WhaleyAdventureAction action);
BOOL WhaleySrcAdventurePlayerIsDead(void);
CGPoint WhaleySrcAdventureViewPoint(CGPoint normalizedLevelPoint);
BOOL WhaleySrcAdventurePrepareCheckpoint(CGPoint normalizedLevelPoint);

CGSize WhaleySrcAdventureLevelSize(void);
#endif
