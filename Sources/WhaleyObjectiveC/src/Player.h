//
//  Created by Francis Lazenka on 8/2/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "GameObject.h"
#import "GameState.h"

typedef enum air_mode_types {
    GROUNDED,
    JUMPING_UP,
    JUMPING_DOWN,
    FALLING
} AirMode;

@interface Player : GameObject {
}

@property (nonatomic, retain) CCAction *spoutAction;

@property (nonatomic, readwrite) AirMode airMode;
@property (nonatomic, readwrite) BOOL isDead;
@property (nonatomic, readwrite) BOOL hasWon;
@property (nonatomic, readwrite) BOOL isMovingLaterally;
@property (nonatomic, readwrite) NSInteger jumpDiff;
@property (nonatomic, readwrite) NSInteger yAdd;
@property (nonatomic, readwrite) NSInteger xAdd;
@property (nonatomic, readwrite) CGFloat groundYpos;
@property (nonatomic, readwrite) CGPoint desiredPos;
@property (nonatomic, retain) CCAction *moveAction;

+ (Player *)initDefaults:(NSString *)file;

+ (Player *)initWithFile:(NSString *)file
              withAirMode:(BOOL)airmode
    withIsMovingLaterally:(BOOL)movinglaterally
             withJumpDiff:(BOOL)jumpdiff
                 withYadd:(BOOL)yadd
                 withXadd:(BOOL)xadd
           withGroundYpos:(CGFloat)groundypos
           withDesiredPos:(CGPoint)desiredpos;

@end
#endif
