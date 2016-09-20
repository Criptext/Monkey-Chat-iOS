//
//  MOKCollectionViewCellIncoming.h
//  Criptext
//
//  Created by Gianni Carlo on 6/29/15.
//  Copyright (c) 2015 Criptext INC. All rights reserved.
//

#import "JSQMessagesCollectionViewCellIncoming.h"

@protocol JSQMessagesCollectionViewCellIncomingDelegate <NSObject>
-(void)openTextEfimero:(JSQMessagesCollectionViewCellIncoming *)cell;
@end

@interface JSQMessagesCollectionViewCellIncoming2 : JSQMessagesCollectionViewCellIncoming
@property (weak, nonatomic) id<JSQMessagesCollectionViewCellIncomingDelegate>criptextDelegate;
@property (nonatomic, strong) NSTimer *timerEfimero;
@property (weak, nonatomic) IBOutlet UIButton *privateTapButton;
@property (weak, nonatomic) IBOutlet UILabel *horaDelMensaje;
@property (weak, nonatomic) IBOutlet UILabel *protectedLabel;

-(void)cellHandlePan:(UIGestureRecognizer *)recognizer;
@end
