#if __has_include(<UIKit/UIKit.h>)
#import "cocos2d.h"
#import <objc/message.h>
#import <zlib.h>
#import "WhaleyBootstrap.h"
#import "WhaleyRuntimeBridge.h"

@implementation CCCompatTrace
static BOOL _traceEnabled = NO;
static NSMutableArray<NSString *> *_trace;
static const NSUInteger CCCompatTraceCapacity = 4096;

+ (void)setEnabled:(BOOL)enabled {
    @synchronized(self) {
        _traceEnabled = enabled;
        if (enabled && !_trace) {
            _trace = [[NSMutableArray alloc] init];
        }
    }
}

+ (void)record:(NSString *)operation detail:(NSString *)detail {
    @synchronized(self) {
        if (!_traceEnabled) {
            return;
        }
        if (!_trace) {
            _trace = [[NSMutableArray alloc] init];
        }
        NSString *entry = [NSString stringWithFormat:@"%@ %@", operation ?: @"", detail ?: @""];
        if (_trace.count >= CCCompatTraceCapacity) {
            [_trace removeObjectAtIndex:0];
        }
        [_trace addObject:entry];
    }
}

+ (NSArray<NSString *> *)drain {
    @synchronized(self) {
        NSArray *result = _trace ? [[_trace copy] autorelease] : @[];
        [_trace removeAllObjects];
        return result;
    }
}
@end

@implementation CCNode {
    CGSize _contentSize;
    CGPoint _anchorPoint;
    BOOL _visible;
    NSInteger _tag;
    BOOL _ignoreAnchorPointForPosition;
}
- (instancetype)init {
    if ((self = [super init])) {
        self.xScale = 1;
        self.yScale = 1;
        _anchorPoint = CGPointMake(.5, .5);
        _visible = YES;
    }
    return self;
}
- (CGSize)contentSize {
    return _contentSize;
}
- (void)setContentSize:(CGSize)v {
    _contentSize = v;
}
- (CGFloat)scaleX {
    return self.xScale;
}
- (void)setScaleX:(CGFloat)v {
    self.xScale = v;
}
- (CGFloat)scaleY {
    return self.yScale;
}
- (void)setScaleY:(CGFloat)v {
    self.yScale = v;
}
- (BOOL)visible {
    return _visible;
}
- (void)setVisible:(BOOL)v {
    _visible = v;
    self.hidden = !v;
}
- (NSInteger)tag {
    return _tag;
}
- (void)setTag:(NSInteger)v {
    _tag = v;
    self.name = [NSString stringWithFormat:@"tag:%ld", (long)v];
}
- (BOOL)ignoreAnchorPointForPosition {
    return _ignoreAnchorPointForPosition;
}
- (void)setIgnoreAnchorPointForPosition:(BOOL)v {
    _ignoreAnchorPointForPosition = v;
}
- (CGPoint)anchorPoint {
    return _anchorPoint;
}
- (void)setAnchorPoint:(CGPoint)v {
    _anchorPoint = v;
}
- (void)setPosition:(CGPoint)p {
    [super setPosition:p];
    [CCCompatTrace record:@"CCNode.setPosition" detail:NSStringFromCGPoint(p)];
}
- (void)addChild:(CCNode *)child z:(NSInteger)z {
    child.zPosition = z;
    [super addChild:child];
}
- (void)addChild:(CCNode *)child z:(NSInteger)z tag:(NSInteger)tag {
    child.tag = tag;
    [self addChild:child z:z];
}
- (void)removeChild:(CCNode *)child cleanup:(BOOL)cleanup {
    [child removeFromParent];
}
- (CCAction *)runAction:(CCAction *)action {
    void *raw = WhaleyRenderGameAction(action.gameAction, (__bridge void *)self);
    SKAction *rendered = (__bridge SKAction *)raw;
    [super runAction:rendered];
    WhaleyReleaseRenderedObject(raw);
    [CCCompatTrace record:@"CCNode.runAction" detail:NSStringFromClass(action.class)];
    return action;
}
- (void)stopAction:(CCAction *)action {
    [self removeAllActions];
}
- (CGPoint)convertToNodeSpace:(CGPoint)point {
    return [self convertPoint:point fromNode:self.scene];
}
@end
@implementation CCLayer {
    BOOL _isTouchEnabled;
}
- (BOOL)isTouchEnabled {
    return _isTouchEnabled;
}
- (void)setIsTouchEnabled:(BOOL)v {
    _isTouchEnabled = v;
    if (v) {
        [self registerWithTouchDispatcher];
    }
}
@end
@implementation CCScene
@end

@implementation CCSprite {
    SKSpriteNode *_spriteKitNode;
    CGRect _textureRect;
    CGPoint _frameOffset;
    BOOL _flipX, _flipY;
    CCSpriteBatchNode *_batchNode;
}
+ (instancetype)spriteWithFile:(NSString *)file {
    CCSprite *n = [self new];
    SKTexture *t = WhaleySrcTexture(file);
    n->_spriteKitNode = [SKSpriteNode spriteNodeWithTexture:t];
    n.contentSize = t.size;
    [n addChild:(CCNode *)(id)n->_spriteKitNode];
    [CCCompatTrace record:@"CCSprite.file" detail:[NSString stringWithFormat:@"%@ %.0fx%.0f", file, t.size.width, t.size.height]];
    return [n autorelease];
}
+ (instancetype)spriteWithSpriteFrameName:(NSString *)name {
    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:name];
    if (!frame) {
        [CCCompatTrace record:@"CCSprite.frame.missing" detail:name];
        return nil;
    }
    CGRect r = frame.frameRect;
    CCSprite *n = [self new];
    if (frame.atlasFile.length > 0) {
        SKTexture *atlas = WhaleySrcTexture(frame.atlasFile);
        CGSize a = frame.atlasSize;
        CGRect normalized = CGRectMake(r.origin.x / a.width, 1.0 - (r.origin.y + r.size.height) / a.height, r.size.width / a.width, r.size.height / a.height);
        SKTexture *texture = [SKTexture textureWithRect:normalized inTexture:atlas];
        n->_spriteKitNode = [SKSpriteNode spriteNodeWithTexture:texture];
        [n addChild:(CCNode *)(id)n->_spriteKitNode];
    }
    n.contentSize = CGSizeEqualToSize(frame.originalSize, CGSizeZero) ? r.size : frame.originalSize;
    n.textureRect = r;
    n->_frameOffset = frame.frameOffset;
    [n cc_updatePresentationTransform];
    [CCCompatTrace record:@"CCSprite.frame" detail:[NSString stringWithFormat:@"%@ %@ crop %.0fx%.0f logical %.0fx%.0f offset %@", name, frame.atlasFile, r.size.width, r.size.height, n.contentSize.width, n.contentSize.height, NSStringFromCGPoint(frame.frameOffset)]];
    return [n autorelease];
}
- (SKSpriteNode *)spriteKitNode {
    return _spriteKitNode;
}
- (CGRect)textureRect {
    return _textureRect;
}
- (void)setTextureRect:(CGRect)v {
    _textureRect = v;
}
- (void)cc_updatePresentationTransform {
    if (!_spriteKitNode) {
        return;
    }
    CGPoint a = self.anchorPoint;
    CGSize size = self.contentSize;
    _spriteKitNode.anchorPoint = a;
    _spriteKitNode.xScale = _flipX ? -1 : 1;
    _spriteKitNode.yScale = _flipY ? -1 : 1;
    CGFloat flipCompX = _flipX ? (1.0 - 2.0 * a.x) * size.width : 0;
    CGFloat flipCompY = _flipY ? (1.0 - 2.0 * a.y) * size.height : 0;
    CGFloat offsetX = _flipX ? -_frameOffset.x : _frameOffset.x;
    CGFloat offsetY = _flipY ? -_frameOffset.y : _frameOffset.y;
    _spriteKitNode.position = CGPointMake(flipCompX + offsetX, flipCompY + offsetY);
}
- (void)setAnchorPoint:(CGPoint)v {
    [super setAnchorPoint:v];
    [self cc_updatePresentationTransform];
}
- (void)setContentSize:(CGSize)v {
    [super setContentSize:v];
    [self cc_updatePresentationTransform];
}
- (BOOL)flipX {
    return _flipX;
}
- (void)setFlipX:(BOOL)v {
    _flipX = v;
    [self cc_updatePresentationTransform];
}
- (BOOL)flipY {
    return _flipY;
}
- (void)setFlipY:(BOOL)v {
    _flipY = v;
    [self cc_updatePresentationTransform];
}
- (CCSpriteBatchNode *)batchNode {
    return _batchNode;
}
- (void)setBatchNode:(CCSpriteBatchNode *)v {
    _batchNode = v;
}
- (CGRect)boundingBox {
    return CGRectMake(self.position.x - self.contentSize.width * self.scaleX * self.anchorPoint.x, self.position.y - self.contentSize.height * self.scaleY * self.anchorPoint.y, self.contentSize.width * self.scaleX, self.contentSize.height * self.scaleY);
}
@end
@implementation CCSpriteBatchNode
+ (instancetype)batchNodeWithFile:(NSString *)file {
    return [self new];
}
- (void)addChild:(CCNode *)child z:(NSInteger)z {
    if ([child isKindOfClass:[CCSprite class]]) {
        ((CCSprite *)child).batchNode = self;
    }
    [super addChild:child z:z];
}
- (void)addChild:(CCNode *)child z:(NSInteger)z tag:(NSInteger)tag {
    if ([child isKindOfClass:[CCSprite class]]) {
        ((CCSprite *)child).batchNode = self;
    }
    [super addChild:child z:z tag:tag];
}
@end

@implementation CCAction
- (void)dealloc {
    if (_gameAction) {
        WhaleyReleaseGameAction(_gameAction);
    }
}
@end
@implementation CCFiniteTimeAction
@end
@implementation CCMoveTo
+ (instancetype)actionWithDuration:(ccTime)d position:(CGPoint)p {
    CCMoveTo *a = [self new];
    a.gameAction = WhaleyGameActionMoveTo(p.x, p.y, d);
    [CCCompatTrace record:@"CCMoveTo.lower" detail:NSStringFromCGPoint(p)];
    return a;
}
@end
@implementation CCScaleTo
+ (instancetype)actionWithDuration:(ccTime)d scale:(CGFloat)s {
    CCScaleTo *a = [self new];
    a.gameAction = WhaleyGameActionScaleTo(s, d);
    [CCCompatTrace record:@"CCScaleTo.lower" detail:[NSString stringWithFormat:@"%g", s]];
    return a;
}
@end
@implementation CCRotateBy
+ (instancetype)actionWithDuration:(ccTime)d angle:(CGFloat)angle {
    CCRotateBy *a = [self new];
    a.gameAction = WhaleyGameActionRotateBy(angle, d);
    [CCCompatTrace record:@"CCRotateBy.lower" detail:[NSString stringWithFormat:@"%g", angle]];
    return a;
}
@end
@implementation CCDelayTime
+ (instancetype)actionWithDuration:(ccTime)d {
    CCDelayTime *a = [self new];
    a.gameAction = WhaleyGameActionWait(d);
    [CCCompatTrace record:@"CCDelayTime.lower" detail:[NSString stringWithFormat:@"%g", d]];
    return a;
}
@end
@implementation CCSequence
+ (instancetype)actions:(CCFiniteTimeAction *)first, ... {
    NSMutableArray<CCFiniteTimeAction *> *actions = [NSMutableArray array];
    va_list ap;
    va_start(ap, first);
    for (CCFiniteTimeAction *a = first; a; a = va_arg(ap, CCFiniteTimeAction *)) {
        [actions addObject:a];
    }
    va_end(ap);
    void **raw = calloc(actions.count, sizeof(void *));
    for (NSUInteger i = 0; i < actions.count; i++) {
        raw[i] = actions[i].gameAction;
    }
    CCSequence *r = [self new];
    r.gameAction = WhaleyGameActionSequence(raw, actions.count);
    free(raw);
    [CCCompatTrace record:@"CCSequence.lower" detail:[NSString stringWithFormat:@"%lu", (unsigned long)actions.count]];
    return r;
}
@end
@implementation CCRepeatForever
+ (instancetype)actionWithAction:(CCFiniteTimeAction *)action {
    CCRepeatForever *r = [self new];
    r.gameAction = WhaleyGameActionRepeatForever(action.gameAction);
    [CCCompatTrace record:@"CCRepeatForever.lower" detail:NSStringFromClass(action.class)];
    return r;
}
@end

@implementation CCSpriteFrame
@end

@implementation CCSpriteFrameCache {
    NSMutableDictionary *_frames;
}
+ (instancetype)sharedSpriteFrameCache {
    static CCSpriteFrameCache *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        c = [self new];
    });
    return c;
}
- (instancetype)init {
    if ((self = [super init])) {
        _frames = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [_frames release];
    [super dealloc];
}
- (void)addSpriteFramesWithFile:(NSString *)file {
    NSString *base = file.stringByDeletingPathExtension;
    NSURL *url = WhaleySrcResourceURL(file);
    NSDictionary *plist = url ? [NSDictionary dictionaryWithContentsOfURL:url] : nil;
    NSDictionary *entries = plist[@"frames"];
    NSDictionary *texture = plist[@"texture"];
    NSString *atlas = [base stringByAppendingPathExtension:@"png"];
    if (!plist) {
        NSInteger count = [base isEqualToString:@"spout"] ? 4 : ([base isEqualToString:@"player-win"] ? 3 : 0);
        for (NSInteger i = 1; i <= count; i++) {
            NSString *name = [NSString stringWithFormat:@"%@%ld.png", base, (long)i];
            CCSpriteFrame *f = [CCSpriteFrame new];
            f.frameName = name;
            f.atlasFile = @"";
            f.frameRect = CGRectZero;
            f.atlasSize = CGSizeZero;
            f.originalSize = CGSizeZero;
            f.frameOffset = CGPointZero;
            f.rotated = NO;
            _frames[name] = f;
            WhaleyRegisterMissingSpriteFrame(name.UTF8String);
            [f release];
        }
        [CCCompatTrace record:@"CCSpriteFrameCache.missingSheet" detail:[NSString stringWithFormat:@"%@ (%ld semantic frames)", file, (long)count]];
        return;
    }
    CGSize atlasSize = CGSizeMake([texture[@"width"] doubleValue], [texture[@"height"] doubleValue]);
    for (NSString *name in entries) {
        NSDictionary *d = entries[name];
        CCSpriteFrame *f = [CCSpriteFrame new];
        f.frameName = name;
        f.atlasFile = atlas;
        f.frameRect = CGRectMake([d[@"x"] doubleValue], [d[@"y"] doubleValue], [d[@"width"] doubleValue], [d[@"height"] doubleValue]);
        f.atlasSize = atlasSize;
        f.frameOffset = CGPointMake([d[@"offsetX"] doubleValue], [d[@"offsetY"] doubleValue]);
        CGFloat originalWidth = d[@"originalWidth"] ? [d[@"originalWidth"] doubleValue] : f.frameRect.size.width;
        CGFloat originalHeight = d[@"originalHeight"] ? [d[@"originalHeight"] doubleValue] : f.frameRect.size.height;
        f.originalSize = CGSizeMake(originalWidth, originalHeight);
        f.rotated = [d[@"rotated"] boolValue];
        _frames[name] = f;
        WhaleyRegisterSpriteFrame(name.UTF8String, atlas.UTF8String, f.frameRect.origin.x, f.frameRect.origin.y, f.frameRect.size.width, f.frameRect.size.height, atlasSize.width, atlasSize.height);
        [f release];
    }
    [CCCompatTrace record:@"CCSpriteFrameCache.add" detail:[NSString stringWithFormat:@"%@ -> %@ (%lu frames)", file, atlas, (unsigned long)entries.count]];
}
- (CCSpriteFrame *)spriteFrameByName:(NSString *)name {
    return _frames[name];
}
- (void)removeUnusedSpriteFrames {
}
@end

@implementation CCAnimation
+ (instancetype)animationWithSpriteFrames:(NSArray<CCSpriteFrame *> *)frames delay:(ccTime)delay {
    CCAnimation *a = [self new];
    a.frames = frames;
    a.delay = delay;
    return [a autorelease];
}
- (void)dealloc {
    [_frames release];
    [super dealloc];
}
@end

@implementation CCAnimate
+ (instancetype)actionWithAnimation:(CCAnimation *)animation {
    NSUInteger count = animation.frames.count;
    const char **names = calloc(count, sizeof(char *));
    for (NSUInteger i = 0; i < count; i++) {
        names[i] = animation.frames[i].frameName.UTF8String;
    }
    CCAnimate *a = [self new];
    a.gameAction = WhaleyGameActionAnimate(names, count, animation.delay);
    free(names);
    [CCCompatTrace record:@"CCAnimate.lower" detail:[NSString stringWithFormat:@"%lu frames", (unsigned long)count]];
    return [a autorelease];
}
@end

@implementation CCTMXObjectGroup
- (NSDictionary *)objectNamed:(NSString *)name {
    for (NSDictionary *o in self.objects) {
        if ([o[@"name"] isEqual:name]) {
            return o;
        }
    }
    return nil;
}
@end

static NSData *CCGunzip(NSData *compressed) {
    if (compressed.length == 0) {
        return [NSData data];
    }
    z_stream stream = {0};
    stream.next_in = (Bytef *)compressed.bytes;
    stream.avail_in = (uInt)compressed.length;
    if (inflateInit2(&stream, 15 + 32) != Z_OK) {
        return nil;
    }
    NSMutableData *result = [NSMutableData dataWithLength:MAX((NSUInteger)4096, compressed.length * 3)];
    int status;
    do {
        if (stream.total_out >= result.length) {
            [result increaseLengthBy:MAX((NSUInteger)4096, compressed.length)];
        }
        stream.next_out = (Bytef *)result.mutableBytes + stream.total_out;
        stream.avail_out = (uInt)(result.length - stream.total_out);
        status = inflate(&stream, Z_NO_FLUSH);
    } while (status == Z_OK);
    inflateEnd(&stream);
    if (status != Z_STREAM_END) {
        return nil;
    }
    result.length = stream.total_out;
    return result;
}

@class CCTMXTiledMap;
@interface CCTMXParser : NSObject <NSXMLParserDelegate>
@property (nonatomic, assign) CCTMXTiledMap *map;
@property (nonatomic) NSInteger firstGID;
@property (nonatomic) NSInteger currentTileGID;
@property (nonatomic, copy) NSString *currentLayer;
@property (nonatomic, strong) NSMutableString *layerData;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *groups;
@property (nonatomic, copy) NSString *currentGroup;
@property (nonatomic, strong) NSMutableDictionary *currentObject;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableDictionary *> *gidProperties;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *decodedLayers;
@end

@interface CCTMXLayer ()
@property (nonatomic, copy, readwrite) NSString *layerName;
@property (nonatomic, assign) void *tileMapBox;
@property (nonatomic) CGSize compatTileSize;
@end

@interface CCTMXTiledMap ()
@property (nonatomic, assign) void *tileMapBox;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CCTMXLayer *> *compatLayers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CCTMXObjectGroup *> *compatGroups;
@property (nonatomic, strong) NSDictionary<NSNumber *, NSDictionary *> *compatGIDProperties;
@end

@implementation CCTMXParser
- (instancetype)init {
    if ((self = [super init])) {
        _groups = [NSMutableDictionary dictionary];
        _gidProperties = [NSMutableDictionary dictionary];
        _decodedLayers = [NSMutableArray array];
        _currentTileGID = -1;
    }
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)element namespaceURI:(NSString *)uri qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)a {
    if ([element isEqual:@"map"]) {
        self.map.mapSize = CGSizeMake(a[@"width"].doubleValue, a[@"height"].doubleValue);
        self.map.tileSize = CGSizeMake(a[@"tilewidth"].doubleValue, a[@"tileheight"].doubleValue);
    } else if ([element isEqual:@"tileset"]) {
        self.firstGID = a[@"firstgid"].integerValue;
    } else if ([element isEqual:@"tile"]) {
        self.currentTileGID = self.firstGID + a[@"id"].integerValue;
        self.gidProperties[@(self.currentTileGID)] = [NSMutableDictionary dictionary];
    } else if ([element isEqual:@"layer"]) {
        self.currentLayer = a[@"name"];
    } else if ([element isEqual:@"data"] && self.currentLayer) {
        self.layerData = [NSMutableString string];
    } else if ([element isEqual:@"objectgroup"]) {
        self.currentGroup = a[@"name"];
        self.groups[self.currentGroup] = [NSMutableArray array];
    } else if ([element isEqual:@"object"] && self.currentGroup) {
        self.currentObject = [NSMutableDictionary dictionary];
        for (NSString *key in @[ @"name", @"x", @"y", @"width", @"height" ]) {
            if (a[key]) {
                self.currentObject[key] = a[key];
            }
        }
    } else if ([element isEqual:@"property"]) {
        NSString *name = a[@"name"], *value = a[@"value"] ?: @"";
        if (self.currentObject) {
            self.currentObject[name] = value;
        } else if (self.currentTileGID >= 0) {
            self.gidProperties[@(self.currentTileGID)][name] = value;
        }
    }
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.layerData) {
        [self.layerData appendString:string];
    }
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)element namespaceURI:(NSString *)uri qualifiedName:(NSString *)qName {
    if ([element isEqual:@"data"] && self.layerData) {
        NSString *compact = [[self.layerData componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        NSData *encoded = [[NSData alloc] initWithBase64EncodedString:compact options:0];
        NSData *raw = CCGunzip(encoded);
        NSUInteger expected = (NSUInteger)(self.map.mapSize.width * self.map.mapSize.height);
        NSMutableData *gids = [NSMutableData dataWithLength:expected * sizeof(uint32_t)];
        if (raw.length >= gids.length) {
            const uint8_t *bytes = raw.bytes;
            uint32_t *out = gids.mutableBytes;
            for (NSUInteger i = 0; i < expected; i++) {
                out[i] = (uint32_t)bytes[i * 4] | ((uint32_t)bytes[i * 4 + 1] << 8) | ((uint32_t)bytes[i * 4 + 2] << 16) | ((uint32_t)bytes[i * 4 + 3] << 24);
            }
            [self.decodedLayers addObject:@{@"name" : self.currentLayer, @"gids" : gids}];
        }
        self.layerData = nil;
    } else if ([element isEqual:@"layer"]) {
        self.currentLayer = nil;
    } else if ([element isEqual:@"tile"]) {
        self.currentTileGID = -1;
    } else if ([element isEqual:@"object"] && self.currentObject) {
        CGFloat h = [self.currentObject[@"height"] doubleValue];
        CGFloat rawY = [self.currentObject[@"y"] doubleValue];
        self.currentObject[@"y"] = @(self.map.mapSize.height * self.map.tileSize.height - rawY - h);
        [self.groups[self.currentGroup] addObject:self.currentObject];
        self.currentObject = nil;
    } else if ([element isEqual:@"objectgroup"]) {
        self.currentGroup = nil;
    }
}
@end

@implementation CCTMXLayer
- (NSInteger)tileGIDAt:(CGPoint)tileCoord {
    if (!self.tileMapBox) {
        return 0;
    }
    NSInteger gid = (NSInteger)WhaleyTileMapGID(self.tileMapBox, self.layerName.UTF8String, (int)tileCoord.x, (int)tileCoord.y);
    [CCCompatTrace record:@"CCTMXLayer.tileGIDAt" detail:[NSString stringWithFormat:@"%@ (%ld,%ld) -> %ld", self.layerName, (long)tileCoord.x, (long)tileCoord.y, (long)gid]];
    return gid;
}
- (void)setTileGID:(NSInteger)gid at:(CGPoint)tileCoord {
    if (!self.tileMapBox) {
        return;
    }
    WhaleyTileMapSetGID(self.tileMapBox, self.layerName.UTF8String, (int)tileCoord.x, (int)tileCoord.y, (uint32_t)MAX(0, gid));
}
- (CCSprite *)tileAt:(CGPoint)tileCoord {
    if ([self tileGIDAt:tileCoord] == 0) {
        return nil;
    }
    CCSprite *tile = [CCSprite new];
    tile.contentSize = self.compatTileSize;
    tile.anchorPoint = CGPointZero;
    tile.position = CGPointMake(tileCoord.x * self.compatTileSize.width,
                                (self.parent ? ((CCTMXTiledMap *)self.parent).mapSize.height - 1 - tileCoord.y : 0) * self.compatTileSize.height);
    return [tile autorelease];
}
@end

@implementation CCTMXTiledMap
+ (instancetype)tiledMapWithTMXFile:(NSString *)file {
    CCTMXTiledMap *map = [self new];
    NSString *base = file.stringByDeletingPathExtension;
    NSString *ext = file.pathExtension.length ? file.pathExtension : @"tmx";
    NSURL *url = WhaleySrcResourceURL(file);
    if (!url && [base hasPrefix:@"level"]) {
        url = WhaleySrcResourceURL([@"original-" stringByAppendingString:file]);
    }
    NSAssert(url != nil, @"TMX resource %@ not found", file);
    CCTMXParser *delegate = [CCTMXParser new];
    delegate.map = map;
    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    parser.delegate = delegate;
    BOOL ok = [parser parse];
    NSAssert(ok, @"Unable to parse %@: %@", file, parser.parserError);
    map.tileMapBox = WhaleyTileMapCreate((int)map.mapSize.width, (int)map.mapSize.height, map.tileSize.width, map.tileSize.height);
    map.compatLayers = [NSMutableDictionary dictionary];
    for (NSDictionary *entry in delegate.decodedLayers) {
        NSString *name = entry[@"name"];
        NSData *data = entry[@"gids"];
        WhaleyTileMapSetLayer(map.tileMapBox, name.UTF8String, data.bytes, data.length / sizeof(uint32_t));
        CCTMXLayer *layer = [CCTMXLayer new];
        layer.layerName = name;
        layer.tileMapBox = map.tileMapBox;
        layer.compatTileSize = map.tileSize;
        [map addChild:layer];
        map.compatLayers[name] = layer;
        [layer release];
    }
    map.compatGroups = [NSMutableDictionary dictionary];
    [delegate.groups enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSMutableArray *objects, BOOL *stop) {
        CCTMXObjectGroup *group = [CCTMXObjectGroup new];
        group.objects = objects;
        map.compatGroups[name] = group;
        [group release];
    }];
    map.compatGIDProperties = delegate.gidProperties;
    [CCCompatTrace record:@"CCTMXTiledMap.load" detail:[NSString stringWithFormat:@"%@ %gx%g", file, map.mapSize.width, map.mapSize.height]];
    [parser release];
    [delegate release];
    return [map autorelease];
}
- (void)dealloc {
    if (_tileMapBox) {
        WhaleyReleaseTileMap(_tileMapBox);
    }
    [_compatLayers release];
    [_compatGroups release];
    [_compatGIDProperties release];
    [super dealloc];
}
- (CCTMXLayer *)layerNamed:(NSString *)name {
    return self.compatLayers[name];
}
- (CCTMXObjectGroup *)objectGroupNamed:(NSString *)name {
    return self.compatGroups[name];
}
- (NSDictionary *)propertiesForGID:(NSInteger)gid {
    return self.compatGIDProperties[@(gid)];
}
@end
@implementation CCDirector {
    CGSize _compatWinSize;
    CGSize _compatViewSize;
}
+ (instancetype)sharedDirector {
    static CCDirector *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [self new];
        d->_compatWinSize = CGSizeMake(320, 568);
    });
    return d;
}
- (CGSize)winSize {
    return _compatWinSize;
}
- (void)setCompatWinSize:(CGSize)size {
    _compatWinSize = size;
}
- (void)setCompatViewSize:(CGSize)size {
    _compatViewSize = size;
}
- (CGSize)compatViewSize {
    return _compatViewSize;
}
@end

@implementation CCLayerColor
+ (instancetype)layerWithColor:(ccColor4B)c width:(CGFloat)w height:(CGFloat)h {
    CCLayerColor *l = [[[self alloc] init] autorelease];
    l.contentSize = CGSizeMake(w, h);
    return l;
}
@end
@implementation CCTouchDispatcher {
    id _targetedDelegate;
    BOOL _swallowsTouches;
}
- (void)addTargetedDelegate:(id)delegate priority:(NSInteger)priority swallowsTouches:(BOOL)swallowsTouches {
    _targetedDelegate = delegate;
    _swallowsTouches = swallowsTouches;
    [CCCompatTrace record:@"touch.delegate" detail:NSStringFromClass([delegate class])];
}
- (BOOL)dispatchTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    if ([_targetedDelegate respondsToSelector:@selector(ccTouchBegan:withEvent:)]) {
        return ((BOOL (*)(id, SEL, UITouch *, UIEvent *))objc_msgSend)(_targetedDelegate, @selector(ccTouchBegan:withEvent:), touch, event);
    }
    return NO;
}
- (void)dispatchTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
    if ([_targetedDelegate respondsToSelector:@selector(ccTouchMoved:withEvent:)]) {
        ((void (*)(id, SEL, UITouch *, UIEvent *))objc_msgSend)(_targetedDelegate, @selector(ccTouchMoved:withEvent:), touch, event);
    }
}
- (void)dispatchTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    if ([_targetedDelegate respondsToSelector:@selector(ccTouchEnded:withEvent:)]) {
        ((void (*)(id, SEL, UITouch *, UIEvent *))objc_msgSend)(_targetedDelegate, @selector(ccTouchEnded:withEvent:), touch, event);
    }
}
- (void)dispatchTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event {
    if ([_targetedDelegate respondsToSelector:@selector(ccTouchCancelled:withEvent:)]) {
        ((void (*)(id, SEL, UITouch *, UIEvent *))objc_msgSend)(_targetedDelegate, @selector(ccTouchCancelled:withEvent:), touch, event);
    } else {
        [self dispatchTouchEnded:touch withEvent:event];
    }
}
@end
#endif
