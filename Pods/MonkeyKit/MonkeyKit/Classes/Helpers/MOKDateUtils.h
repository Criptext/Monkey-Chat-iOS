//
//  DateUtils.h
//
//
//  Created by Y H on 12.10.10.
//  Copyright 2010 neoviso. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MOKDateUtils : NSObject {
	NSCalendar *gregorianCalendar;
	NSDate *today;
	NSDateFormatter *curentTimezoneFormatter;
}

@property (nonatomic,strong) NSCalendar *gregorianCalendar;
@property (nonatomic,strong) NSDate *today;

+ (MOKDateUtils*)instance;
- (NSDate*)stringToDate:(NSString*)dateString withFormat:(NSString*)format;
- (NSString*)dateToString:(NSDate*)date withFormat:(NSString*)format;
- (BOOL)date:(NSDate*)date1 sameWithDate:(NSDate*)date2;
- (NSString*)stringFromTimestamp:(NSTimeInterval)timestamp;
- (NSString*)stringFromTimestampConv1:(NSTimeInterval)timestamp;
- (NSString*)stringFromTimestampConv2:(NSTimeInterval)timestamp;
- (NSString*)stringFromTimestampConv3:(NSTimeInterval)timestamp;
- (NSString*)stringFromTimestampConv4:(NSTimeInterval)timestamp;
- (NSString*)stringFromTimestampConv5:(NSTimeInterval)timestamp;
- (NSString*)stringFromTimestampConv6:(NSTimeInterval)timestamp;
- (NSString*)dateToServerString:(NSDate*)date;
- (NSDate*)stringToServerDate:(NSString*)dateString;
- (void)reInit;

@end
