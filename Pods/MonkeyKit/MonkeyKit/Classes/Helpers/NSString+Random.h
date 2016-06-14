//
//  NSString+Random.h
//

@import Foundation;

@interface NSString (Random)

/*!
 *  Returns random alpha-numeric string
 *
 *  @param length of string
 *
 *  @return random string
 */
+ (NSString *)mok_randomAlphaNumericStringOfLength:(NSUInteger)length;

/*!
 *  Returns random alpha string (no numbers)
 *
 *  @param length of string
 *
 *  @return random string
 */
+ (NSString *)mok_randomAlphaStringOfLength:(NSUInteger)length;

/*!
 *  Returns random string that can contain all ASCII characters
 *
 *  @param length of string
 *
 *  @return random string
 */
+ (NSString *)mok_randomStringOfLength:(NSUInteger)length;

/*!
 *  Returns random new UUID
 *
 *  @return random UUID
 */
+ (NSString *)mok_UUID;

@end