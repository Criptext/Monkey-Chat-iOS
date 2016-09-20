//
//  JSQMessagesActivityIndicatorHeaderView.h
//  JSQMessages
//
//  Created by Gianni Carlo on 8/5/16.
//  Copyright © 2016 Hexed Bits. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JSQMessagesActivityIndicatorHeaderView : UICollectionReusableView

#pragma mark - Class methods

/**
 *  Returns the `UINib` object initialized for the collection reusable view.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during
 *  initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 *  Returns the default string used to identify the reusable header view.
 *
 *  @return The string used to identify the reusable header view.
 */
+ (NSString *)headerReuseIdentifier;
@end
