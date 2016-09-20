//
//  CriptextCollectionViewCellOutgoing.m
//  Criptext
//
//  Created by Gianni Carlo on 6/29/15.
//  Copyright (c) 2015 Criptext INC. All rights reserved.
//

#import "JSQMessagesCollectionViewCellOutgoing2.h"

@interface JSQMessagesCollectionViewCellOutgoing2()
@property CGPoint originalCenterBurbuja;
@property CGPoint originalCenterHora;
@property CGPoint originalCenterStatus;
@property CGPoint originalCenterMedia;
@property CGPoint originalCenterResend;
@property CGRect originalFrameMedia;

@end

@implementation JSQMessagesCollectionViewCellOutgoing2

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.messageBubbleTopLabel.textAlignment = NSTextAlignmentRight;
    self.cellBottomLabel.textAlignment = NSTextAlignmentRight;
    self.privateLabelMessage.text = NSLocalizedString(@"privateMessage", @"");
    self.isAnimating = false;
    self.messageLoadingImageView.hidden = true;
}

-(void)cellHandlePan:(UIPanGestureRecognizer *)recognizer{
    
    // 1
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        // if the gesture has just started, record the current centre location
        self.originalCenterBurbuja = self.messageBubbleContainerView.center;
        self.originalCenterMedia = self.mediaView.center;
        self.originalCenterHora = self.horaDelMensaje.center;
        self.originalCenterStatus = self.avatarContainerView.center;
        self.originalCenterResend= self.resendButton.center;
        
        self.horaDelMensaje.alpha = 0.0;
    }
    // 2
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        // translate the center
        CGPoint translation = [recognizer translationInView:self.messageBubbleContainerView];
        if(translation.x<0 && translation.x>=-60){
            self.messageBubbleContainerView.center = CGPointMake(self.originalCenterBurbuja.x + translation.x, self.originalCenterBurbuja.y);
            
            self.horaDelMensaje.center = CGPointMake(self.originalCenterHora.x + translation.x, self.originalCenterHora.y);
            self.avatarContainerView.center = CGPointMake(self.originalCenterStatus.x+ translation.x, self.originalCenterStatus.y);
            
            self.resendButton.center = CGPointMake(self.originalCenterResend.x + translation.x, self.originalCenterResend.y);
        }
        else if(translation.x<0){
            self.messageBubbleContainerView.center = CGPointMake(self.originalCenterBurbuja.x -60, self.originalCenterBurbuja.y);
            
            self.horaDelMensaje.center = CGPointMake(self.originalCenterHora.x - 60, self.originalCenterHora.y);
            self.avatarContainerView.center = CGPointMake(self.originalCenterStatus.x -60, self.originalCenterStatus.y);
            
            self.resendButton.center = CGPointMake(self.originalCenterResend.x - 60, self.originalCenterResend.y);
        }
        
        if(translation.x<0 && translation.x>=0){
            self.mediaView.center = CGPointMake(self.originalCenterMedia.x + translation.x, self.originalCenterMedia.y);
        }
        else if(translation.x<0){
            self.mediaView.center = CGPointMake(self.originalCenterMedia.x, self.originalCenterMedia.y);
        }
        
        if (translation.x>-100) {
            self.horaDelMensaje.alpha = translation.x / (-100);
        }
        
    }
    // 3
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        // the frame this cell would have had before being dragged
        
        CGRect originalFrameBurbuja = CGRectMake(self.originalCenterBurbuja.x-(self.messageBubbleContainerView.bounds.size.width/2), self.originalCenterBurbuja.y-(self.messageBubbleContainerView.bounds.size.height/2),self.messageBubbleContainerView.bounds.size.width, self.messageBubbleContainerView.bounds.size.height);
        CGRect originalFrameHora = CGRectMake(self.originalCenterHora.x-(self.horaDelMensaje.bounds.size.width/2),self.originalCenterHora.y-(self.horaDelMensaje.bounds.size.height/2), self.horaDelMensaje.bounds.size.width, self.horaDelMensaje.bounds.size.height);
        
        CGRect originalFrameStatus = CGRectMake(self.originalCenterStatus.x-(self.avatarContainerView.bounds.size.width/2),self.originalCenterStatus.y-(self.avatarContainerView.bounds.size.height/2), self.avatarContainerView.bounds.size.width, self.avatarContainerView.bounds.size.height);
        
        CGRect originalFrameError = CGRectMake(self.originalCenterResend.x-(self.resendButton.bounds.size.width/2),self.originalCenterResend.y-(self.resendButton.bounds.size.height/2), self.resendButton.bounds.size.width, self.resendButton.bounds.size.height);
        
        [UIView animateWithDuration:0.2 animations:^{
            if(originalFrameHora.origin.x>0 && originalFrameBurbuja.origin.x>0){
                self.messageBubbleContainerView.frame = originalFrameBurbuja;
                self.horaDelMensaje.frame = originalFrameHora;
                self.avatarContainerView.frame = originalFrameStatus;
                self.resendButton.frame = originalFrameError;
            }
        }];
        
    }
    
}
- (IBAction)didPressResend:(id)sender {
    if ([self.criptextDelegate respondsToSelector:@selector(createActionSheetResend:)]) {
        [self.criptextDelegate createActionSheetResend:self];
    }
}

-(void)startAnimating{
    self.shouldAnimate = true;
    self.messageLoadingImageView.hidden = true;
    
}

-(void)rotateView{
        [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.messageLoadingImageView.hidden = false;
            self.messageLoadingImageView.transform = CGAffineTransformRotate(self.messageLoadingImageView.transform, M_PI);
        }completion:nil];
}

-(void)stopAnimating{
    self.messageLoadingImageView.hidden = true;
    self.shouldAnimate = false;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return YES;
}
@end
