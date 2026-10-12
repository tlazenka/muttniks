//
//  Created by Francis Lazenka on 7/31/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Projectile.h"

@implementation Projectile

@synthesize isFrozen;
@synthesize isBeingMoved;
@synthesize bouncesLeft;
@synthesize relativeOffset = _relativeOffset;

- (CGFloat)sizeMode {
    return _sizeMode;
}

- (void)setSizeMode:(CGFloat)newValue {
    _sizeMode = newValue;
    self.scaleX = newValue;
    self.scaleY = newValue;
}

+ (Projectile *)initDefaults {
    return [Projectile
            initWithFile:([GameState gameState].levelsAchieved > NumLevels) ? (@"infinite_bubble.png") : (@"bubble01.png")
            withIsFrozen:NO
            withSizeMode:SmallSize
        withIsBeingMoved:NO
         withBouncesLeft:2];
}

+ (Projectile *)initWithFile:(NSString *)file
                withIsFrozen:(BOOL)f
                withSizeMode:(CGFloat)s
            withIsBeingMoved:(BOOL)m
             withBouncesLeft:(NSInteger)b {
    Projectile *projectile = [Projectile spriteWithFile:file];

    if (projectile) {
        projectile.isFrozen = f;
        projectile.sizeMode = s;
        projectile.isBeingMoved = m;
        projectile.bouncesLeft = b;
    }

    return projectile;
}

+ (void)projectileCollides:(CCSprite *)projectile1
            withProjectile:(CCSprite *)projectile2
                withOffset:(NSInteger)diff
               withTileMap:(CCTMXTiledMap *)tileMap {
    NSInteger bspd = 1;

    CGFloat tmpbypos = projectile2.position.y;
    CGFloat tmpbxpos = projectile2.position.x;

    CGFloat bypos = projectile1.position.y;
    CGFloat bxpos = projectile1.position.x;

    BOOL boffdown = ((tmpbypos - bypos) <= diff) && ((tmpbypos - bypos) >= 0);
    BOOL boffup = ((bypos - tmpbypos) <= diff) && ((bypos - tmpbypos) >= 0);
    BOOL boffright = ((tmpbxpos - bxpos) <= diff) && ((tmpbxpos - bxpos) >= 0);
    BOOL boffleft = ((bxpos - tmpbxpos) <= diff) && ((bxpos - tmpbxpos) >= 0);
    if ((boffup && (boffright || boffleft))
        || (boffdown && (boffright || boffleft))
        || (boffleft && (boffup || boffdown))
        || (boffright && (boffup || boffdown))) {
        if (boffup) {
            if (bypos < ((tileMap.tileSize.height * tileMap.mapSize.height) - (projectile1.contentSize.height * projectile1.scaleY) - bspd)) {
                projectile1.position = ccp(projectile1.position.x, projectile1.position.y - bspd);
            }
            if (tmpbypos > (1 + bspd)) {
                projectile2.position = ccp(projectile2.position.x, projectile2.position.y + bspd);
            };
        }
        if (boffdown) {
            if (tmpbypos < ((tileMap.tileSize.height * tileMap.mapSize.height) - (projectile2.contentSize.height * projectile2.scaleY) - bspd)) {
                projectile2.position = ccp(projectile2.position.x, projectile2.position.y - bspd);
            }
            if (bypos > (1 + bspd)) {
                projectile1.position = ccp(projectile1.position.x, projectile1.position.y + bspd);
            };
        }
        if (boffleft) {
            if (bxpos < ((tileMap.tileSize.width * tileMap.mapSize.width) - (projectile1.contentSize.width * projectile1.scaleX) - bspd)) {
                projectile1.position = ccp(projectile1.position.x + bspd, projectile1.position.y);
            }
            if (tmpbxpos > (1 + bspd)) {
                projectile2.position = ccp(projectile2.position.x - bspd, projectile2.position.y);
            };
        }
        if (boffright) {
            if (tmpbxpos < ((tileMap.tileSize.width * tileMap.mapSize.width) - (projectile2.contentSize.width * projectile2.scaleX) - bspd)) {
                projectile2.position = ccp(projectile2.position.x + bspd, projectile2.position.y);
            }
            if (bxpos > (1 + bspd)) {
                projectile1.position = ccp(projectile1.position.x - bspd, projectile1.position.y);
            };
        }
    }
}

@end
#endif
