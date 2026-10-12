//
//  Created by Francis Lazenka on 7/31/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "GameObject.h"
#import "GameState.h"

@interface Projectile : GameObject {
    CGFloat _sizeMode;
}

@property (nonatomic, readwrite) BOOL isFrozen;
@property (nonatomic, readwrite) CGFloat sizeMode;
@property (nonatomic, readwrite) BOOL isBeingMoved;
@property (nonatomic, readwrite) NSInteger bouncesLeft;
@property (nonatomic, readwrite) CGPoint relativeOffset;

- (CGFloat)sizeMode;
- (void)setSizeMode:(CGFloat)newValue;

+ (Projectile *)initDefaults;

+ (Projectile *)initWithFile:(NSString *)file
                withIsFrozen:(BOOL)f
                withSizeMode:(CGFloat)s
            withIsBeingMoved:(BOOL)m
             withBouncesLeft:(NSInteger)b;

+ (void)projectileCollides:(CCSprite *)projectile1
            withProjectile:(CCSprite *)projectile2
                withOffset:(NSInteger)diff
               withTileMap:(CCTMXTiledMap *)tileMap;

@end
#endif
