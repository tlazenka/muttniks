//
//  Created by Francis Lazenka on 9/6/10.
//

#import "GameState.h"

#if __has_include(<UIKit/UIKit.h>)

@implementation GameState

@synthesize levelsAchieved = _levelsAchieved;
@synthesize levels = _levels;
@synthesize hasExtraBounce = _hasExtraBounce;
@synthesize transparentGameTitleCharacters = _transparentGameTitleCharacters;
@synthesize transparentCredits = _transparentCredits;

static GameState *_gameState = nil;

+ (GameState *)gameState {
    @synchronized([GameState class]) {
        if (!(_gameState)) {
            [GameState loadGameStateFromFile];
        }

        return _gameState;
    }

    return nil;
}

+ (id)alloc {
    @synchronized([GameState class]) {
        NSAssert(_gameState == nil, @"Attempted to allocate a second instance of a singleton.");
        _gameState = [[super alloc] retain];
        return _gameState;
    }

    return nil;
}

- (id)init {
    self = [super init];
    if (self != nil) {
        self.levels = [NSMutableArray arrayWithCapacity:NumLevels];
        self.transparentGameTitleCharacters = [NSMutableArray arrayWithCapacity:[GameName1 length]];
        for (NSInteger i = 0; i < [GameName1 length]; i++) {
            [self.transparentGameTitleCharacters addObject:[NSNull null]];
        }
        //[self.transparentGameTitleCharacters insertObject:[NSNumber numberWithInt:1] atIndex:6];
    }

    return self;
}

+ (void)saveGameStateToFile {
    NSString *savePath = [self makeSavePath];
    [NSKeyedArchiver archiveRootObject:_gameState toFile:savePath];
}

+ (void)loadGameStateFromFile {
    @synchronized([GameState class]) {
        NSString *savePath = [self makeSavePath];
        [_gameState release];
        _gameState = [[NSKeyedUnarchiver unarchiveObjectWithFile:savePath] retain];
        if (_gameState == nil) {
            [_gameState release];
            _gameState = [[GameState new] retain];
            _gameState.levelsAchieved = 1;
            _gameState.hasExtraBounce = YES;
            _gameState.transparentCredits = NO;
            for (NSInteger i = 0; i < MaxNumLevels; i++) {
                Level *level = [Level levelWithNum:i + 1 withGameMode:NormalBubble];
                level.levelImageRotation = [Helpers getRandomLevelImageAngle];
                [_gameState.levels insertObject:level atIndex:i];
            }
        }
    }
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    // denotes an object that cannot be released
    return UINT_MAX;
}

- (oneway void)release {
    // never release
}

- (id)autorelease {
    return self;
}

+ (NSString *)makeSavePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *savePath = [documentsDirectory stringByAppendingPathComponent:GameStateFile];
    return savePath;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:self.levelsAchieved forKey:@"levelsAchieved"];
    [coder encodeBool:self.hasExtraBounce forKey:@"hasExtraBounce"];
    [coder encodeObject:self.levels forKey:@"levels"];
    [coder encodeObject:self.transparentGameTitleCharacters forKey:@"transparentGameTitleCharacters"];
    [coder encodeBool:self.transparentCredits forKey:@"transparentCredits"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    self.levelsAchieved = [coder decodeIntForKey:@"levelsAchieved"];
    self.hasExtraBounce = [coder decodeBoolForKey:@"hasExtraBounce"];
    self.levels = (NSMutableArray *)[coder decodeObjectForKey:@"levels"];
    self.transparentGameTitleCharacters = (NSMutableArray *)[coder decodeObjectForKey:@"transparentGameTitleCharacters"];
    self.transparentCredits = [coder decodeBoolForKey:@"transparentCredits"];
    return self;
}

- (void)dealloc {
    [_gameState release];
    self.levels = nil;
    self.transparentGameTitleCharacters = nil;
    [super dealloc];
}

@end
#endif
