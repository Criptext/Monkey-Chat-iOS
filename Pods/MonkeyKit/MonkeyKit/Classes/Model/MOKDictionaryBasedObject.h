//
//  BLDictionaryBasedObject.h
//  Blip
//
//  Created by G V on 14.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MOKDictionaryBasedObject : NSObject {

}

- (int)integerFromDictionary:(NSDictionary*)dictionary key:(NSString*)key;
- (float)floatFromDictionary:(NSDictionary*)dictionary key:(NSString*)key;
- (BOOL)booleanFromDictionary:(NSDictionary*)dictionary key:(NSString*)key;
- (double)doubleFromDictionary:(NSDictionary*)dictionary key:(NSString*)key;
- (NSString*)stringFromDictionary:(NSDictionary*)dictionary key:(NSString*)key;
- (NSString*)stringIntFromDictionary:(NSDictionary*)dictionary key:(NSString*)key;
@end
