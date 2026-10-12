//
//  Created by Francis Lazenka on 8/2/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Helpers.h"

@implementation Helpers

// see http://stackoverflow.com/questions/12535471/detect-iphone-5-4-screen/12535566#12535566
+ (BOOL)isiPhone5 {
    return [[UIScreen mainScreen] bounds].size.height >= 568;
}

+ (CGFloat)getRandomLevelImageAngle {
    CGFloat angle = 0;
    if ((random() % 2) == 1) {
        angle = ((random() % 3) + 1);
        if ((random() % 2) == 1) {
            angle *= -1;
        }
    }
    return angle;
}

+ (CGPoint)tileCoordForPosition:(CGPoint)position withTileMap:(CCTMXTiledMap *)tileMap {
    NSInteger x = position.x / tileMap.tileSize.width;
    NSInteger y = ((tileMap.mapSize.height * tileMap.tileSize.height) - position.y - 1) / tileMap.tileSize.height;
    return ccp(x, y);
}

+ (BOOL)isYposExactlyOnTile:(CGPoint)position withTileMap:(CCTMXTiledMap *)tileMap {
    return (((NSInteger)position.y) % ((NSInteger)tileMap.tileSize.height)) == 0;
}

+ (BOOL)isXposExactlyOnTile:(CGPoint)position withTileMap:(CCTMXTiledMap *)tileMap {
    return (((NSInteger)position.x) % ((NSInteger)tileMap.tileSize.width)) == 0;
}

+ (CCSprite *)isAtHelper:(CGPoint)tileCoord
             withTileMap:(CCTMXTiledMap *)tileMap
               withLayer:(CCTMXLayer *)layer
                 withKey:(NSString *)key
               withValue:(NSString *)value {
    NSInteger tileGid = [layer tileGIDAt:tileCoord];
    if (tileGid) {
        NSDictionary *properties = [tileMap propertiesForGID:tileGid];
        if (properties) {
            NSString *collision = [properties valueForKey:key];
            if ((collision) && ([collision compare:value] == NSOrderedSame)) {
                return [layer tileAt:tileCoord];
            }
        }
    }
    return nil;
}

+ (NSMutableArray *)isAt:(CGPoint)position
             withTileMap:(CCTMXTiledMap *)tileMap
               withLayer:(CCTMXLayer *)layer
                 withKey:(NSString *)key
               withValue:(NSString *)value
                  withDx:(NSInteger)dx
                  withDy:(NSInteger)dy {
    CGPoint tempPosition = ccp(position.x + dx, position.y + dy);

    NSMutableArray *result = [[NSMutableArray new] autorelease];

    CGPoint tileCoord = [Helpers tileCoordForPosition:tempPosition withTileMap:tileMap];
    CCSprite *tempResult = [Helpers isAtHelper:tileCoord
                                   withTileMap:tileMap
                                     withLayer:layer
                                       withKey:key
                                     withValue:value];
    if (tempResult) {
        [result addObject:tempResult];
    }

    tileCoord = [Helpers tileCoordForPosition:tempPosition withTileMap:tileMap];
    if ((!([Helpers isXposExactlyOnTile:tempPosition withTileMap:tileMap]))
        && (tileCoord.x < (tileMap.mapSize.width - 1))) {
        tileCoord.x++;
    }
    tempResult = [Helpers isAtHelper:tileCoord
                         withTileMap:tileMap
                           withLayer:layer
                             withKey:key
                           withValue:value];
    if (tempResult) {
        [result addObject:tempResult];
    }

    tileCoord = [Helpers tileCoordForPosition:tempPosition withTileMap:tileMap];
    if ((!([Helpers isYposExactlyOnTile:tempPosition withTileMap:tileMap]))
        && (tileCoord.y > 0)) {
        tileCoord.y--;
    }
    tempResult = [Helpers isAtHelper:tileCoord
                         withTileMap:tileMap
                           withLayer:layer
                             withKey:key
                           withValue:value];
    if (tempResult) {
        [result addObject:tempResult];
    }

    tileCoord = [Helpers tileCoordForPosition:tempPosition withTileMap:tileMap];
    if ((!([Helpers isXposExactlyOnTile:tempPosition withTileMap:tileMap]))
        && (tileCoord.x < (tileMap.mapSize.width - 1))) {
        tileCoord.x++;
    }
    if ((!([Helpers isYposExactlyOnTile:tempPosition withTileMap:tileMap]))
        && (tileCoord.y > 0)) {
        tileCoord.y--;
    }
    tempResult = [Helpers isAtHelper:tileCoord
                         withTileMap:tileMap
                           withLayer:layer
                             withKey:key
                           withValue:value];
    if (tempResult) {
        [result addObject:tempResult];
    }

    return result;
}

+ (CGFloat)clamp:(CGFloat)value clampMin:(CGFloat)min clampMax:(CGFloat)max {
    CGFloat result = value;
    if (value > max) {
        result = max;
    }
    if (value < min) {
        result = min;
    }
    return result;
}

// http://stackoverflow.com/questions/401847/circle-rectangle-collision-detection-intersection
+ (BOOL)rectIntersectsCircle:(CGRect)rect
                   forCircle:(CGRect)circle
            withRadiusOffset:(NSInteger)radiusOffset
         withRectWidthOffset:(NSInteger)rectWidthOffset
        withRectHeightOffset:(NSInteger)rectHeightOffset {
    CGFloat radius = (circle.size.width / 2.0f) + radiusOffset;

    CGFloat circleMiddleX = circle.origin.x;
    CGFloat circleMiddleY = circle.origin.y;

    // Find the closest point to the circle within the rectangle
    CGFloat closestX = [Helpers
           clamp:circleMiddleX
        clampMin:(rect.origin.x - rectWidthOffset)
        clampMax:(rect.origin.x + rect.size.width + rectWidthOffset - 1)];
    CGFloat closestY = [Helpers
           clamp:circleMiddleY
        clampMin:(rect.origin.y - rectHeightOffset)
        clampMax:(rect.origin.y + rect.size.height + rectHeightOffset - 1)];

    // Calculate the distance between the circle's center and this closest point
    CGFloat distanceX = circleMiddleX - closestX;
    CGFloat distanceY = circleMiddleY - closestY;

    // If the distance is less than the circle's radius, an intersection occurs
    CGFloat distanceSquared = (distanceX * distanceX) + (distanceY * distanceY);
    return distanceSquared < (radius * radius);
}

+ (CGFloat)distanceBetweenPoints:(CGPoint)point1 forPoint:(CGPoint)point2 {
    CGFloat dx = point2.x - point1.x;
    CGFloat dy = point2.y - point1.y;
    return sqrt((dx * dx) + (dy * dy));
};

+ (BOOL)circleIntersectsCircle:(CGRect)circle1
                    forCircle2:(CGRect)circle2
             withRadius1Offset:(NSInteger)radius1Offset
             withRadius2Offset:(NSInteger)radius2Offset
                       inRange:(NSInteger)range {
    CGFloat radius1 = (circle1.size.width / 2.0f) + radius1Offset;
    CGFloat radius2 = (circle2.size.width / 2.0f) + radius2Offset;

    CGPoint middle1 = ccp(circle1.origin.x, circle1.origin.y);
    CGPoint middle2 = ccp(circle2.origin.x, circle2.origin.y);

    return ([Helpers distanceBetweenPoints:middle1 forPoint:middle2] < (radius1 + radius2 - range));
}

+ (CGRect)spriteRectangle:(CCNode *)sprite {
    return CGRectMake(sprite.position.x,
                      sprite.position.y,
                      (sprite.contentSize.width * sprite.scaleX),
                      (sprite.contentSize.height * sprite.scaleY));
}

+ (CGPoint)spriteCenter:(CCSprite *)sprite {
    return ccp(sprite.position.x + ((sprite.contentSize.width * sprite.scaleX) / 2),
               sprite.position.y + ((sprite.contentSize.height * sprite.scaleY) / 2));
}

// http://www.raywenderlich.com/1163/how-to-make-a-tile-based-game-with-cocos2d
+ (void)setViewpointCenter:(CGPoint)position
                 withLayer:(CCLayer *)layer
               withTileMap:(CCTMXTiledMap *)tileMap
               withDamping:(BOOL)hasDamping
                   adjustY:(BOOL)withY
               forceCenter:(BOOL)forceCent {
    CGSize winSize = [[CCDirector sharedDirector] winSize];

    if ((!(forceCent))
        && (winSize.width >= (tileMap.mapSize.width * tileMap.tileSize.width))
        && (winSize.height >= (tileMap.mapSize.height * tileMap.tileSize.height))) {
        layer.position = ccp((winSize.width - (tileMap.mapSize.width * tileMap.tileSize.width)) / 2,
                             (winSize.height - (tileMap.mapSize.height * tileMap.tileSize.height)) / 2);
    } else {
        NSInteger x = MAX(position.x, winSize.width / 2);
        NSInteger y = MAX(position.y, winSize.height / 2);
        x = MIN(x, (tileMap.mapSize.width * tileMap.tileSize.width) - (winSize.width / 2));
        if (withY) {
            y = MIN(y, (tileMap.mapSize.height * tileMap.tileSize.height) - (winSize.height / 2));
        }
        CGPoint actualPosition = ccp(x, y);

        CGPoint centerOfView = ccp(winSize.width / 2, winSize.height / 2);
        CGPoint viewPoint = ccpSub(centerOfView, actualPosition);

        if (hasDamping) {
            CGFloat damping = 0.1f;
            layer.position = ccpAdd(layer.position, ccpMult(ccpSub(viewPoint, layer.position), damping));
        } else {
            layer.position = viewPoint;
        }
    }
}

@end
#endif
