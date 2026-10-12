//
//  CBLinearHierarchyViewController.h
//  CBLinearHierarchy
//
//  Created by Chris Benoit on 12/19/2013.
//  Copyright (c) 2013 Autodesk Inc. All rights reserved.
//

#if __has_include(<UIKit/UIKit.h>)

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CBHierarchyNode <NSObject>
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *subtitle;
@property (nonatomic, readonly) NSString *jsonPath;
@property (nonatomic, readonly, nullable) NSString *sectionTitle;
@property (nonatomic, readonly, nullable) NSString *markerText;
@property (nonatomic, readonly) BOOL isAdjustable;
@property (nonatomic, readonly, nullable) NSString *accessibilityFilterValue;
@property (nonatomic, readonly) NSArray<id<CBHierarchyNode>> *children;
@end

@class CBLinearHierarchyViewController;

@protocol CBLinearHierarchyViewControllerDelegate <NSObject>
- (void)linearHierarchyViewController:(CBLinearHierarchyViewController *)viewController
                       didSelectNode:(id<CBHierarchyNode>)node;
- (void)linearHierarchyViewController:(CBLinearHierarchyViewController *)viewController
                  didScrubNode:(id<CBHierarchyNode>)node
                 translationX:(CGFloat)translationX
                    touchPoint:(CGPoint)touchPoint
                        state:(UIGestureRecognizerState)state;
- (void)linearHierarchyViewController:(CBLinearHierarchyViewController *)viewController
                 didAdjustNode:(id<CBHierarchyNode>)node
                     direction:(NSInteger)direction;
@end

@interface CBLinearHierarchyViewController : UIViewController
@property (nonatomic, weak, nullable) id<CBLinearHierarchyViewControllerDelegate> delegate;
- (instancetype)initWithRootNode:(id<CBHierarchyNode>)rootNode NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)setRootNode:(id<CBHierarchyNode>)rootNode animated:(BOOL)animated;
@end

NS_ASSUME_NONNULL_END

#endif
