//
//  BLDictionaryBasedObject.m
//  Blip
//
//  Created by G V on 14.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MOKDictionaryBasedObject.h"


@implementation MOKDictionaryBasedObject

- (int)integerFromDictionary:(NSDictionary*)dictionary key:(NSString*)key {

	NSNumber *object = [dictionary objectForKey:key];

	if (object == nil) {
		return 0;
	}
	if (object == (NSNumber *)[NSNull null]) {
		return 0;
	} else {
		return [object intValue];
	}
}

- (long long)longFromDictionary:(NSDictionary*)dictionary key:(NSString*)key {
	NSNumber *object = [dictionary objectForKey:key];
	if (object == nil) {
		return 0;
	}
	if (object == (NSNumber *)[NSNull null]) {
		return 0;
	} else {
		return [object longLongValue];
	}
}

- (float)floatFromDictionary:(NSDictionary*)dictionary key:(NSString*)key {
	NSNumber *object = [dictionary objectForKey:key];
	if (object == nil) {
		return 0.0;
	}
	if (object == (NSNumber *)[NSNull null]) {
		return 0.0;
	} else {
		return [object floatValue];
	}
}

- (double)doubleFromDictionary:(NSDictionary*)dictionary key:(NSString*)key {
	NSNumber *object = [dictionary objectForKey:key];
	if (object == nil) {
		return 0.0;
	}
	if (object == (NSNumber *)[NSNull null]) {
		return 0.0;
	} else {
		return [object doubleValue];
	}
}

- (BOOL)booleanFromDictionary:(NSDictionary*)dictionary key:(NSString*)key {

	NSNumber *object = [dictionary objectForKey:key];
	if (object == nil) {
		return 0.0;
	}
	if (object == (NSNumber *)[NSNull null]) {
		return 0.0;
	} else {
		return [object boolValue];
	}
}

- (NSString*)stringFromDictionary:(NSDictionary*)dictionary key:(NSString*)key {

	NSString *object = [dictionary objectForKey:key];
	if (object == nil) {
		return @"";
	}
	if (object == (NSString *)[NSNull null]) {
		return @"";
	} else {
		if ([object respondsToSelector:@selector(stringValue)]) {
			return [(id)object stringValue];
		} else {
			return object;
		}
	}
}

- (NSString*)stringIntFromDictionary:(NSDictionary*)dictionary key:(NSString*)key {
	NSString *object = [dictionary objectForKey:key];
	if (object == nil) {
		return @"";
	}
	if (object == (NSString *)[NSNull null]) {
		return @"";
	} else {
		return [NSString stringWithFormat:@"%@", object];
	}
}

@end
