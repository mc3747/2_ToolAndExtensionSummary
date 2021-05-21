//
//  MNLinkPageController.m
//  MNKit
//
//  Created by Vincent on 2018/12/26.
//  Copyright © 2018年 小斯. All rights reserved.
//

#import "MNLinkPageController.h"
#import "MNLinkSubpageProtocol.h"
#import "MNLinkPageView.h"
#import "UIScrollView+MNLinkHelper.h"

static NSString *MNLinkPageIndexKey = @"com.mn.link.page.index.key";

@interface MNLinkPageController ()<UIScrollViewDelegate>
@property (nonatomic, weak) MNLinkPageView *scrollView;
@property (nonatomic, strong) NSMapTable<NSNumber *, UIViewController*> *pageCache;
@property (nonatomic, assign) NSUInteger currentPageIndex;/**当前page索引*/
@property (nonatomic, assign) NSUInteger lastPageIndex; /**上一次页面索引*/
@property (nonatomic, assign) NSInteger guessToIndex; /**交互滑动时猜想page索引*/
@property (nonatomic, assign) CGFloat originOffsetY; /**交互滑动初始偏移*/
@property (nonatomic, assign) BOOL needDisplayCurrentPage; /**是否需要展示page(首次出现YES)*/
@end

#define kLinkPageAnimatedDuration      .25f

@implementation MNLinkPageController

- (void)initialized {
    [super initialized];
    self.lastPageIndex = 0;
    self.currentPageIndex = 0;
    self.needDisplayCurrentPage = YES;
    self.pageCache = [NSMapTable weakToWeakObjectsMapTable];
}

#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    MNLinkPageView *scrollView = [[MNLinkPageView alloc] initWithFrame:self.view.bounds];
    scrollView.delegate = self;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_needDisplayCurrentPage) {
        [_delegate linkPageController:self
                        willLeavePage:[self pageOfIndex:_lastPageIndex]
                               toPage:[self pageOfIndex:_currentPageIndex]];
    }
    [[self pageOfIndex:_currentPageIndex] beginAppearanceTransition:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_needDisplayCurrentPage) {
        _needDisplayCurrentPage = NO;
        [_delegate linkPageController:self
                         didLeavePage:[self pageOfIndex:_lastPageIndex]
                               toPage:[self pageOfIndex:_currentPageIndex]];
    }
    [[self pageOfIndex:_currentPageIndex] endAppearanceTransition];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self pageOfIndex:_currentPageIndex] beginAppearanceTransition:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[self pageOfIndex:_currentPageIndex] endAppearanceTransition];
}

#pragma mark - 清除缓存
- (void)cleanCache {
    [_scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self cleanPageCache];
}

- (void)cleanPageCache {
    if (_pageCache.count <= 0) return;
    [self.childViewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull page, NSUInteger idx, BOOL * _Nonnull stop) {
        [self removeChildPage:page];
    }];
    [_pageCache removeAllObjects];
}

- (void)removeChildPage:(UIViewController *)controller {
    [controller willMoveToParentViewController:nil];
    [controller.view removeFromSuperview];
    [controller removeFromParentViewController];
    [controller didMoveToParentViewController:nil];
}

#pragma mark - Reload
- (void)reloadData {
    self.scrollEnabled = YES;
    self.needDisplayCurrentPage = YES;
    [self cleanCache];
}

#pragma mark - Update ScrollView Content
- (void)updateContentIfNeed {
    [_scrollView updateContentSizeWithNumberOfPages:[self numberOfPages]];
}

#pragma mark - update page index
- (void)updateCurrentPageIndex:(NSUInteger)pageIndex {
    _currentPageIndex = pageIndex;
}

- (void)reloadLastPageIndex {
    _lastPageIndex = _currentPageIndex;
}

#pragma mark - Display CurrentPage
- (void)displayCurrentPageIfNeed {
    [_scrollView updateOffsetWithIndex:_currentPageIndex];
}

#pragma mark - UIScrollViewDelegate<交互切换界面>
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView.isDecelerating || scrollView != _scrollView) return;
    _originOffsetY = [[scrollView valueForKeyPath:@"_startOffsetY"] floatValue];
    _guessToIndex = _currentPageIndex;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    /**手指离开屏幕就不再处理*/
    if (!scrollView.isDragging || scrollView != _scrollView) return;
    /**根据偏移计算下一页页数*/
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat height = scrollView.frame.size.height;
    NSInteger lastGuestIndex = (_guessToIndex < 0 ? _currentPageIndex:_guessToIndex);
    CGFloat ratio = offsetY/height;
    if (_originOffsetY < offsetY) {
        _guessToIndex = ceil(ratio); /**上滑 最小的整数但不小于本身*/
    } else if (_originOffsetY >= offsetY) {
        _guessToIndex = floor(ratio); /**下滑 最大的整数但不大于本身*/
    }
    NSInteger numberOfPages = [self numberOfPages];
    if (((_guessToIndex != _currentPageIndex && !_scrollView.isDecelerating) || _scrollView.isDecelerating) && lastGuestIndex != _guessToIndex && _guessToIndex >= 0 && _guessToIndex < numberOfPages) {
        
        UIViewController *fromPage = [self pageOfIndex:_currentPageIndex];
        UIViewController *toPage = [self pageOfIndex:_guessToIndex];

        if ([_delegate respondsToSelector:@selector(linkPageController:willLeavePage:toPage:)]) {
            [_delegate linkPageController:self willLeavePage:fromPage toPage:toPage];
        }
        
        /**控制视图生命周期*/
        if (lastGuestIndex == _currentPageIndex) {
            [fromPage beginAppearanceTransition:NO animated:YES];
        }
        [toPage beginAppearanceTransition:YES animated:YES];
        
        if (lastGuestIndex != _currentPageIndex && lastGuestIndex >= 0 && lastGuestIndex < numberOfPages) {
            UIViewController *lastGuestPage = [self pageOfIndex:lastGuestIndex];
            [lastGuestPage beginAppearanceTransition:NO animated:YES];
            [lastGuestPage endAppearanceTransition];
        }
        
        if ([toPage conformsToProtocol:@protocol(MNLinkSubpageDataSource)]) {
            UIViewController<MNLinkSubpageDataSource>*vc = (UIViewController<MNLinkSubpageDataSource> *)toPage;
            if ([vc respondsToSelector:@selector(linkSubpageScrollView)]) {
                UIScrollView *scrollView = vc.linkSubpageScrollView;
                if (toPage.pageIndex < fromPage.pageIndex) {
                    [scrollView link_scrollToBottomAnimated:NO];
                } else if (toPage.pageIndex > fromPage.pageIndex) {
                    [scrollView link_scrollToTopAnimated:NO];
                }
            }
        }
    }
    if ([_delegate respondsToSelector:@selector(linkPageDidScrollWithOffsetRatio:dragging:)]) {
        [_delegate linkPageDidScrollWithOffsetRatio:ratio dragging:YES];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    //因为pagingEnabled = YES 所以目标位置就是一个整数, 即索引值
    if ([_delegate respondsToSelector:@selector(linkPageDidScrollWithOffsetRatio:dragging:)]) {
        [_delegate linkPageDidScrollWithOffsetRatio:(targetContentOffset ->y/scrollView.frame.size.height)
                                           dragging:NO];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate) return;
    [self scrollViewDidEndDecelerating:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) return;
    _lastPageIndex = _currentPageIndex;
    _currentPageIndex = [_scrollView currentPageIndex];
    if (_currentPageIndex == _lastPageIndex) {
        if (_guessToIndex >= 0 && _guessToIndex < [self numberOfPages]) {
            [[self pageOfIndex:_guessToIndex] beginAppearanceTransition:NO animated:YES];
            [[self pageOfIndex:_currentPageIndex] beginAppearanceTransition:YES animated:YES];
            [[self pageOfIndex:_guessToIndex] endAppearanceTransition];
            [[self pageOfIndex:_currentPageIndex] endAppearanceTransition];
        }
    } else {
        [[self pageOfIndex:_lastPageIndex] endAppearanceTransition];
        [[self pageOfIndex:_currentPageIndex] endAppearanceTransition];
    }
    
    _originOffsetY = scrollView.contentOffset.y;
    _guessToIndex = _currentPageIndex;
    
    if ([_delegate respondsToSelector:@selector(linkPageController:didLeavePage:toPage:)]) {
        [_delegate linkPageController:self
                         didLeavePage:[self pageOfIndex:_lastPageIndex]
                               toPage:[self pageOfIndex:_currentPageIndex]];
    }
}

#pragma mark - 非交互切换page动画
- (void)scrollPageToIndex:(NSUInteger)index animated:(BOOL)animated {
    _lastPageIndex = _currentPageIndex;
    _currentPageIndex = index;
    UIViewController *fromPage = [self pageOfIndex:_lastPageIndex];
    UIViewController *toPage = [self pageOfIndex:_currentPageIndex];
    if ([_delegate respondsToSelector:@selector(linkPageController:willLeavePage:toPage:)]) {
        [_delegate linkPageController:self willLeavePage:fromPage toPage:toPage];
    }
    [self __beginAppearanceTransition];
    if (animated) {
        UIView *lastView = fromPage.view;
        UIView *currentView = toPage.view;
        [_scrollView bringSubviewToFront:lastView];
        [_scrollView bringSubviewToFront:currentView];
        CGFloat lastViewStartOriginY = lastView.frame.origin.y;
        CGFloat currentViewStartOriginY = lastViewStartOriginY;
        CGFloat offset = (_lastPageIndex < _currentPageIndex) ? _scrollView.frame.size.height : -_scrollView.frame.size.height;
        currentViewStartOriginY += offset;
        CGFloat currentViewToOriginY = lastViewStartOriginY;
        CGFloat lastViewToOriginY = lastViewStartOriginY - offset;
        
        currentView.top_mn = currentViewStartOriginY;
        
        [UIView animateWithDuration:kLinkPageAnimatedDuration delay:0.f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            lastView.top_mn = lastViewToOriginY;
            currentView.top_mn = currentViewToOriginY;
        } completion:^(BOOL finished) {
            [self displayCurrentPageIfNeed];
            [self layoutPageView:lastView ofIndex:_lastPageIndex];
            [self layoutPageView:currentView ofIndex:_currentPageIndex];
            [self __endAppearanceTransition];
        }];
    } else {
        [self displayCurrentPageIfNeed];
        [self __endAppearanceTransition];
    }
}

/**动画开始*/
- (void)__beginAppearanceTransition {
    if (_lastPageIndex != _currentPageIndex) {
        [[self pageOfIndex:_lastPageIndex] beginAppearanceTransition:NO animated:YES];
    }
    [[self pageOfIndex:_currentPageIndex] beginAppearanceTransition:YES animated:YES];
}

/**动画结束*/
- (void)__endAppearanceTransition {
    if (_lastPageIndex != _currentPageIndex) {
        [[self pageOfIndex:_lastPageIndex] endAppearanceTransition];
    }
    [[self pageOfIndex:_currentPageIndex] endAppearanceTransition];
    [_delegate linkPageController:self
                 didLeavePage:[self pageOfIndex:_lastPageIndex]
                       toPage:[self pageOfIndex:_currentPageIndex]];
}

/**动画结束计算位置*/
- (void)layoutPageView:(UIView *)pageView ofIndex:(NSUInteger)index {
    if (!pageView || index >= [self numberOfPages]) return;
    CGFloat offsetY = [_scrollView offsetYOfIndex:index];
    if (pageView.frame.origin.y != offsetY) pageView.top_mn = offsetY;
}

#pragma mark - Setter
- (void)setScrollEnabled:(BOOL)scrollEnabled {
    _scrollView.scrollEnabled = scrollEnabled;
}

#pragma mark - Getter
- (BOOL)scrollEnabled {
    return _scrollView.scrollEnabled;
}

- (NSUInteger)numberOfPages {
    return [_dataSource numberOfPages];
}

- (UIViewController *)pageOfIndex:(NSUInteger)pageIndex {
    UIViewController *page = [_pageCache objectForKey:@(pageIndex)];
    if (!page && [_dataSource respondsToSelector:@selector(pageOfIndex:)]) {
        page = [_dataSource pageOfIndex:pageIndex];
        if (page) {
            page.pageIndex = pageIndex;
            page.view.backgroundColor = page.view.backgroundColor;
            [self addChildPage:page ofIndex:pageIndex];
            [_pageCache setObject:page forKey:@(pageIndex)];
        }
    }
    return page;
}

#pragma mark - AddPage
- (void)addChildPage:(UIViewController *)page ofIndex:(NSUInteger)pageIndex {
    CGFloat offsetY = [_scrollView offsetYOfIndex:pageIndex];
    page.view.left_mn = 0.f;
    page.view.top_mn = offsetY;
    [self addChildPage:page];
}

- (void)addChildPage:(UIViewController *)page {
    if ([self.childViewControllers containsObject:page]) return;
    [page willMoveToParentViewController:self];
    [self addChildViewController:page];
    [_scrollView addSubview:page.view];
    [page didMoveToParentViewController:self];
}

#pragma mark - controller config
- (BOOL)isChildViewController {
    return YES;
}

@end



@implementation UIViewController (MNLinkPage)

- (void)setPageIndex:(NSUInteger)pageIndex {
    objc_setAssociatedObject(self, &MNLinkPageIndexKey, @(pageIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)pageIndex {
    NSNumber *pageIndex = objc_getAssociatedObject(self, &MNLinkPageIndexKey);
    if (pageIndex) return [pageIndex unsignedIntegerValue];
    return 0;
}

@end
