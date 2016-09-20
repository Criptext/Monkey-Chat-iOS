//
//  CriptextCollectionViewCellOutgoing.h
//  Criptext
//
//  Created by Gianni Carlo on 6/29/15.
//  Copyright (c) 2015 Criptext INC. All rights reserved.
//

#import "JSQMessagesCollectionViewCellOutgoing.h"

@protocol JSQMessagesCollectionViewCellOutgoingDelegate <NSObject>
-(void)createActionSheetResend:(JSQMessagesCollectionViewCellOutgoing *)cell;
@end

@interface JSQMessagesCollectionViewCellOutgoing2 : JSQMessagesCollectionViewCellOutgoing
@property (weak, nonatomic) id<JSQMessagesCollectionViewCellOutgoingDelegate>criptextDelegate;
@property (weak, nonatomic) IBOutlet UIButton *resendButton;
@property (weak, nonatomic) IBOutlet UIView *privateLabelContainer;
@property (weak, nonatomic) IBOutlet UILabel *privateLabelMessage;
@property (weak, nonatomic) IBOutlet UILabel *horaDelMensaje;
@property (weak, nonatomic) IBOutlet UIImageView *messageLoadingImageView;
@property BOOL shouldAnimate;
@property BOOL isAnimating;

-(void)startAnimating;
-(void)stopAnimating;
-(void)cellHandlePan:(UIGestureRecognizer *)recognizer;

@end