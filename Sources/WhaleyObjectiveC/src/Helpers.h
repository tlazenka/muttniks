//
//  Created by Francis Lazenka on 8/2/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "cocos2d.h"

@interface Helpers : NSObject {
}

+ (BOOL)isiPhone5;

+ (CGFloat)getRandomLevelImageAngle;

+ (CGPoint)tileCoordForPosition:(CGPoint)position withTileMap:(CCTMXTiledMap *)tileMap;

+ (BOOL)isYposExactlyOnTile:(CGPoint)position withTileMap:(CCTMXTiledMap *)tileMap;

+ (BOOL)isXposExactlyOnTile:(CGPoint)position withTileMap:(CCTMXTiledMap *)tileMap;

+ (CCSprite *)isAtHelper:(CGPoint)tileCoord
             withTileMap:(CCTMXTiledMap *)tileMap
               withLayer:(CCTMXLayer *)layer
                 withKey:(NSString *)key
               withValue:(NSString *)value;

+ (NSMutableArray *)isAt:(CGPoint)position
             withTileMap:(CCTMXTiledMap *)tileMap
               withLayer:(CCTMXLayer *)layer
                 withKey:(NSString *)key
               withValue:(NSString *)value
                  withDx:(NSInteger)dx
                  withDy:(NSInteger)dy;

+ (CGFloat)clamp:(CGFloat)value clampMin:(CGFloat)min clampMax:(CGFloat)max;

+ (BOOL)rectIntersectsCircle:(CGRect)rect
                   forCircle:(CGRect)circle
            withRadiusOffset:(NSInteger)radiusOffset
         withRectWidthOffset:(NSInteger)rectWidthOffset
        withRectHeightOffset:(NSInteger)rectHeightOffset;

+ (CGFloat)distanceBetweenPoints:(CGPoint)point1 forPoint:(CGPoint)point2;

+ (BOOL)circleIntersectsCircle:(CGRect)circle1
                    forCircle2:(CGRect)circle2
             withRadius1Offset:(NSInteger)radius1Offset
             withRadius2Offset:(NSInteger)radius2Offset
                       inRange:(NSInteger)range;

+ (CGRect)spriteRectangle:(CCNode *)sprite;

+ (CGPoint)spriteCenter:(CCSprite *)sprite;

+ (void)setViewpointCenter:(CGPoint)position
                 withLayer:(CCLayer *)layer
               withTileMap:(CCTMXTiledMap *)tileMap
               withDamping:(BOOL)hasDamping
                   adjustY:(BOOL)withY
               forceCenter:(BOOL)forceCent;

@end
#endif
