//
//  Created by Francis Lazenka on 10/14/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Score.h"

@implementation Score

@synthesize bestBubblesUsed = _bestBubblesUsed;
@synthesize bestCollectiblesCaptured = _bestCollectiblesCaptured;
@synthesize highScore = _highScore;
@synthesize bestTime = _bestTime;

- (id)init {
    if ((self = [super init])) {
        self.bestCollectiblesCaptured = 0;
        self.bestBubblesUsed = INT_MAX;
        self.bestTime = CGFLOAT_MAX;
        self.highScore = 0;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:self.bestCollectiblesCaptured forKey:@"bestCollectiblesCaptured"];
    [coder encodeInt:self.bestBubblesUsed forKey:@"bestBubblesUsed"];
    [coder encodeInt:self.highScore forKey:@"highScore"];
    [coder encodeFloat:self.bestTime forKey:@"bestTime"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    self.bestCollectiblesCaptured = [coder decodeIntForKey:@"bestCollectiblesCaptured"];
    self.bestBubblesUsed = [coder decodeIntForKey:@"bestBubblesUsed"];
    self.highScore = [coder decodeIntForKey:@"highScore"];
    self.bestTime = [coder decodeFloatForKey:@"bestTime"];
    return self;
}

@end
#endif
