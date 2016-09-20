//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQMessagesInputToolbar.h"

#import "JSQMessagesComposerTextView.h"

#import "JSQMessagesToolbarButtonFactory.h"

#import "UIColor+JSQMessages.h"
#import "UIImage+JSQMessages.h"
#import "UIView+JSQMessages.h"
#import "NSBundle+JSQMessages.h"

static void * kJSQMessagesInputToolbarKeyValueObservingContext = &kJSQMessagesInputToolbarKeyValueObservingContext;


@interface JSQMessagesInputToolbar ()<KSMManyOptionsButtonDelegate>

@property (assign, nonatomic) BOOL jsq_isObserving;
@property (strong, nonatomic) KSMManyOptionsButton *optionsButton;

@end



@implementation JSQMessagesInputToolbar

@dynamic delegate;

#pragma mark - Initialization

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

    self.jsq_isObserving = NO;
    self.sendButtonOnRight = YES;

    self.preferredDefaultHeight = 44.0f;
    self.maximumHeight = NSNotFound;

    JSQMessagesToolbarContentView *toolbarContentView = [self loadToolbarContentView];
    toolbarContentView.frame = self.frame;
    [self addSubview:toolbarContentView];
    [self jsq_pinAllEdgesOfSubview:toolbarContentView];
    [self setNeedsUpdateConstraints];
    _contentView = toolbarContentView;

    [self jsq_addObservers];

    self.contentView.leftBarButtonItem = [JSQMessagesToolbarButtonFactory defaultAccessoryButtonItem];
    UIButton *rightButton = [JSQMessagesToolbarButtonFactory defaultSendButtonItem];
    rightButton.hidden = true;
    self.contentView.rightBarButtonItem = rightButton;
    
    self.optionsButton = [JSQMessagesToolbarButtonFactory defaultOptionsButton];
    self.optionsButton.delegate = self;
    
//    self.contentView.rightBarButtonItem = self.optionsButton;
    
    
    //////////////////
    
    self.optionsButton.center = CGPointMake(20, 17);
    self.optionsButton.centerLabel.center = [self.optionsButton convertPoint:self.optionsButton.center fromView:self.optionsButton.superview];
    [self.optionsButton.centerLabel setLineBreakMode:NSLineBreakByWordWrapping];
    self.optionsButton.centerLabel.textAlignment = NSTextAlignmentCenter;
    
    [self.contentView.rightBarButtonContainerView addSubview:self.optionsButton];
    self.optionsButton.frame = CGRectMake(self.optionsButton.frame.origin.x, self.optionsButton.frame.origin.y, self.contentView.rightBarButtonContainerView.frame.size.width, self.optionsButton.frame.size.height);
    
    [self.contentView bringSubviewToFront:self.contentView.rightBarButtonContainerView];
    
    [self toggleSendButtonEnabled];
}

- (JSQMessagesToolbarContentView *)loadToolbarContentView
{
    NSArray *nibViews = [[NSBundle bundleForClass:[JSQMessagesInputToolbar class]] loadNibNamed:NSStringFromClass([JSQMessagesToolbarContentView class])
                                                                                          owner:nil
                                                                                        options:nil];
    return nibViews.firstObject;
}

- (void)dealloc
{
    [self jsq_removeObservers];
}

#pragma mark - Setters

- (void)setPreferredDefaultHeight:(CGFloat)preferredDefaultHeight
{
    NSParameterAssert(preferredDefaultHeight > 0.0f);
    _preferredDefaultHeight = preferredDefaultHeight;
}

#pragma mark - Actions



- (void)jsq_leftBarButtonPressed:(UIButton *)sender
{
    [self.delegate messagesInputToolbar:self didPressLeftBarButton:sender];
}

-(void)manyOptionDidBeginOpening:(KSMManyOptionsButton *)button
{
    [self.delegate messagesInputToolbar:self didBeginOpeningButton:button];
}

-(void)manyOptionDidOpen:(KSMManyOptionsButton *)button
{
    [self.delegate messagesInputToolbar:self didOpenOptionButton:button];
}

-(void) manyOptionDidBeginClosing:(KSMManyOptionsButton *)button
{
    [self.delegate messagesInputToolbar:self didBeginClosingOptionButton:button];
}

-(void)manyOptionDidClose:(KSMManyOptionsButton *)button {
    [self.delegate messagesInputToolbar:self didCloseOptionButton:button];
}

-(void) manyOptionDidPressCenter:(KSMManyOptionsButton *)button
{
    [self.delegate messagesInputToolbar:self didPressRightBarButton:button];
}

-(void) manyOptionsButton:(KSMManyOptionsButton *)button didSelectButtonAtLocation:(KSMManyOptionsButtonLocation)location
{
    [self.delegate messagesInputToolbar:self didSelectOptionButton:location];
}

#pragma mark - Input toolbar

- (void)toggleSendButtonEnabled
{
    [self.optionsButton showCenterText:[self.contentView.textView hasText]];

//    if (self.sendButtonOnRight) {
//        self.contentView.rightBarButtonItem.enabled = hasText;
//    }
//    else {
//        self.contentView.leftBarButtonItem.enabled = hasText;
//    }
}



#pragma mark - Key-value observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kJSQMessagesInputToolbarKeyValueObservingContext) {
        if (object == self.contentView) {

            if ([keyPath isEqualToString:NSStringFromSelector(@selector(leftBarButtonItem))]) {

                [self.contentView.leftBarButtonItem removeTarget:self
                                                          action:NULL
                                                forControlEvents:UIControlEventTouchUpInside];

                [self.contentView.leftBarButtonItem addTarget:self
                                                       action:@selector(jsq_leftBarButtonPressed:)
                                             forControlEvents:UIControlEventTouchUpInside];
            }
            else if ([keyPath isEqualToString:NSStringFromSelector(@selector(rightBarButtonItem))]) {

                [self.contentView.rightBarButtonItem removeTarget:self
                                                           action:NULL
                                                 forControlEvents:UIControlEventTouchUpInside];

//                [self.contentView.rightBarButtonItem addTarget:self
//                                                        action:@selector(jsq_rightBarButtonPressed:)
//                                              forControlEvents:UIControlEventTouchUpInside];
            }

            [self toggleSendButtonEnabled];
        }
    }
}

- (void)jsq_addObservers
{
    if (self.jsq_isObserving) {
        return;
    }

    [self.contentView addObserver:self
                       forKeyPath:NSStringFromSelector(@selector(leftBarButtonItem))
                          options:0
                          context:kJSQMessagesInputToolbarKeyValueObservingContext];

    [self.contentView addObserver:self
                       forKeyPath:NSStringFromSelector(@selector(rightBarButtonItem))
                          options:0
                          context:kJSQMessagesInputToolbarKeyValueObservingContext];

    self.jsq_isObserving = YES;
}

- (void)jsq_removeObservers
{
    if (!_jsq_isObserving) {
        return;
    }

    @try {
        [_contentView removeObserver:self
                          forKeyPath:NSStringFromSelector(@selector(leftBarButtonItem))
                             context:kJSQMessagesInputToolbarKeyValueObservingContext];

        [_contentView removeObserver:self
                          forKeyPath:NSStringFromSelector(@selector(rightBarButtonItem))
                             context:kJSQMessagesInputToolbarKeyValueObservingContext];
    }
    @catch (NSException *__unused exception) { }
    
    _jsq_isObserving = NO;
}

@end
