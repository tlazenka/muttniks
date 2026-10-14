//
//  Created by Francis Lazenka on 8/4/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "GameObject.h"

@interface Hazard : GameObject {
}

@property (nonatomic, readwrite) NSInteger phase;
@property (nonatomic, readwrite) BOOL isActive;

@end
#endif
