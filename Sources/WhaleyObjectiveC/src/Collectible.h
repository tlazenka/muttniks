//
//  Created by Francis Lazenka on 8/11/10.
//

#if __has_include(<UIKit/UIKit.h>)

#import "GameObject.h"

@interface Collectible : GameObject {
}

@property (nonatomic, retain) CCAction *shineAction;

+ (Collectible *)initWithFile:(NSString *)file;

@end
#endif
