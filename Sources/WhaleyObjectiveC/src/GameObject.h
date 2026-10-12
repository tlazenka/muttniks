//
//  Created by Francis Lazenka on 8/3/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "Constants.h"
#import "cocos2d.h"

@interface GameObject : CCSprite {
}

@property (nonatomic, readonly) CGFloat scaledHeight;

- (CGFloat)scaledHeight;

@property (nonatomic, readonly) CGFloat scaledWidth;

- (CGFloat)scaledWidth;

@end
#endif
