//
//  Created by Francis Lazenka on 8/23/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Helpers.h"
#import "Score.h"
#import "cocos2d.h"

@interface Level : NSObject <NSCoding> {
}

extern NSInteger const NormalBubble;
extern NSInteger const ExtraBounce;
extern NSInteger const InfiniteBubble;

@property (nonatomic, readwrite) NSInteger num;
@property (nonatomic, readwrite) NSInteger checkpointIndex;
@property (nonatomic, readwrite) NSInteger bubblesUsed;
@property (nonatomic, readwrite) CGFloat totalTime;
@property (nonatomic, readwrite) NSInteger totalCollectibles;
@property (nonatomic, readwrite) CGFloat levelImageRotation;
@property (nonatomic, retain) NSMutableArray *collectiblesCaptured;
@property (nonatomic, readwrite) NSInteger gameMode;
@property (nonatomic, retain) NSMutableDictionary *scores;

+ (id)levelWithNum:(NSInteger)num withGameMode:(NSInteger)gameMode;

- (NSString *)name;

@end
#endif
