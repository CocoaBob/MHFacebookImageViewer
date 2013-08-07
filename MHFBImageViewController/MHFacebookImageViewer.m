//
// MHFacebookImageViewer.m
// Version 2.0
//
// Copyright (c) 2013 Michael Henry Pantaleon (http://www.iamkel.net). All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import "MHFacebookImageViewer.h"

static const CGFloat kMinBlackMaskAlpha = 0.3f;
static const CGFloat kMaxImageScale = 2.5f;
static const CGFloat kMinImageScale = 1.0f;

@interface MHFacebookImageViewerCell : UITableViewCell <UIGestureRecognizerDelegate,UIScrollViewDelegate>{
    UIImageView * __imageView;
    UIScrollView * __scrollView;
    
    NSMutableArray *_gestures;
    
    CGPoint _panOrigin;
    
    BOOL _isAnimating;
    BOOL _isDoneAnimating;
    BOOL _isLoaded;
}

@property (nonatomic,assign) CGRect originalFrameRelativeToScreen;
@property (nonatomic,weak) UIViewController * rootViewController;
@property (nonatomic,weak) UIViewController * viewController;
@property (nonatomic,weak) UIView * blackMask;
@property (nonatomic,weak) UIButton * doneButton;
@property (nonatomic,weak) UIImageView * senderView;
@property (nonatomic,assign) NSInteger imageIndex;
@property (nonatomic,weak) UIImage * defaultImage;

@property (nonatomic,weak) MHFacebookImageViewerOpeningBlock openingBlock;
@property (nonatomic,weak) MHFacebookImageViewerClosingBlock closingBlock;

@property (nonatomic,weak) UIView * superView;

- (void)loadAllRequiredViews;
- (void)setImage:(UIImage *)image defaultImage:(UIImage*)defaultImage;

@end

@implementation MHFacebookImageViewerCell

- (void)loadAllRequiredViews{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    CGRect frame = [UIScreen mainScreen].applicationFrame;
    __scrollView = [[UIScrollView alloc]initWithFrame:frame];
    __scrollView.delegate = self;
    [self addSubview:__scrollView];
}

- (void)setImage:(UIImage *)image defaultImage:(UIImage*)defaultImage {
    _defaultImage = defaultImage;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _senderView.alpha = 0.0f;
        if(!__imageView){
            __imageView = [[UIImageView alloc]init];
            [__scrollView addSubview:__imageView];
            __imageView.contentMode = UIViewContentModeScaleAspectFill;
        }
        __block MHFacebookImageViewerCell * _justMeInsideTheBlock = self;
        __block UIScrollView * _scrollViewInsideBlock = __scrollView;
        
        [_scrollViewInsideBlock setZoomScale:1.0f animated:YES];
        [__imageView setImage:image];
        __imageView.frame = [_justMeInsideTheBlock centerFrameFromImage:__imageView.image];
        
        if(!_isLoaded){
            __imageView.frame = _originalFrameRelativeToScreen;
            [UIView animateWithDuration:0.25f delay:0.0f options:0 animations:^{
                __imageView.frame = [self centerFrameFromImage:__imageView.image];
                CGAffineTransform transf = CGAffineTransformIdentity;
                // Root View Controller - move backward
                _rootViewController.view.transform = CGAffineTransformScale(transf, 0.95f, 0.95f);
                // Root View Controller - move forward
                //                _viewController.view.transform = CGAffineTransformScale(transf, 1.05f, 1.05f);
                _blackMask.alpha = 1;
            } completion:^(BOOL finished) {
                if (finished) {
                    _isAnimating = NO;
                    _isLoaded = YES;
                    if(_openingBlock)
                        _openingBlock();
                }
            }];
            
        }
        __imageView.userInteractionEnabled = YES;
        [self addPanGestureToView:__imageView];
        [self addMultipleGesture];
        
    });
}

#pragma mark - Add Pan Gesture

- (void)addPanGestureToView:(UIView*)view {
    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureRecognizerDidPan:)];
    panGesture.cancelsTouchesInView = YES;
    panGesture.delegate = self;
    [view addGestureRecognizer:panGesture];
    [_gestures addObject:panGesture];
    panGesture = nil;
}

# pragma mark - Avoid Unwanted Horizontal Gesture

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)panGestureRecognizer {
    CGPoint translation = [panGestureRecognizer translationInView:__scrollView];
    return fabs(translation.y) > fabs(translation.x) ;
}

#pragma mark - Gesture recognizer

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    _panOrigin = __imageView.frame.origin;
    gestureRecognizer.enabled = YES;
    return !_isAnimating;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    UITableView * tableView = (UITableView*)self.superview;
    if ([otherGestureRecognizer isEqual:(tableView.panGestureRecognizer)])
    {
        return NO;
    }
    return YES;
}

#pragma mark - Handle Panning Activity

- (void)gestureRecognizerDidPan:(UIPanGestureRecognizer*)panGesture {
    if(__scrollView.zoomScale != 1.0f || _isAnimating)return;
    if(_senderView.alpha!=0.0f)
        _senderView.alpha = 0.0f;
    // Hide the Done Button
    __scrollView.bounces = NO;
    CGSize windowSize = _blackMask.bounds.size;
    CGPoint currentPoint = [panGesture translationInView:__scrollView];
    CGFloat y = currentPoint.y + _panOrigin.y;
    CGRect frame = __imageView.frame;
    frame.origin = CGPointMake(0, y);
    __imageView.frame = frame;
    
    CGFloat yDiff = abs((y + __imageView.frame.size.height/2) - windowSize.height/2);
    _blackMask.alpha = MAX(1 - yDiff/(windowSize.height/2),kMinBlackMaskAlpha);
    
    if ((panGesture.state == UIGestureRecognizerStateEnded || panGesture.state == UIGestureRecognizerStateCancelled) && __scrollView.zoomScale == 1.0f) {
        
        if(_blackMask.alpha < 0.7) {
            [self dismissViewController];
        }else {
            [self rollbackViewController];
        }
    }
}

#pragma mark - Just Rollback

- (void)rollbackViewController {
    _isAnimating = YES;
    [UIView animateWithDuration:0.2f delay:0.0f options:0 animations:^{
        __imageView.frame = [self centerFrameFromImage:__imageView.image];
        _blackMask.alpha = 1;
    }   completion:^(BOOL finished) {
        if (finished) {
            _isAnimating = NO;
        }
    }];
}


#pragma mark - Dismiss

- (void)dismissViewController {
    _isAnimating = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        __imageView.clipsToBounds = YES;
        [UIView animateWithDuration:0.2f delay:0.0f options:0 animations:^{
            __imageView.frame = _originalFrameRelativeToScreen;
            CGAffineTransform transf = CGAffineTransformIdentity;
            _rootViewController.view.transform = CGAffineTransformScale(transf, 1.0f, 1.0f);
            _blackMask.alpha = 0.0f;
        } completion:^(BOOL finished) {
            if (finished) {
                [_viewController.view removeFromSuperview];
                [_viewController removeFromParentViewController];
                _senderView.alpha = 1.0f;
                [UIApplication sharedApplication].statusBarHidden = NO;
                _isAnimating = NO;
                if(_closingBlock)
                    _closingBlock();
            }
        }];
    });
}

#pragma mark - Compute the new size of image relative to width(window)

- (CGRect)centerFrameFromImage:(UIImage*) image {
    if(!image) return CGRectZero;
    
    CGRect windowBounds = _rootViewController.view.bounds;
    CGSize newImageSize = [self imageResizeBaseOnWidth:windowBounds
                           .size.width oldWidth:image
                           .size.width oldHeight:image.size.height];
    // Just fit it on the size of the screen
    newImageSize.height = MIN(windowBounds.size.height,newImageSize.height);
    return CGRectMake(0.0f, windowBounds.size.height/2 - newImageSize.height/2, newImageSize.width, newImageSize.height);
}

- (CGSize)imageResizeBaseOnWidth:(CGFloat)newWidth oldWidth:(CGFloat)oldWidth oldHeight:(CGFloat)oldHeight {
    CGFloat scaleFactor = newWidth / oldWidth;
    CGFloat newHeight = oldHeight * scaleFactor;
    return CGSizeMake(newWidth, newHeight);
    
}

# pragma mark - UIScrollView Delegate

- (void)centerScrollViewContents {
    CGSize boundsSize = _rootViewController.view.bounds.size;
    CGRect contentsFrame = __imageView.frame;
    
    if (contentsFrame.size.width < boundsSize.width) {
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0f;
    } else {
        contentsFrame.origin.x = 0.0f;
    }
    
    if (contentsFrame.size.height < boundsSize.height) {
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0f;
    } else {
        contentsFrame.origin.y = 0.0f;
    }
    __imageView.frame = contentsFrame;
}

- (UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return __imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    _isAnimating = YES;
    [self centerScrollViewContents];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
    _isAnimating = NO;
}

- (void)addMultipleGesture {
    UITapGestureRecognizer *twoFingerTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTwoFingerTap:)];
    twoFingerTapGesture.numberOfTapsRequired = 1;
    twoFingerTapGesture.numberOfTouchesRequired = 2;
    [__scrollView addGestureRecognizer:twoFingerTapGesture];
    
    UITapGestureRecognizer *singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSingleTap:)];
    singleTapRecognizer.numberOfTapsRequired = 1;
    singleTapRecognizer.numberOfTouchesRequired = 1;
    [__scrollView addGestureRecognizer:singleTapRecognizer];
    
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDobleTap:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [__scrollView addGestureRecognizer:doubleTapRecognizer];
    
    [singleTapRecognizer requireGestureRecognizerToFail:doubleTapRecognizer];
    
    __scrollView.minimumZoomScale = kMinImageScale;
    __scrollView.maximumZoomScale = kMaxImageScale;
    __scrollView.zoomScale = 1;
    [self centerScrollViewContents];
}

#pragma mark - For Zooming

- (void)didTwoFingerTap:(UITapGestureRecognizer*)recognizer {
    CGFloat newZoomScale = __scrollView.zoomScale / 1.5f;
    newZoomScale = MAX(newZoomScale, __scrollView.minimumZoomScale);
    [__scrollView setZoomScale:newZoomScale animated:YES];
}

#pragma mark - Dismiss

- (void)didSingleTap:(UITapGestureRecognizer*)recognizer {
    [self dismissViewController];
}

#pragma mark - Zoom in or Zoom out

- (void)didDobleTap:(UITapGestureRecognizer*)recognizer {
    CGPoint pointInView = [recognizer locationInView:__imageView];
    [self zoomInZoomOut:pointInView];
}

- (void)zoomInZoomOut:(CGPoint)point {
    // Check if current Zoom Scale is greater than half of max scale then reduce zoom and vice versa
    CGFloat newZoomScale = __scrollView.zoomScale > (__scrollView.maximumZoomScale/2)?__scrollView.minimumZoomScale:__scrollView.maximumZoomScale;
    
    CGSize scrollViewSize = __scrollView.bounds.size;
    CGFloat w = scrollViewSize.width / newZoomScale;
    CGFloat h = scrollViewSize.height / newZoomScale;
    CGFloat x = point.x - (w / 2.0f);
    CGFloat y = point.y - (h / 2.0f);
    CGRect rectToZoomTo = CGRectMake(x, y, w, h);
    [__scrollView zoomToRect:rectToZoomTo animated:YES];
}

@end

#pragma mark -

@interface MHFacebookImageViewer : UIViewController <UIGestureRecognizerDelegate,UIScrollViewDelegate,UITableViewDataSource,UITableViewDelegate> {
    NSMutableArray *_gestures;
    
    UITableView * _tableView;
    UIView *_blackMask;
    UIImageView * _imageView;
    UIButton * _doneButton;
    UIView * _superView;
    
    CGPoint _panOrigin;
    CGRect _originalFrameRelativeToScreen;
    
    BOOL _isAnimating;
    BOOL _isDoneAnimating;
}

@property (weak, readonly, nonatomic) UIViewController *rootViewController;
@property (nonatomic,strong) UIImage * image;
@property (nonatomic,strong) UIImageView * senderView;
@property (nonatomic,weak) MHFacebookImageViewerOpeningBlock openingBlock;
@property (nonatomic,weak) MHFacebookImageViewerClosingBlock closingBlock;
@property (nonatomic,assign) NSInteger initialIndex;

- (void)presentFromRootViewController;
- (void)presentFromViewController:(UIViewController *)controller;

@end

@implementation MHFacebookImageViewer

- (void)loadView {
    [super loadView];
    [UIApplication sharedApplication].statusBarHidden = YES;
    CGRect windowBounds = [[UIScreen mainScreen] applicationFrame];
    
    
    // Compute Original Frame Relative To Screen
    CGRect newFrame = [_senderView convertRect:[[UIScreen mainScreen] applicationFrame] toView:nil];
    newFrame.origin = CGPointMake(newFrame.origin.x, newFrame.origin.y);
    newFrame.size = _senderView.frame.size;
    _originalFrameRelativeToScreen = newFrame;
    
    self.view = [[UIView alloc] initWithFrame:windowBounds];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Add a Tableview
    _tableView = [[UITableView alloc]initWithFrame:windowBounds style:UITableViewStylePlain];
    [self.view addSubview:_tableView];
    //rotate it -90 degrees
    _tableView.transform = CGAffineTransformMakeRotation(-M_PI_2);
    _tableView.frame = CGRectMake(0,0,windowBounds.size.width,windowBounds.size.height);
    _tableView.pagingEnabled = YES;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    [_tableView setShowsVerticalScrollIndicator:NO];
    [_tableView setContentOffset:CGPointMake(0, _initialIndex * [[UIScreen mainScreen] applicationFrame].size.width)];
    
    _blackMask = [[UIView alloc] initWithFrame:windowBounds];
    _blackMask.backgroundColor = [UIColor blackColor];
    _blackMask.alpha = 0.0f;
    _blackMask.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [
     self.view insertSubview:_blackMask atIndex:0];
}

#pragma mark Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
    static NSString * cellID = @"mhfacebookImageViewerCell";
    MHFacebookImageViewerCell * imageViewerCell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if(!imageViewerCell) {
        CGRect windowFrame = [[UIScreen mainScreen] applicationFrame];
        imageViewerCell = [[MHFacebookImageViewerCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        imageViewerCell.transform = CGAffineTransformMakeRotation(M_PI_2);
        imageViewerCell.frame = CGRectMake(0,0,windowFrame.size.width, windowFrame.size.height);
        imageViewerCell.originalFrameRelativeToScreen = _originalFrameRelativeToScreen;
        imageViewerCell.viewController = self;
        imageViewerCell.blackMask = _blackMask;
        imageViewerCell.rootViewController = _rootViewController;
        imageViewerCell.closingBlock = _closingBlock;
        imageViewerCell.openingBlock = _openingBlock;
        imageViewerCell.superView = _senderView.superview;
        imageViewerCell.senderView = _senderView;
        imageViewerCell.doneButton = _doneButton;
        [imageViewerCell loadAllRequiredViews];
    }
    [imageViewerCell setImage:_image defaultImage:_senderView.image];
    return imageViewerCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return _rootViewController.view.bounds.size.width;
}

#pragma mark - Show

- (void)presentFromRootViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [self presentFromViewController:rootViewController];
}

- (void)presentFromViewController:(UIViewController *)controller {
    _rootViewController = controller;
    [[[[UIApplication sharedApplication]windows]objectAtIndex:0]addSubview:self.view];
    [controller addChildViewController:self];
    [self didMoveToParentViewController:controller];
}

@end

#pragma mark - Custom Gesture Recognizer that will Handle image

@interface MHFacebookImageViewerTapGestureRecognizer : UITapGestureRecognizer

@property(nonatomic,strong) UIImage *image;
@property(nonatomic,strong) MHFacebookImageViewerLoadingBlock loadingBlock;
@property(nonatomic,strong) MHFacebookImageViewerOpeningBlock openingBlock;
@property(nonatomic,strong) MHFacebookImageViewerClosingBlock closingBlock;

@end

@implementation MHFacebookImageViewerTapGestureRecognizer

@end

#pragma mark - UIImageView Category

@implementation UIImageView (MHFacebookImageViewer)

#pragma mark - Initializer for UIImageView

- (void)setupImageViewerWithImage:(UIImage*)image {
    [self setupImageViewerWithImage:image onOpen:nil onClose:nil];
}

- (void)setupImageViewerWithImage:(UIImage *)image onOpen:(MHFacebookImageViewerOpeningBlock)open onClose:(MHFacebookImageViewerClosingBlock)close {
    self.userInteractionEnabled = YES;
    MHFacebookImageViewerTapGestureRecognizer *  tapGesture = [[MHFacebookImageViewerTapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    tapGesture.image = image;
    tapGesture.openingBlock = open;
    tapGesture.closingBlock = close;
    [[self gestureRecognizers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[MHFacebookImageViewerTapGestureRecognizer class]]) {
            [self removeGestureRecognizer:obj];
        }
    }];
    [self addGestureRecognizer:tapGesture];
    tapGesture = nil;
}

- (void)setupImageViewerWithLoadingBlock:(MHFacebookImageViewerLoadingBlock)loadingBlock {
    [self setupImageViewerWithLoadingBlock:loadingBlock onOpen:nil onClose:nil];
}

- (void)setupImageViewerWithLoadingBlock:(MHFacebookImageViewerLoadingBlock)loadingBlock onOpen:(MHFacebookImageViewerOpeningBlock)open onClose:(MHFacebookImageViewerClosingBlock)close {
    self.userInteractionEnabled = YES;
    MHFacebookImageViewerTapGestureRecognizer *  tapGesture = [[MHFacebookImageViewerTapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    tapGesture.loadingBlock = loadingBlock;
    tapGesture.openingBlock = open;
    tapGesture.closingBlock = close;
    [[self gestureRecognizers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[MHFacebookImageViewerTapGestureRecognizer class]]) {
            [self removeGestureRecognizer:obj];
        }
    }];
    [self addGestureRecognizer:tapGesture];
    tapGesture = nil;
}

#pragma mark - Handle Tap

- (void)didTap:(MHFacebookImageViewerTapGestureRecognizer*)gestureRecognizer {
    MHFacebookImageViewer * imageBrowser = [[MHFacebookImageViewer alloc]init];
    imageBrowser.senderView = self;
    if (gestureRecognizer.image) {
        imageBrowser.image = gestureRecognizer.image;
    }
    else if (gestureRecognizer.loadingBlock) {
        imageBrowser.image = gestureRecognizer.loadingBlock();
    }
    imageBrowser.openingBlock = gestureRecognizer.openingBlock;
    imageBrowser.closingBlock = gestureRecognizer.closingBlock;
    if(self.image)
        [imageBrowser presentFromRootViewController];
}

@end

