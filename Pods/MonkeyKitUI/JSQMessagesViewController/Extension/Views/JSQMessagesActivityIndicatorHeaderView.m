//
//  JSQMessagesActivityIndicatorHeaderView.m
//  JSQMessages
//
//  Created by Gianni Carlo on 8/5/16.
//  Copyright © 2016 Hexed Bits. All rights reserved.
//

#import "JSQMessagesActivityIndicatorHeaderView.h"
#import "JSQMessagesLoadEarlierHeaderView.h"
#import "NSBundle+JSQMessages.h"

@interface JSQMessagesActivityIndicatorHeaderView ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;

@end

@implementation JSQMessagesActivityIndicatorHeaderView
#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([JSQMessagesActivityIndicatorHeaderView class])
                          bundle:[NSBundle bundleForClass:[JSQMessagesActivityIndicatorHeaderView class]]];
}

+ (NSString *)headerReuseIdentifier
{
    return NSStringFromClass([JSQMessagesActivityIndicatorHeaderView class]);
}

#pragma mark - Initialization

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    self.backgroundColor = [UIColor clearColor];
}

- (void)dealloc
{
    _activityIndicatorView = nil;
}

#pragma mark - Reusable view

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    self.activityIndicatorView.backgroundColor = backgroundColor;
}

@end
