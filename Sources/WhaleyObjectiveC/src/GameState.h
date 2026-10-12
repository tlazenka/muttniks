//
//  Created by Francis Lazenka on 9/6/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Constants.h"
#import "Level.h"
#import "cocos2d.h"

// http://www.cocos2d-iphone.org/forum/topic/737#post-8224

@interface GameState : NSObject {
}

@property (nonatomic, readwrite) NSInteger levelsAchieved;
@property (nonatomic, readwrite) BOOL hasExtraBounce;
@property (nonatomic, readwrite) BOOL transparentCredits;
@property (nonatomic, retain) NSMutableArray *levels;
@property (nonatomic, retain) NSMutableArray *transparentGameTitleCharacters;

+ (GameState *)gameState;
+ (void)loadGameStateFromFile;
+ (void)saveGameStateToFile;
+ (NSString *)makeSavePath;

@end
#endif
