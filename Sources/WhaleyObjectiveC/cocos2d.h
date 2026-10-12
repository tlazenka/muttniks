#if __has_include(<UIKit/UIKit.h>)
#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static inline CGPoint ccp(CGFloat x, CGFloat y) { return CGPointMake(x, y); }
static inline CGPoint ccpAdd(CGPoint a, CGPoint b) { return CGPointMake(a.x + b.x, a.y + b.y); }
static inline CGPoint ccpSub(CGPoint a, CGPoint b) { return CGPointMake(a.x - b.x, a.y - b.y); }
static inline CGPoint ccpMult(CGPoint a, CGFloat s) { return CGPointMake(a.x * s, a.y * s); }

typedef CGFloat ccTime;

typedef struct {
    uint8_t r, g, b;
} ccColor3B;
typedef struct {
    uint8_t r, g, b, a;
} ccColor4B;
typedef struct {
    float r, g, b, a;
} ccColor4F;
typedef ccColor4F ccColor4f;
static const ccColor3B ccBLACK = {0, 0, 0};
static const ccColor3B ccWHITE = {255, 255, 255};
static const ccColor3B ccRED = {255, 0, 0};
static const ccColor3B ccGREEN = {0, 255, 0};

static inline ccColor3B ccc3(uint8_t r, uint8_t g, uint8_t b) {
    return (ccColor3B){r, g, b};
}

static inline ccColor4B ccc4(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    return (ccColor4B){r, g, b, a};
}

@class CCAction, CCFiniteTimeAction, CCTMXLayer, CCTMXObjectGroup, CCAnimation, CCTouchDispatcher, CCSpriteBatchNode;

@interface CCCompatTrace : NSObject
+ (void)setEnabled:(BOOL)enabled;
+ (void)record:(NSString *)operation detail:(NSString *)detail;
+ (NSArray<NSString *> *)drain;
@end

@interface CCNode : SKNode
@property (nonatomic) CGSize contentSize;
@property (nonatomic) CGFloat scaleX;
@property (nonatomic) CGFloat scaleY;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic) BOOL visible;
@property (nonatomic) NSInteger tag;
@property (nonatomic) BOOL ignoreAnchorPointForPosition;
- (void)addChild:(CCNode *)child z:(NSInteger)z;
- (void)addChild:(CCNode *)child z:(NSInteger)z tag:(NSInteger)tag;
- (void)removeChild:(CCNode *)child cleanup:(BOOL)cleanup;
- (CCAction *)runAction:(CCAction *)action;
- (void)stopAction:(CCAction *)action;
- (CGPoint)convertToNodeSpace:(CGPoint)point;
@end

@interface CCLayer : CCNode
@property (nonatomic) BOOL isTouchEnabled;
- (void)schedule:(SEL)selector;
- (void)schedule:(SEL)selector interval:(ccTime)interval;
- (void)unschedule:(SEL)selector;
- (void)registerWithTouchDispatcher;
@end
@interface CCLayerColor : CCLayer
+ (instancetype)layerWithColor:(ccColor4B)color width:(CGFloat)width height:(CGFloat)height;
@end
@interface CCScene : CCLayer
@end

@interface CCSprite : CCNode
@property (nonatomic, strong, readonly) SKSpriteNode *spriteKitNode;
@property (nonatomic) CGRect textureRect;
@property (nonatomic) GLubyte opacity;
@property (nonatomic) ccColor3B color;
@property (nonatomic) BOOL flipX;
@property (nonatomic) BOOL flipY;
@property (nonatomic, assign, nullable) CCSpriteBatchNode *batchNode;
+ (instancetype)spriteWithFile:(NSString *)file;
+ (instancetype)spriteWithSpriteFrameName:(NSString *)name;
- (CGRect)boundingBox;
@end
@interface CCSpriteBatchNode : CCNode
+ (instancetype)batchNodeWithFile:(NSString *)file;
@end

@interface CCAction : NSObject
@property (nonatomic, assign) void *gameAction;
@end
@interface CCFiniteTimeAction : CCAction
@end
@interface CCMoveTo : CCFiniteTimeAction
+ (instancetype)actionWithDuration:(ccTime)duration position:(CGPoint)position;
@end
@interface CCScaleTo : CCFiniteTimeAction
+ (instancetype)actionWithDuration:(ccTime)duration scale:(CGFloat)scale;
@end
@interface CCRotateBy : CCFiniteTimeAction
+ (instancetype)actionWithDuration:(ccTime)duration angle:(CGFloat)angle;
@end
@interface CCDelayTime : CCFiniteTimeAction
+ (instancetype)actionWithDuration:(ccTime)duration;
@end
@interface CCSequence : CCFiniteTimeAction
+ (instancetype)actions:(CCFiniteTimeAction *)first, ... NS_REQUIRES_NIL_TERMINATION;
@end
@interface CCFadeTo : CCFiniteTimeAction
+ (instancetype)actionWithDuration:(ccTime)duration opacity:(GLubyte)opacity;
@end
@interface CCCallFuncN : CCFiniteTimeAction
+ (instancetype)actionWithTarget:(id)target selector:(SEL)selector;
@end
@interface CCRepeatForever : CCAction
+ (instancetype)actionWithAction:(CCFiniteTimeAction *)action;
@end

@interface CCSpriteFrame : NSObject
@property (nonatomic, copy) NSString *frameName;
@property (nonatomic, copy) NSString *atlasFile;
@property (nonatomic) CGRect frameRect;
@property (nonatomic) CGSize atlasSize;
@property (nonatomic) CGPoint frameOffset;
@property (nonatomic) CGSize originalSize;
@property (nonatomic) BOOL rotated;
@end
@interface CCSpriteFrameCache : NSObject
+ (instancetype)sharedSpriteFrameCache;
- (void)addSpriteFramesWithFile:(NSString *)file;
- (nullable CCSpriteFrame *)spriteFrameByName:(NSString *)name;
- (void)removeUnusedSpriteFrames;
@end
@interface CCAnimation : NSObject
@property (nonatomic, copy) NSArray<CCSpriteFrame *> *frames;
@property (nonatomic) ccTime delay;
@property (nonatomic) BOOL restoreOriginalFrame;
+ (instancetype)animationWithSpriteFrames:(NSArray<CCSpriteFrame *> *)frames delay:(ccTime)delay;
@end
@interface CCAnimate : CCFiniteTimeAction
+ (instancetype)actionWithAnimation:(CCAnimation *)animation;
@end

@interface CCTMXLayer : CCNode
@property (nonatomic, copy, readonly) NSString *layerName;
- (NSInteger)tileGIDAt:(CGPoint)tileCoord;
- (void)setTileGID:(NSInteger)gid at:(CGPoint)tileCoord;
- (nullable CCSprite *)tileAt:(CGPoint)tileCoord;
@end

@interface CCTMXTiledMap : CCNode
@property (nonatomic) CGSize mapSize;
@property (nonatomic) CGSize tileSize;
+ (instancetype)tiledMapWithTMXFile:(NSString *)file;
- (nullable CCTMXLayer *)layerNamed:(NSString *)name;
- (nullable CCTMXObjectGroup *)objectGroupNamed:(NSString *)name;
- (nullable NSDictionary *)propertiesForGID:(NSInteger)gid;
@end

@interface CCTMXObjectGroup : NSObject
@property (nonatomic, copy) NSArray<NSDictionary *> *objects;
- (nullable NSDictionary *)objectNamed:(NSString *)name;
@end

@interface CCDirector : NSObject
@property (nonatomic, readonly) CGSize winSize;
- (void)setCompatWinSize:(CGSize)size;
- (void)setCompatViewSize:(CGSize)size;
@property (nonatomic, readonly) CGSize compatViewSize;
@property (nonatomic, readonly) CCTouchDispatcher *touchDispatcher;
- (CGPoint)convertToGL:(CGPoint)point;
+ (instancetype)sharedDirector NS_SWIFT_NAME(shared());
@end
@interface CCTouchDispatcher : NSObject
- (void)addTargetedDelegate:(id)delegate priority:(NSInteger)priority swallowsTouches:(BOOL)swallowsTouches;
- (BOOL)dispatchTouchBegan:(UITouch *)touch withEvent:(nullable UIEvent *)event;
- (void)dispatchTouchMoved:(UITouch *)touch withEvent:(nullable UIEvent *)event;
- (void)dispatchTouchEnded:(UITouch *)touch withEvent:(nullable UIEvent *)event;
- (void)dispatchTouchCancelled:(UITouch *)touch withEvent:(nullable UIEvent *)event;
@end

#define CCLOG(...) NSLog(__VA_ARGS__)

NS_ASSUME_NONNULL_END
#endif
