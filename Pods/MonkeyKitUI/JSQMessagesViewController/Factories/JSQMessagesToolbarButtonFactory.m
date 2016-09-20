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

#import "JSQMessagesToolbarButtonFactory.h"

#import "KSMManyOptionsButton.h"

#import "UIColor+JSQMessages.h"
#import "UIImage+JSQMessages.h"
#import "NSBundle+JSQMessages.h"


@implementation JSQMessagesToolbarButtonFactory

+ (UIButton *)defaultAccessoryButtonItem
{
    UIImage *accessoryImage = [UIImage jsq_defaultAccessoryImage];
    UIImage *normalImage = [accessoryImage jsq_imageMaskedWithColor:[UIColor lightGrayColor]];
    UIImage *highlightedImage = [accessoryImage jsq_imageMaskedWithColor:[UIColor darkGrayColor]];

    UIButton *accessoryButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, accessoryImage.size.width, 32.0f)];
    [accessoryButton setImage:normalImage forState:UIControlStateNormal];
    [accessoryButton setImage:highlightedImage forState:UIControlStateHighlighted];

    accessoryButton.contentMode = UIViewContentModeScaleAspectFit;
    accessoryButton.backgroundColor = [UIColor clearColor];
    accessoryButton.tintColor = [UIColor lightGrayColor];
    
    accessoryButton.accessibilityLabel = [NSBundle jsq_localizedStringForKey:@"accessory_button_accessibility_label"];

    return accessoryButton;
}

+ (UIButton *)defaultSendButtonItem
{
    NSString *sendTitle = [NSBundle jsq_localizedStringForKey:@"send"];

    UIButton *sendButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [sendButton setTitle:sendTitle forState:UIControlStateNormal];
    [sendButton setTitleColor:[UIColor jsq_messageBubbleBlueColor] forState:UIControlStateNormal];
    [sendButton setTitleColor:[[UIColor jsq_messageBubbleBlueColor] jsq_colorByDarkeningColorWithValue:0.1f] forState:UIControlStateHighlighted];
    [sendButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];

    sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    sendButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    sendButton.titleLabel.minimumScaleFactor = 0.85f;
    sendButton.contentMode = UIViewContentModeCenter;
    sendButton.backgroundColor = [UIColor clearColor];
    sendButton.tintColor = [UIColor jsq_messageBubbleBlueColor];

    CGFloat maxHeight = 32.0f;

    CGRect sendTitleRect = [sendTitle boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, maxHeight)
                                                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                attributes:@{ NSFontAttributeName : sendButton.titleLabel.font }
                                                   context:nil];

    sendButton.frame = CGRectMake(0.0f,
                                  0.0f,
                                  CGRectGetWidth(CGRectIntegral(sendTitleRect)),
                                  maxHeight);

    return sendButton;
}

+ (UIButton *)defaultOptionsButton{
    
    NSBundle *bundle = [NSBundle jsq_messagesAssetBundle];
    NSString *cancelImagePath = [bundle pathForResource:@"icon_thread_cancel" ofType:@"png" inDirectory:@"Images"];
    NSString *micImagePath = [bundle pathForResource:@"btn_mic_active" ofType:@"png" inDirectory:@"Images"];
    
    KSMManyOptionsButton *button = [[KSMManyOptionsButton alloc] initWithCenterText:[NSBundle jsq_localizedStringForKey:@"send"]
                                                                  centerButtonImage:[UIImage imageWithContentsOfFile:micImagePath]
                                                                    leftButtonImage:[UIImage imageWithContentsOfFile:cancelImagePath]
                                                                   rightButtonImage:nil
                                                                     topButtonImage:nil
                                                               andBottomButtonImage:nil];
    
    NSString *cancelHighlightedImagePath = [bundle pathForResource:@"icon_th_cancel_selected" ofType:@"png" inDirectory:@"Images"];
    button.highlightedLeftButtonImage = [UIImage imageWithContentsOfFile:cancelHighlightedImagePath];
    return button;
}

@end
