//
//  DateUtils.m
//  8coupons
//
//  Created by Y H on 12.10.10.
//  Copyright 2010 neoviso. All rights reserved.
//

#import "MOKDateUtils.h"

@implementation MOKDateUtils
@synthesize gregorianCalendar, today;
static MOKDateUtils *dateUtilsInstance = nil;

+ (MOKDateUtils*)instance {
	if (dateUtilsInstance == nil) {
		dateUtilsInstance = [[MOKDateUtils alloc] init];
	}
	return dateUtilsInstance;
}

static NSString *dateTimeFormat = @"MM/dd/yyyy hh:mm:ssaa";
static NSString *dateTimeConv1Format = @"MM/dd/yyyy";
static NSString *dateTimeConv2Format = @"EEEE";
static NSString *dateTimeConv3Format = @"hh:mm aa";//MMMM dd
static NSString *dateTimeConv4Format = @"dd-MM-yyyy";
static NSString *dateTimeConv5Format = @"MMM d, yyyy hh:mm aa";
static NSString *dateTimeConv6Format = @"HH:mm";
static NSString *serverDateFormat = @"yyyy-MM-dd";

- (void)reInit {
	curentTimezoneFormatter = [[NSDateFormatter alloc] init];
	[curentTimezoneFormatter setDateFormat:dateTimeFormat];
	
}

- (id)init {
	if (self = [super init]) {
		self.gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
//		self.gregorianCalendar;
		[self reInit];
	}
	return self;
}

- (NSString*)dateToString:(NSDate*)date withFormat:(NSString*)format {
	NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
	[dateFormat setDateFormat:format];
	NSString *theDate = [dateFormat stringFromDate:date];
	return theDate;
}

- (NSString*)dateToServerString:(NSDate*)date {
	NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
	[dateFormat setDateFormat:serverDateFormat];
	NSString *theDate = [dateFormat stringFromDate:date];
	return theDate;
}
- (NSDate*)stringToServerDate:(NSString*)dateString {
	[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:serverDateFormat];
	NSDate *theDate = [dateFormatter dateFromString:dateString];
	return theDate;
}

- (NSDate*)stringToDate:(NSString*)dateString withFormat:(NSString*)format {
	[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
	NSDate *theDate = [dateFormatter dateFromString:dateString];
	return theDate;
}

- (BOOL)date:(NSDate*)date1 sameWithDate:(NSDate*)date2 {
	unsigned units = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay;
	NSDateComponents *comps1 = [gregorianCalendar components:units fromDate:date1];
	NSDateComponents *comps2 = [gregorianCalendar components:units fromDate:date2];
	return comps1.day == comps2.day && comps1.month == comps2.month && comps1.year == comps2.year;
}



- (NSString*)stringFromTimestamp:(NSTimeInterval)timestamp {
	NSString *result;
	NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
	[curentTimezoneFormatter setDateFormat:dateTimeFormat];
	result = [curentTimezoneFormatter stringFromDate:date];
	return result;
}

- (NSString*)stringFromTimestampConv1:(NSTimeInterval)timestamp {
	NSString *result;
	NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
	[curentTimezoneFormatter setDateFormat:dateTimeConv1Format];
	result = [curentTimezoneFormatter stringFromDate:date];
	return result;
}

- (NSString*)stringFromTimestampConv2:(NSTimeInterval)timestamp {
	NSString *result;
	NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
	[curentTimezoneFormatter setDateFormat:dateTimeConv2Format];
	result = [curentTimezoneFormatter stringFromDate:date];
	return result;
}

- (NSString*)stringFromTimestampConv3:(NSTimeInterval)timestamp {
	NSString *result;
	NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
	[curentTimezoneFormatter setDateFormat:dateTimeConv3Format];
	result = [curentTimezoneFormatter stringFromDate:date];
	return result;
}

- (NSString*)stringFromTimestampConv4:(NSTimeInterval)timestamp {
	NSString *result;
	NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
	[curentTimezoneFormatter setDateFormat:dateTimeConv4Format];
	result = [curentTimezoneFormatter stringFromDate:date];
	return result;
}

- (NSString*)stringFromTimestampConv5:(NSTimeInterval)timestamp {
	NSString *result;
	NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
	[curentTimezoneFormatter setDateFormat:dateTimeConv5Format];
	result = [curentTimezoneFormatter stringFromDate:date];
	return result;
}

- (NSString*)stringFromTimestampConv6:(NSTimeInterval)timestamp {
    NSString *result;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
    [curentTimezoneFormatter setDateFormat:dateTimeConv6Format];
    result = [curentTimezoneFormatter stringFromDate:date];
    return result;
}


@end
