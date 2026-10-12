//
//  Created by Francis Lazenka on 8/2/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Constants.h"

const NSInteger NormYspd = 2;
const NSInteger SlowYspd = 1;
const NSInteger FastYspd = 3;

const NSInteger NormXspd = 3;
const NSInteger SlowXspd = 2;
const NSInteger FastXspd = 4;

const NSInteger NumLevels = 6;
const NSInteger MaxNumLevels = 101;

const NSInteger HighlightOverlayTag = 3334;

const ccColor3B Green = {178, 178, 178};
const ccColor3B Red = {255, 44, 56};
const ccColor3B LightGreen = {35, 255, 131};
const ccColor3B Purple = {153, 153, 255};
const ccColor3B Magenta = {211, 24, 149};
const ccColor3B Brown = {228, 124, 72};

NSString *const GameStateFile = @"info";
NSString *const GameName1 = @"Gray Whale";
NSString *const GameName2 = @"Glad Whale";
NSString *const MusicFile1 = @"A.mp3";
NSString *const MusicFile2 = @"B.mp3";

const CGFloat SmallerSize = 44 / 128.0;
const CGFloat SmallSize = 44 / 128.0;
const CGFloat NormalSize = 1.0;
#endif
