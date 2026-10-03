#if __has_include(<UIKit/UIKit.h>)

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CBHierarchyNodeProvider <NSObject>
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *subtitle;
@property (nonatomic, readonly) NSString *jsonPath;
@property (nonatomic, readonly, nullable) NSString *sectionTitle;
@property (nonatomic, readonly) NSArray<id<CBHierarchyNodeProvider>> *children;
@property (nonatomic, readonly, nullable) NSString *markerText;
@end

@class _CBLinearHierarchyViewController;

@protocol CBLinearHierarchyViewControllerDelegate <NSObject>
- (void)linearHierarchyViewController:(_CBLinearHierarchyViewController *)viewController
                       didSelectNode:(id<CBHierarchyNodeProvider>)node;
- (void)linearHierarchyViewController:(_CBLinearHierarchyViewController *)viewController
                  didScrubNode:(id<CBHierarchyNodeProvider>)node
                 translationX:(CGFloat)translationX
                        state:(UIGestureRecognizerState)state;
@end

@interface _CBLinearHierarchyViewController : UIViewController
@property (nonatomic, weak, nullable) id<CBLinearHierarchyViewControllerDelegate> delegate;
- (instancetype)initWithRootNode:(id<CBHierarchyNodeProvider>)rootNode NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)setRootNode:(id<CBHierarchyNodeProvider>)rootNode animated:(BOOL)animated;
@end

NS_ASSUME_NONNULL_END

#endif
