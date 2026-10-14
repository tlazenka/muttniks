//
//  Created by Francis Lazenka on 8/23/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Level.h"

@implementation Level

@synthesize num = _num;
@synthesize checkpointIndex = _checkpointIndex;
@synthesize bubblesUsed = _bubblesUsed;
@synthesize collectiblesCaptured = _collectiblesCaptured;
@synthesize levelImageRotation = _levelImageRotation;
@synthesize totalCollectibles = _totalCollectibles;
@synthesize totalTime = _totalTime;
@synthesize gameMode = _gameMode;
@synthesize scores = _scores;

const NSInteger NormalBubble = 0;
const NSInteger ExtraBounce = 1;
const NSInteger InfiniteBubble = 2;

static NSMutableDictionary *_names = nil;

+ (id)levelWithNum:(NSInteger)num withGameMode:(NSInteger)gameMode {
    Level *result = [[self alloc] autorelease];
    result.num = num;
    result.collectiblesCaptured = [NSMutableArray array];
    result.bubblesUsed = 0;
    result.checkpointIndex = -1;
    result.totalTime = 0;
    result.totalCollectibles = 0;
    result.levelImageRotation = [Helpers getRandomLevelImageAngle];
    result.gameMode = gameMode;
    result.scores = [[NSMutableDictionary new] autorelease];
    for (NSInteger i = 0; i < 3; i++) {
        Score *newScore = [Score new];
        [result.scores setObject:newScore forKey:[NSString stringWithFormat:@"%d", i]];
        [newScore release];
    }
    return result;
}

- (NSString *)name {
    if (!(_names)) {
        _names = [NSMutableDictionary new];
        [_names setObject:@"DRYDOCK AT LIVERPOOL" forKey:@"1"];
        [_names setObject:@"LIFE LINE" forKey:@"2"];
        [_names setObject:@"HMS CALCUTTA" forKey:@"3"];
        [_names setObject:@"LAS MENINAS" forKey:@"4"];
        [_names setObject:@"LA BELLE DAME" forKey:@"5"];
        [_names setObject:@"PEARL EARRING" forKey:@"6"];
    }
    return [_names objectForKey:[[NSNumber numberWithInt:self.num] stringValue]];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:self.num forKey:@"num"];
    [coder encodeObject:self.collectiblesCaptured forKey:@"collectiblesCaptured"];
    [coder encodeInt:self.checkpointIndex forKey:@"checkpointIndex"];
    [coder encodeInt:self.bubblesUsed forKey:@"bubblesUsed"];
    [coder encodeFloat:self.totalTime forKey:@"totalTime"];
    [coder encodeFloat:self.levelImageRotation forKey:@"levelImageRotation"];
    [coder encodeInt:self.totalCollectibles forKey:@"totalCollectibles"];
    [coder encodeInt:self.gameMode forKey:@"gameMode"];
    [coder encodeObject:self.scores forKey:@"scores"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    self.num = [coder decodeIntForKey:@"num"];
    self.collectiblesCaptured = (NSMutableArray *)[coder decodeObjectForKey:@"collectiblesCaptured"];
    self.checkpointIndex = [coder decodeIntForKey:@"checkpointIndex"];
    self.bubblesUsed = [coder decodeIntForKey:@"bubblesUsed"];
    self.totalTime = [coder decodeFloatForKey:@"totalTime"];
    self.levelImageRotation = [coder decodeFloatForKey:@"levelImageRotation"];
    self.totalCollectibles = [coder decodeIntForKey:@"totalCollectibles"];
    self.gameMode = [coder decodeIntForKey:@"gameMode"];
    self.scores = (NSMutableDictionary *)[coder decodeObjectForKey:@"scores"];
    return self;
}

- (void)dealloc {
    self.collectiblesCaptured = nil;
    self.scores = nil;
    [_names release];
    [super dealloc];
}

@end
#endif
