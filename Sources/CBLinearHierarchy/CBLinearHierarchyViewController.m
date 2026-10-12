//
//  CBLinearHierarchyViewController.m
//  CBLinearHierarchy
//
//  Created by Chris Benoit on 12/19/2013.
//  Copyright (c) 2013 Autodesk Inc. All rights reserved.
//

#if __has_include(<UIKit/UIKit.h>)

#import "CBLinearHierarchyViewController.h"


@interface CBAdjustableListCell : UICollectionViewListCell
@property (nonatomic, copy, nullable) void (^adjustHandler)(NSInteger direction);
@end

@implementation CBAdjustableListCell
- (void)accessibilityIncrement { if (self.adjustHandler) self.adjustHandler(1); }
- (void)accessibilityDecrement { if (self.adjustHandler) self.adjustHandler(-1); }
- (void)prepareForReuse { [super prepareForReuse]; self.adjustHandler = nil; }
@end

@interface CBLinearHierarchyViewController () <UICollectionViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic) id<CBHierarchyNode> rootNode;
@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic) UICollectionViewDiffableDataSource<NSString *, NSString *> *dataSource;
@property (nonatomic) NSDictionary<NSString *, id<CBHierarchyNode>> *nodesByID;
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *depthByID;
@property (nonatomic) NSDictionary<NSString *, NSString *> *titlesBySection;
@property (nonatomic) NSArray<NSString *> *sectionIDs;
@property (nonatomic) NSDictionary<NSString *, NSArray<NSString *> *> *itemsBySection;
@property (nonatomic, strong, nullable) id<CBHierarchyNode> scrubNode;
@end

@implementation CBLinearHierarchyViewController

- (instancetype)initWithRootNode:(id<CBHierarchyNode>)rootNode {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _rootNode = rootNode;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                              collectionViewLayout:[self makeLayout]];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.systemBackgroundColor;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.view addSubview:self.collectionView];
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self configureDataSource];

    UIPanGestureRecognizer *scrub =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleScrub:)];
    scrub.delegate = self;
    scrub.maximumNumberOfTouches = 1;
    [self.collectionView addGestureRecognizer:scrub];

    [self refresh];
    [self applySnapshotAnimated:NO];
}

- (UICollectionViewLayout *)makeLayout {
    UICollectionLayoutListConfiguration *configuration =
        [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearancePlain];
    configuration.showsSeparators = YES;
    configuration.headerMode = UICollectionLayoutListHeaderModeSupplementary;
    return [UICollectionViewCompositionalLayout layoutWithListConfiguration:configuration];
}

- (void)configureDataSource {
    UICollectionViewCellRegistration *registration =
        [UICollectionViewCellRegistration registrationWithCellClass:CBAdjustableListCell.class
        configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *indexPath, NSString *identifier) {
            id<CBHierarchyNode> node = self.nodesByID[identifier];
            NSInteger depth = [self.depthByID[identifier] integerValue];
            UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
            content.text = node.title;
            if (node.markerText.length > 0) {
                content.secondaryText = [NSString stringWithFormat:@"%@   [%@]",
                                         node.subtitle ?: @"",
                                         node.markerText];
                content.secondaryTextProperties.color = UIColor.systemIndigoColor;
                content.secondaryTextProperties.font =
                    [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
            } else {
                content.secondaryText = node.subtitle;
                content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
            }
            content.directionalLayoutMargins =
                NSDirectionalEdgeInsetsMake(5, 12 + (depth * 20), 5, 12);
            cell.contentConfiguration = content;
            CBAdjustableListCell *adjustableCell = (CBAdjustableListCell *)cell;
            if (node.isAdjustable) {
                adjustableCell.accessibilityTraits |= UIAccessibilityTraitAdjustable;
                adjustableCell.accessibilityLabel = node.title;
                adjustableCell.accessibilityValue = node.accessibilityFilterValue ?: node.subtitle;
                adjustableCell.accessibilityHint = @"Swipe up or down to adjust this filter";
                __weak typeof(self) weakSelf = self;
                adjustableCell.adjustHandler = ^(NSInteger direction) {
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self) return;
                    [self.delegate linearHierarchyViewController:self didAdjustNode:node direction:direction];
                };
            } else {
                adjustableCell.accessibilityTraits &= ~UIAccessibilityTraitAdjustable;
                adjustableCell.adjustHandler = nil;
                adjustableCell.accessibilityHint = nil;
                adjustableCell.accessibilityValue = node.subtitle;
                adjustableCell.accessibilityLabel = node.title;
            }
            UIBackgroundConfiguration *background = [UIBackgroundConfiguration listPlainCellConfiguration];
            background.backgroundColor = node.children.count == 0
                ? UIColor.secondarySystemBackgroundColor : UIColor.clearColor;
            cell.backgroundConfiguration = background;
        }];

    self.dataSource =
        [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView
        cellProvider:^UICollectionViewCell *(UICollectionView *collectionView, NSIndexPath *indexPath, NSString *identifier) {
            return [collectionView dequeueConfiguredReusableCellWithRegistration:registration
                                                                     forIndexPath:indexPath
                                                                             item:identifier];
        }];

    UICollectionViewSupplementaryRegistration *headerRegistration =
        [UICollectionViewSupplementaryRegistration
         registrationWithSupplementaryClass:UICollectionViewListCell.class
         elementKind:UICollectionElementKindSectionHeader
         configurationHandler:^(UICollectionViewListCell *header, NSString *kind, NSIndexPath *indexPath) {
            NSString *sectionID = self.sectionIDs[indexPath.section];
            UIListContentConfiguration *content = [UIListContentConfiguration groupedHeaderConfiguration];
            content.text = self.titlesBySection[sectionID] ?: sectionID;
            header.contentConfiguration = content;
            UIBackgroundConfiguration *background = [UIBackgroundConfiguration listPlainHeaderFooterConfiguration];
            background.backgroundColor = UIColor.systemBackgroundColor;
            header.backgroundConfiguration = background;
        }];

    self.dataSource.supplementaryViewProvider =
        ^UICollectionReusableView *(UICollectionView *collectionView, NSString *kind, NSIndexPath *indexPath) {
            return [collectionView dequeueConfiguredReusableSupplementaryViewWithRegistration:headerRegistration
                                                                                  forIndexPath:indexPath];
        };
}

- (void)setRootNode:(id<CBHierarchyNode>)rootNode animated:(BOOL)animated {
    _rootNode = rootNode;
    [self refresh];
    if (self.isViewLoaded) [self applySnapshotAnimated:animated];
}

- (void)refresh {
    NSMutableDictionary *nodes = [NSMutableDictionary dictionary];
    NSMutableDictionary *depths = [NSMutableDictionary dictionary];
    NSMutableDictionary *titles = [NSMutableDictionary dictionary];
    NSMutableDictionary *items = [NSMutableDictionary dictionary];
    NSMutableArray *sections = [NSMutableArray array];

    id<CBHierarchyNode> collection = nil;
    for (id<CBHierarchyNode> child in self.rootNode.children) {
        if ([child.title isEqualToString:@"items"]) { collection = child; break; }
        if (!collection && [child.title isEqualToString:@"features"]) { collection = child; }
    }

    if (collection) {
        for (id<CBHierarchyNode> feature in collection.children) {
            NSString *sectionID = feature.identifier;
            [sections addObject:sectionID];
            titles[sectionID] = feature.sectionTitle ?: feature.title;
            NSMutableArray *sectionItems = [NSMutableArray array];
            [self appendChildrenOfNode:feature depth:0 items:sectionItems nodeMap:nodes depthMap:depths];
            items[sectionID] = sectionItems;
        }
    } else {
        NSString *sectionID = self.rootNode.identifier;
        [sections addObject:sectionID];
        titles[sectionID] = self.rootNode.title;
        NSMutableArray *sectionItems = [NSMutableArray array];
        [self appendChildrenOfNode:self.rootNode depth:0 items:sectionItems nodeMap:nodes depthMap:depths];
        items[sectionID] = sectionItems;
    }

    self.nodesByID = nodes;
    self.depthByID = depths;
    self.titlesBySection = titles;
    self.sectionIDs = sections;
    self.itemsBySection = items;
}

- (void)appendChildrenOfNode:(id<CBHierarchyNode>)node
                       depth:(NSInteger)depth
                       items:(NSMutableArray<NSString *> *)items
                     nodeMap:(NSMutableDictionary *)nodeMap
                    depthMap:(NSMutableDictionary *)depthMap {
    for (id<CBHierarchyNode> child in node.children) {
        [items addObject:child.identifier];
        nodeMap[child.identifier] = child;
        depthMap[child.identifier] = @(depth);
        [self appendChildrenOfNode:child depth:depth + 1 items:items nodeMap:nodeMap depthMap:depthMap];
    }
}

- (void)applySnapshotAnimated:(BOOL)animated {
    NSDiffableDataSourceSnapshot<NSString *, NSString *> *snapshot = [NSDiffableDataSourceSnapshot new];
    [snapshot appendSectionsWithIdentifiers:self.sectionIDs];
    for (NSString *sectionID in self.sectionIDs) {
        [snapshot appendItemsWithIdentifiers:self.itemsBySection[sectionID] ?: @[]
                       intoSectionWithIdentifier:sectionID];
    }
    [self.dataSource applySnapshot:snapshot animatingDifferences:animated];
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gesture {
    CGPoint velocity = [gesture velocityInView:self.collectionView];
    if (fabs(velocity.x) <= fabs(velocity.y)) return NO;

    CGPoint location = [gesture locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
    if (!indexPath) return NO;
    NSString *identifier = [self.dataSource itemIdentifierForIndexPath:indexPath];
    id<CBHierarchyNode> node = self.nodesByID[identifier];
    return node != nil && node.children.count == 0;
}

- (void)handleScrub:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [gesture locationInView:self.collectionView];
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
        if (!indexPath) return;
        NSString *identifier = [self.dataSource itemIdentifierForIndexPath:indexPath];
        self.scrubNode = self.nodesByID[identifier];
    }

    id<CBHierarchyNode> node = self.scrubNode;
    if (!node) return;

    CGFloat translationX = [gesture translationInView:self.collectionView].x;
    [self.delegate linearHierarchyViewController:self
                                    didScrubNode:node
                                   translationX:translationX
                                     touchPoint:[gesture locationInView:nil]
                                          state:gesture.state];

    if (gesture.state == UIGestureRecognizerStateEnded ||
        gesture.state == UIGestureRecognizerStateCancelled ||
        gesture.state == UIGestureRecognizerStateFailed) {
        self.scrubNode = nil;
    }
}

@end

#endif
