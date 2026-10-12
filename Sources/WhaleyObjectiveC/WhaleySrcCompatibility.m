#if __has_include(<UIKit/UIKit.h>)
#import <objc/message.h>
#import "WhaleyRuntimeBridge.h"
#import "cocos2d.h"

typedef struct {
    id target;
    SEL selector;
} WhaleyObjCActionContext;
static void WhaleyInvokeAction(void *rawContext, void *rawNode) {
    WhaleyObjCActionContext *context = rawContext;
    id node = (id)rawNode;
    ((void (*)(id, SEL, id))objc_msgSend)(context->target, context->selector, node);
    [context->target release];
    free(context);
}

@interface WhaleySchedulerDriver : NSObject
@property (nonatomic, assign) CCLayer *layer;
@property (nonatomic, assign) void *scheduler;
@property (nonatomic, retain) CADisplayLink *displayLink;
@property (nonatomic, retain) NSMutableDictionary<NSString *, NSNumber *> *scheduleIDs;
- (void)scheduleSelector:(SEL)selector interval:(ccTime)interval;
- (void)unscheduleSelector:(SEL)selector;
@end

static NSMapTable *WhaleySchedulerDrivers(void) {
    static NSMapTable *table;
    if (!table) {
        table = [[NSMapTable weakToStrongObjectsMapTable] retain];
    }
    return table;
}

static void WhaleyInvokeScheduled(void *rawContext, double dt) {
    WhaleySchedulerDriver *driver = (WhaleySchedulerDriver *)rawContext;
    (void)driver;
    (void)dt;
}

typedef struct {
    WhaleySchedulerDriver *driver;
    SEL selector;
} WhaleyScheduleContext;
static void WhaleyInvokeScheduledSelector(void *rawContext, double dt) {
    WhaleyScheduleContext *context = rawContext;
    CCLayer *layer = context->driver.layer;
    if (layer) {
        ((void (*)(id, SEL, ccTime))objc_msgSend)(layer, context->selector, (ccTime)dt);
    }
}

@implementation WhaleySchedulerDriver
- (instancetype)init {
    if ((self = [super init])) {
        _scheduler = WhaleySchedulerCreate();
        _scheduleIDs = [[NSMutableDictionary alloc] init];
        _displayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)] retain];
        [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    return self;
}
- (void)tick:(CADisplayLink *)link {
    double delta = link.targetTimestamp - link.timestamp;
    if (delta <= 0) {
        delta = link.duration;
    }
    WhaleySchedulerAdvance(_scheduler, delta);
}
- (void)scheduleSelector:(SEL)selector interval:(ccTime)interval {
    NSString *key = NSStringFromSelector(selector);
    [self unscheduleSelector:selector];
    WhaleyScheduleContext *context = calloc(1, sizeof(*context));
    context->driver = self;
    context->selector = selector;
    uint64_t scheduleID = WhaleySchedulerSchedule(_scheduler, interval, context, WhaleyInvokeScheduledSelector);
    _scheduleIDs[key] = @(scheduleID);
    [CCCompatTrace record:@"schedule.lower" detail:[NSString stringWithFormat:@"%@ @ %.6g", key, interval]];
}
- (void)unscheduleSelector:(SEL)selector {
    NSString *key = NSStringFromSelector(selector);
    NSNumber *number = _scheduleIDs[key];
    if (!number) {
        return;
    }
    WhaleySchedulerCancel(_scheduler, number.unsignedLongLongValue);
    [_scheduleIDs removeObjectForKey:key];
    [CCCompatTrace record:@"unschedule.lower" detail:key];
}
- (void)dealloc {
    [_displayLink invalidate];
    [_displayLink release];
    WhaleyReleaseScheduler(_scheduler);
    [_scheduleIDs release];
    [super dealloc];
}
@end

@implementation CCLayer (SrcScheduling)
- (void)schedule:(SEL)selector {
    [self schedule:selector interval:1.0 / 60.0];
}
- (void)schedule:(SEL)selector interval:(ccTime)interval {
    WhaleySchedulerDriver *driver = [WhaleySchedulerDrivers() objectForKey:self];
    if (!driver) {
        driver = [[[WhaleySchedulerDriver alloc] init] autorelease];
        driver.layer = self;
        [WhaleySchedulerDrivers() setObject:driver forKey:self];
    }
    [driver scheduleSelector:selector interval:interval];
}
- (void)unschedule:(SEL)selector {
    [[WhaleySchedulerDrivers() objectForKey:self] unscheduleSelector:selector];
}
- (void)registerWithTouchDispatcher {
}
@end

@implementation CCSprite (SrcAppearance)
- (GLubyte)opacity {
    return (GLubyte)lrint(self.spriteKitNode.alpha * 255.0);
}
- (void)setOpacity:(GLubyte)o {
    self.spriteKitNode.alpha = (CGFloat)o / 255.0;
}
- (ccColor3B)color {
    return ccWHITE;
}
- (void)setColor:(ccColor3B)c {
    self.spriteKitNode.color = [UIColor colorWithRed:c.r / 255.0 green:c.g / 255.0 blue:c.b / 255.0 alpha:1];
    self.spriteKitNode.colorBlendFactor = 1;
}
@end
@implementation CCFadeTo
+ (instancetype)actionWithDuration:(ccTime)d opacity:(GLubyte)o {
    CCFadeTo *a = [self new];
    a.gameAction = WhaleyGameActionFade(d, (double)o / 255.0);
    return [a autorelease];
}
@end
@implementation CCCallFuncN
+ (instancetype)actionWithTarget:(id)target selector:(SEL)selector {
    CCCallFuncN *action = [self new];
    WhaleyObjCActionContext *context = calloc(1, sizeof(*context));
    context->target = [target retain];
    context->selector = selector;
    uint64_t callbackID = WhaleyRegisterActionCallback(context, WhaleyInvokeAction);
    action.gameAction = WhaleyGameActionCallback(callbackID);
    [CCCompatTrace record:@"CCCallFuncN.lower" detail:NSStringFromSelector(selector)];
    return [action autorelease];
}
@end
@implementation CCDirector (SrcInput)
- (CCTouchDispatcher *)touchDispatcher {
    static CCTouchDispatcher *d;
    if (!d) {
        d = [CCTouchDispatcher new];
    }
    return d;
}
- (CGPoint)convertToGL:(CGPoint)p {
    CGSize logical = self.winSize;
    CGSize view = self.compatViewSize;
    if (view.width <= 0 || view.height <= 0) {
        view = UIScreen.mainScreen.bounds.size;
    }
    CGFloat scale = MAX(view.width / logical.width, view.height / logical.height);
    CGFloat ox = (view.width - logical.width * scale) / 2.0;
    CGFloat oy = (view.height - logical.height * scale) / 2.0;
    return CGPointMake((p.x - ox) / scale, logical.height - ((p.y - oy) / scale));
}
@end
#endif
