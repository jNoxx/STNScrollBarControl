//
//  STNScrollBar.m
//  STNScrollBarControl
//
//  Created by Stone Zhang on 9/23/17.
//  Copyright © 2017 Stone Zhang. All rights reserved.
//

#import "STNScrollBar.h"
#import "STNScrollBarThumb.h"
#import "STNScrollBarText.h"
#import "UIScrollView+STNScrollBar.h"

static const CGFloat kSTNScrollBarWidth = 30.0;
static const CGFloat kSTNScrollBarEnableThreshold = 1.5;
static const CGFloat kSTNScrollBarAnimationInterval = 0.3;
static const CGFloat kSTNScrollBarAnimationHideDelay = 1.0;
static const CGFloat kSTNScrollBarPauseTrackingDelay = 1.0;

static NSString * const kSTNScrollViewContentInsetKeyPath = @"contentInset";

@interface STNScrollBar ()
@property (strong, nonatomic) STNScrollBarThumb *thumb;
@property (strong, nonatomic) STNScrollBarText *text;
@property (weak, nonatomic) NSTimer *hideAnimationTimer;
@property (weak, nonatomic) NSTimer *scrubbingPauseTimer;
@end

@implementation STNScrollBar

+ (instancetype)scrollBar {
    return [[STNScrollBar alloc] initScrollBar];
}

- (instancetype)initScrollBar {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        _thumb = [STNScrollBarThumb layer];
        [self.layer addSublayer:_thumb];
        
        _text = [STNScrollBarText layer];
        _text.hidden = YES;
        [_thumb addSublayer:_text];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.hideAnimationTimer) {
        [self.hideAnimationTimer invalidate];
    }
    
    if (self.scrubbingPauseTimer) {
        [self.scrubbingPauseTimer invalidate];
        self.scrubbingPauseTimer = nil;
    }
    
    self.hidden = YES;
    self.frame = CGRectMake(CGRectGetWidth(_scrollView.frame),
                            CGRectGetMinY(_scrollView.frame) + _scrollView.stn_contentInsetTop,
                            kSTNScrollBarWidth,
                            _scrollView.stn_height);
    
    [self updateThumbPositionByScrollView];
}

- (void)viewDidDisappear {
    [self setNeedsLayout];
}

- (void)dealloc {
    [_scrollView removeObserver:self forKeyPath:kSTNScrollViewContentInsetKeyPath];
}

- (void)setScrollView:(UIScrollView *)scrollView {
    [_scrollView removeObserver:self forKeyPath:kSTNScrollViewContentInsetKeyPath];
    _scrollView = scrollView;
    _scrollView.showsVerticalScrollIndicator = NO;
    [_scrollView addObserver:self forKeyPath:kSTNScrollViewContentInsetKeyPath options:NSKeyValueObservingOptionNew context:nil];
    
    [self setNeedsLayout];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object != _scrollView) {
        return;
    }
    
    if ([keyPath isEqualToString:kSTNScrollViewContentInsetKeyPath]) {
        
    }
    
    [self setNeedsLayout];
}

#pragma mark - Animation

- (void)show {
    if (_scrollView.contentSize.height < kSTNScrollBarEnableThreshold * _scrollView.stn_height) {
        return;
    }
    
    self.text.hidden = YES;
    self.hidden = NO;
    self.alpha = 0;
    CGRect toFrame = self.frame;
    toFrame.origin.x = CGRectGetWidth(_scrollView.frame) - CGRectGetWidth(self.frame);
    [UIView animateWithDuration:kSTNScrollBarAnimationInterval
                     animations:^{
                         self.frame = toFrame;
                         self.alpha = 1;
                     }
                     completion:nil];
}

- (void)hideWithDelay {
    if (self.hideAnimationTimer != nil) {
        [self.hideAnimationTimer invalidate];
    }
    
    self.hideAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:kSTNScrollBarAnimationHideDelay target:self selector:@selector(hideWithAnimationOnTimer) userInfo:nil repeats:NO];
}

- (void)hideWithAnimationOnTimer {
    CGRect toFrame = self.frame;
    toFrame.origin.x = CGRectGetWidth(_scrollView.frame);
    [UIView animateWithDuration:kSTNScrollBarAnimationInterval
                     animations:^{
                         self.frame = toFrame;
                         self.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                         self.hidden = YES;
                         self.alpha = 1;
                         self.text.hidden = YES;
                     }];
}

- (void)cancelHideWithDelay {
    if (self.hideAnimationTimer != nil) {
        [self.hideAnimationTimer invalidate];
    }
}

- (void)startPauseTimer {
    [self cancelPauseTimer];
    
    self.scrubbingPauseTimer = [NSTimer scheduledTimerWithTimeInterval:kSTNScrollBarPauseTrackingDelay target:self selector:@selector(notifyDelegateOnPauseTimer) userInfo:nil repeats:NO];
}

- (void)cancelPauseTimer {
    if (self.scrubbingPauseTimer) {
        [self.scrubbingPauseTimer invalidate];
        self.scrubbingPauseTimer = nil;
    }
}

- (void)notifyDelegateOnPauseTimer {
    if (self.delegate) {
        NSIndexPath *indexPath = [self indexPathForVisibleItem];
        [self.delegate scrollBarPausedManuallyScrubbing:self atIndexPath:indexPath];
    }
}


#pragma mark - Touch Event

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(self.thumb.frame, point);
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint point = [touch locationInView:self];
    if (CGRectContainsPoint(self.thumb.frame, point)) {
        // stop scrollview scrolling
        [self updateScrollViewContentOffset];
        [self showText];
        [self cancelHideWithDelay];
        if (self.delegate) {
            [self.delegate scrollBarStartedManuallyScrubbing:self];
        }
        [self startPauseTimer];
        return YES;
    }
    
    return NO;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self updateThumbPositionByTouch:touch];
    // Start a timer, if you hold still for a bit, that it starts loading after all, since not everyone will understand you have to let go to properly start.
    [self startPauseTimer];

    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self updateThumbPositionByTouch:touch];
    [self hideWithDelay];
    [self cancelPauseTimer];
    
    if (self.delegate) {
        // Add the indexPath where we think it stopped scrubbing (Same what we will use for updating the Thumb).
        NSIndexPath *indexPath = [self indexPathForVisibleItem];
        [self.delegate scrollBarEndedManuallyScrubbing:self atIndexPath:indexPath];
        // Also update the title, since it happens that we did it too fast and it doesnt update properly.
        [self updateScrollBarText];
    }
}

- (void)updateScrollViewContentOffset {
    CGPoint offset = _scrollView.contentOffset;
    offset.y = (_scrollView.contentSize.height - CGRectGetHeight(self.frame)) * [self thumbOffsetRatio] - _scrollView.stn_contentInsetTop;
    [_scrollView setContentOffset:offset animated:NO];
}

#pragma mark - Thumb

- (void)updateThumbPositionByScrollView {
    if (self.isTracking) {
        // Thumb is being tracked by touch now
        return;
    }
    
    CGFloat y = (CGRectGetHeight(self.frame) - CGRectGetHeight(self.thumb.bounds)) * _scrollView.stn_didScrollRatio;
    y = MIN(MAX(y, 0), CGRectGetHeight(self.frame) - CGRectGetHeight(self.thumb.bounds));
    [self.thumb setOriginY: y];
}

- (void)updateThumbPositionByTouch:(UITouch *)touch {
    CGFloat y = [touch locationInView:self].y - CGRectGetHeight(self.thumb.bounds) * 0.5;
    y = MIN(MAX(y, 0), (CGRectGetHeight(self.frame) - CGRectGetHeight(self.thumb.bounds)));
    BOOL updatedThumbPosition = [self.thumb setOriginY:y];
    
    if (updatedThumbPosition) {
        [self updateScrollViewContentOffset];
        if (self.delegate) {
            [self updateScrollBarText];
        }
    }
}

- (CGFloat)thumbOffsetRatio {
    return CGRectGetMinY(self.thumb.frame) / (CGRectGetHeight(self.frame) - CGRectGetHeight(self.thumb.bounds));
}

#pragma mark - Text

- (void)showText {
    if (self.delegate) {
        [self updateScrollBarText];
        [self.text fadeInText];
    }
}

- (void)hideText {
    if (self.delegate) {
        [self.text fadeOutText];
    }
}

- (void)updateScrollBarText {
    NSIndexPath *indexPath = [self indexPathForVisibleItem];
    if (indexPath) {
        NSString *itemString = [self itemStringAtIndexPath:indexPath];
        if (itemString) {
            [self.text updateTextWithItemString:itemString];
        }
    }
}

- (NSIndexPath *)indexPathForVisibleItem {
    NSArray<NSIndexPath *> *indexPaths;
    
    if ([_scrollView isKindOfClass:[UITableView class]]) {
        indexPaths = [(UITableView *)self.scrollView indexPathsForVisibleRows];
    } else if ([_scrollView isKindOfClass:[UICollectionView class]]) {
        indexPaths = [(UICollectionView *)self.scrollView indexPathsForVisibleItems];
        
        if (indexPaths.count > 0) {
            indexPaths = [indexPaths sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *idx1, NSIndexPath *idx2) {
                return [idx1 compare:idx2];
            }];
        }
    }
    
    if (indexPaths.count == 0) {
        // Handle the case when there are no visible items
        return nil;
    }
    
    CGFloat ratio = [self thumbOffsetRatio];
    NSInteger idx = MIN(indexPaths.count - 1, MAX(0, floor(indexPaths.count * ratio)));
    
    // Check if idx is within bounds
    if (idx >= 0 && idx < indexPaths.count) {
        return indexPaths[idx];
    } else {
        // Handle the case when the calculated index is out of bounds
        return nil;
    }
}

#pragma mark - STNScrollBarDelegate

- (NSString *)itemStringAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.delegate respondsToSelector:@selector(scrollBar:itemStringAtIndexPath:)]) {
        return [self.delegate scrollBar:self itemStringAtIndexPath:indexPath];
    }
    return nil;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging {
    if (self.isHidden) {
        [self show];
    } else {
        [self cancelHideWithDelay];
        [self hideText];
    }
}

- (void)scrollViewDidScroll {
    [self updateThumbPositionByScrollView];
}

- (void)scrollViewDidEndDraggingAndWillDecelerate:(BOOL)decelerate {
    if (decelerate == NO) {
        if (self.isHidden == NO) {
            [self hideWithDelay];
        }
    }
}

- (void)scrollViewDidEndDecelerating {
    if (self.isHidden == NO) {
        [self hideWithDelay];
    }
}

@end
