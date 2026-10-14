//
//  Created by Francis Lazenka on 10/14/10.
//

#if __has_include(<UIKit/UIKit.h>)
#import <Foundation/Foundation.h>

@interface Score : NSObject <NSCoding> {
}

@property (nonatomic, readwrite) NSInteger bestBubblesUsed;
@property (nonatomic, readwrite) NSInteger bestCollectiblesCaptured;
@property (nonatomic, readwrite) CGFloat bestTime;
@property (nonatomic, readwrite) NSInteger highScore;

@end
#endif
