//
//  Created by Francis Lazenka on 8/3/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "GameObject.h"

@implementation GameObject

- (CGFloat)scaledHeight {
    return self.contentSize.height * self.scaleY;
}

- (CGFloat)scaledWidth {
    return self.contentSize.width * self.scaleX;
}

@end
#endif
