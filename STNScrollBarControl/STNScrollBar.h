//
//  STNScrollBar.h
//  STNScrollBarControl
//
//  Created by Stone Zhang on 9/23/17.
//  Copyright © 2017 Stone Zhang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class STNScrollBar;
@protocol STNScrollBarDelegate <NSObject>
@optional
- (NSString *)scrollBar:(STNScrollBar *)scrollBar itemStringAtIndexPath:(NSIndexPath *)indexPath;
- (void)scrollBarStartedManuallyScrubbing:(STNScrollBar *)scrollBar;
- (void)scrollBarPausedManuallyScrubbing:(STNScrollBar *)scrollBar atIndexPath:(NSIndexPath *)indexPath;
- (void)scrollBarEndedManuallyScrubbing:(STNScrollBar *)scrollBar atIndexPath:(NSIndexPath *)indexPath;
@end

@interface STNScrollBar : UIControl
@property (weak, nonatomic) UIScrollView *scrollView;
@property (weak, nonatomic) id<STNScrollBarDelegate>delegate;
+ (instancetype)scrollBar;
- (instancetype)initScrollBar;
- (void)viewDidDisappear;
// UIScrollViewDelegate
- (void)scrollViewWillBeginDragging;
- (void)scrollViewDidScroll;
- (void)scrollViewDidEndDraggingAndWillDecelerate:(BOOL)decelerate;
- (void)scrollViewDidEndDecelerating;
@end
