//
//  NSString+Random.m
//

#import "NSString+Random.h"

typedef enum : NSUInteger {
    HAYRandomStringTypeAlphaNumeric,
    HAYRandomStringTypeAlpha,
    HAYRandomStringTypeAny,
} HAYRandomStringType;

@implementation NSString (Random)

+ (NSString *)mok_randomAlphaNumericStringOfLength:(NSUInteger)length
{
    return [self mok_randomStringWithType:HAYRandomStringTypeAlphaNumeric length:length];
}

+ (NSString *)mok_randomAlphaStringOfLength:(NSUInteger)length
{
    return [self mok_randomStringWithType:HAYRandomStringTypeAlpha length:length];
}

+ (NSString *)mok_randomStringOfLength:(NSUInteger)length
{
    return [self mok_randomStringWithType:HAYRandomStringTypeAny length:length];
}

+ (NSString *)mok_randomStringWithType:(HAYRandomStringType)type length:(NSUInteger)length;
{
    NSString* baseCharacters = nil;
    
    switch (type)
    {
        case HAYRandomStringTypeAlpha:
            baseCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
            break;
        case HAYRandomStringTypeAlphaNumeric:
            baseCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            break;
        case HAYRandomStringTypeAny:
            baseCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&/()=?+<>-_,.[]{}@:;";
            break;
    }
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:length];
    
    for (NSUInteger i = 0; i < length; i++)
    {
        [randomString appendFormat:@"%C", [baseCharacters characterAtIndex:arc4random() % [baseCharacters length]]];
    }
    
    return randomString;
}

+ (NSString *)mok_UUID
{
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(nil, uuidObj);
    
    CFRelease(uuidObj);
    
    return uuidString;
}

@end