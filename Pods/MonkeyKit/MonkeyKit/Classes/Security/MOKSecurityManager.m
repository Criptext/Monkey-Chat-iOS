//
//  KeychainManager.m
//  Criptext
//
//  Created by Gianni Carlo on 1/28/15.
//  Copyright (c) 2015 Nicolas VERINAUD. All rights reserved.
//

#import "MOKSecurityManager.h"
#import "UICKeyChainStore.h"
#import "NSData+Base64.h"
#import "NSData+Conversion.h"
#import "BBAES.h"
#import "MOKMessage.h"

#import <CommonCrypto/CommonCrypto.h>

#define AUTHENTICATION_PUBKEY   @"authentication_pubKey"
#define SYNC_PUBKEY   @"mok_sync_pubKey"
#define SYNC_PRIVKEY   @"mok_sync_privKey"
#define MY_AESKEY      @"myAESKey"
#define MY_IV			@"myIV"

const size_t kSecAttrKeySizeInBitsLength = 2048;
const NSUInteger kCryptoExportImportManagerASNHeaderLengthForRSA = 15;
const UInt8 kCryptoExportImportManagerASNHeaderSequenceMark = 48; // 0x30
const NSUInteger kCryptoExportImportManagerRSAOIDHeaderLength = 15;
const UInt8 kCryptoExportImportManagerExtendedLengthMark = 128;  // 0x80
const UInt8 kCryptoExportImportManagerASNHeaderBitstringMark = 03; //0x03
// RSA OID header
const unsigned char kCryptoExportImportManagerRSAOIDHeader[15] = {0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00};
const NSUInteger kCryptoExportImportManagerPublicNumberOfCharactersInALine = 64;
NSString *kCryptoExportImportManagerPublicKeyInitialTag = @"-----BEGIN PUBLIC KEY-----\n";
NSString *kCryptoExportImportManagerPublicKeyFinalTag = @"-----END PUBLIC KEY-----";
@interface MOKSecurityManager ()

@property (strong, nonatomic) UICKeyChainStore *keychainStore;
@property (strong, nonatomic) NSMutableDictionary *loadedKeys;
@property (nonatomic,readonly) SecKeyRef publicKeyRef;
@property (nonatomic,readonly) SecKeyRef privateKeyRef;
@property (nonatomic,readonly) NSData * publicTag;
@property (nonatomic,readonly) NSData * privateTag;
@end

@implementation MOKSecurityManager

#pragma mark initialization
static MOKSecurityManager *securityManagerInstance = nil;
+ (instancetype)sharedInstance
{
    
    @synchronized(securityManagerInstance) {
        if (securityManagerInstance == nil) {
            securityManagerInstance = [[self alloc] initPrivate];
        }
        
        return securityManagerInstance;
    }
    
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use [MOKSecurityManager sharedInstance]"
                                 userInfo:nil];
    return nil;
}

- (void)deleteAsymmetricKeys {
    
    OSStatus sanityCheck = noErr;
    NSMutableDictionary * queryPublicKey        = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableDictionary * queryPrivateKey       = [NSMutableDictionary dictionaryWithCapacity:0];
    
    // Set the public key query dictionary.
    [queryPublicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    [queryPublicKey setObject:_publicTag forKey:(__bridge id)kSecAttrApplicationTag];
    [queryPublicKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    
    // Set the private key query dictionary.
    [queryPrivateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    [queryPrivateKey setObject:_privateTag forKey:(__bridge id)kSecAttrApplicationTag];
    [queryPrivateKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    
    // Delete the private key.
    sanityCheck = SecItemDelete((__bridge CFDictionaryRef)queryPrivateKey);
    NSAssert1( sanityCheck == noErr || sanityCheck == errSecItemNotFound, @"Error removing private key, OSStatus == %ld.", (long)sanityCheck );
    
    // Delete the public key.
    sanityCheck = SecItemDelete((__bridge CFDictionaryRef)queryPublicKey);
    NSAssert1( sanityCheck == noErr || sanityCheck == errSecItemNotFound, @"Error removing public key, OSStatus == %ld.", (long)sanityCheck );
    
    if (_publicKeyRef) CFRelease(_publicKeyRef);
    if (_privateKeyRef) CFRelease(_privateKeyRef);
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        _keychainStore = [UICKeyChainStore keyChainStoreWithService:@"com.criptextkit.app"];
        _publicTag = [SYNC_PUBKEY dataUsingEncoding:NSUTF8StringEncoding];
        _privateTag = [SYNC_PRIVKEY dataUsingEncoding:NSUTF8StringEncoding];
        //        RSA *rsaKeyPair = NULL;
        //        //        EVP_PKEY *PrivateKey = NULL;
        //        rsaKeyPair = RSA_new();
        //
        //        BIGNUM *e = NULL;
        //        e = BN_new();
        //        BN_set_word(e, 5);
        //
        //        //Generating KeyPair
        //        RSA_generate_key_ex(rsaKeyPair, 2048, e, NULL);
        //
        //        //        PrivateKey = EVP_PKEY_new();
        //
        //        BIO *pri = BIO_new(BIO_s_mem());
        //        BIO *pub = BIO_new(BIO_s_mem());
        //
        //
        //        PEM_write_bio_RSAPrivateKey(pri, rsaKeyPair, NULL, NULL, 0, NULL, NULL);
        //        PEM_write_bio_RSAPublicKey(pub, rsaKeyPair);
        //
        //        size_t pri_len = BIO_pending(pri);
        //        size_t pub_len = BIO_pending(pub);
        //
        //        char *pri_key = malloc(pri_len+1);
        //        char *pub_key = malloc(pub_len+1);
        //
        //        BIO_read(pri, pri_key, pri_len);
        //        BIO_read(pub, pub_key, pub_len);
        //
        //        pri_key[pri_len] = '\0';
        //        pub_key[pub_len] = '\0';
        //
        //        NSString *PK = [[[NSString stringWithFormat:@"%s",pri_key] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
        //        PK = [NSString stringWithUTF8String:pri_key];
        //
        //        NSString *PKK = [[[NSString stringWithFormat:@"%s",pub_key] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
        //        PKK = [NSString stringWithUTF8String:pub_key];
        //        PKK = [[PKK stringByReplacingOccurrencesOfString:@" RSA" withString:@""] stringByReplacingOccurrencesOfString:@"=" withString:@""];
        //
        //
        //        EVP_PKEY* pkey = EVP_PKEY_new();
        //
        //        int rc = EVP_PKEY_set1_RSA(pkey, rsaKeyPair);
        //        //        EVP_PKEY_free(pkey);
        //
        //        BIO *pub2 = BIO_new(BIO_s_mem());
        //
        //        PEM_write_bio_PUBKEY(pub2, pkey);
        //
        //        size_t pub_len2 = BIO_pending(pub2);
        //        char *pub_key2 = malloc(pub_len2+1);
        //
        //        BIO_read(pub2, pub_key2, pub_len2);
        //
        //        pub_key2[pub_len2] = '\0';
        //
        //        [self storeObject:[NSString stringWithUTF8String:pub_key2] withIdentifier:SYNC_PUBKEY];
        //        [self storeObject:PK withIdentifier:SYNC_PRIVKEY];
        
        [self generateKeyPairRSA];
    }
    return self;
}
-(void)logout{
    @synchronized(securityManagerInstance) {
        securityManagerInstance = nil;
    }
}

#pragma mark - Keychain Services
-(BOOL)storeObject:(NSString *)key withIdentifier:(NSString *)identifier{
    NSError *error;
    [self.keychainStore setString:key forKey:identifier error:&error];
    
    if (error) {
        NSLog(@"MONKEY - %@", error.localizedDescription);
        return false;
    }
    return true;
}

-(NSString *)getObjectForIdentifier:(NSString *)identifier{
    return self.keychainStore[identifier];
}

-(NSString *)getKeyAsBase64ForIdentifier:(NSString *)identifier{
    return self.keychainStore[identifier];
}
//
-(BOOL)storeAESKey:(NSData *)aesKey withIdentifier:(NSString *)identifier{
    NSError *error;
    [aesKey base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    [self.keychainStore setString:[aesKey mok_base64EncodedString] forKey:identifier error:&error];
    if (error) {
        NSLog(@"MONKEY - %@", error.localizedDescription);
        return false;
    }
    return true;
}

-(NSData *)getAESKeyForIdentifier:(NSString *)identifier{
    return [NSData mok_dataFromBase64String:self.keychainStore[identifier]];
}

-(NSString *)getIVbase64forUser:(NSString *)userId{
    NSString *aesAndiv = self.keychainStore[userId];
    NSArray *arrays = [aesAndiv componentsSeparatedByString:@":"];
#ifdef DEBUG
    NSLog(@"MONKEY - el iv: %@test", [arrays lastObject]);
#endif
    
    return [arrays lastObject];
}

-(NSString *)getAESbase64forUser:(NSString *)userId{
    NSString *aesandiv = self.keychainStore[userId];
#ifdef DEBUG
    NSLog(@"MONKEY - sacando el aes iv concatenado: %@ for sessionid: %@", aesandiv, userId);
#endif
    NSArray *array = [aesandiv componentsSeparatedByString:@":"];
    return [array firstObject];
}
//
-(BOOL)storeNSData:(NSData *)data withIdentifier:(NSString *)identifier{
    NSError *error;
    [self.keychainStore setString:[data mok_base64EncodedString] forKey:identifier error:&error];
    if (error) {
        NSLog(@"MONKEY - %@", error.localizedDescription);
        return false;
    }
    return true;
}

-(NSData *)getNSDataForIdentifier:(NSString *)identifier{
    return [NSData mok_dataFromBase64String:self.keychainStore[identifier]];
}


//
-(BOOL)storeIV:(NSData *)iv withIdentifier:(NSString *)identifier{
    NSError *error;
    [self.keychainStore setString:[iv mok_base64EncodedString] forKey:identifier error:&error];
    if (error) {
        NSLog(@"MONKEY - %@", error.localizedDescription);
        return false;
    }
    return true;
}

-(NSData *)getIV:(NSString *)identifier{
    return [NSData mok_dataFromBase64String:self.keychainStore[identifier]];
}


#pragma mark - RSA encryption

size_t encodeLength(unsigned char * buf, size_t length) {
    
    // encode length in ASN.1 DER format
    if (length < 128) {
        buf[0] = length;
        return 1;
    }
    
    size_t i = (length / 256) + 1;
    buf[0] = i + 0x80;
    for (size_t j = 0 ; j < i; ++j) {
        buf[i - j] = length & 0xFF;
        length = length >> 8;
    }
    
    return i + 1;
}
/**
 * Returns the number of bytes needed to represent an integer.
 */
int bytesNeededForRepresentingInteger(int number) {
    if (number <= 0) { return 0; }
    int i = 1;
    while (i < 8 && number >= (1 << (i * 8))) { i++; }
    return i;
}

/**
 * Generates an ASN.1 length sequence for the given length. Modifies the buffer parameter by
 * writing the ASN.1 sequence. The memory of buffer must be initialized (i.e: from an NSData).
 * Returns the number of bytes used to write the sequence.
 */
int encodeASN1LengthParameter(int length, char* buffer) {
    if (length < kCryptoExportImportManagerExtendedLengthMark) {
        buffer[0] = (UInt8)length;
        return 1; // just one byte was used, no need for length starting mark (0x80).
    } else {
        int extraBytes = bytesNeededForRepresentingInteger(length);
        int currentLengthValue = length;
        
        buffer[0] = kCryptoExportImportManagerExtendedLengthMark + (UInt8)extraBytes;
        for (int i = 0; i < extraBytes; i++) {
            buffer[extraBytes - i] = (UInt8)currentLengthValue & 0xff;
            currentLengthValue = currentLengthValue >> 8;
        }
        return extraBytes + 1; // 1 byte for the starting mark (0x80 + bytes used) + bytes used to encode length.
    }
}

/**
 * This method transforms a DER encoded key to PEM format. It gets a Base64 representation of
 * the key and then splits this base64 string in 64 character chunks. Then it wraps it in
 * BEGIN and END key tags.
 */
-(NSString *) PEMKeyFromDERKey:(NSData *)data {
    // base64 encode the result
    NSString *base64EncodedString = [data base64EncodedStringWithOptions:0];
    
    // split in lines of 64 characters.
    NSMutableString *currentLine = [@"" mutableCopy];
    NSMutableString *resultString = [kCryptoExportImportManagerPublicKeyInitialTag mutableCopy];
    int charCount = 0;
    
    for(NSUInteger i =0 ;i<[base64EncodedString length]; i++) {
        char character = [base64EncodedString characterAtIndex:i];
        charCount++;
        [currentLine appendFormat:@"%c", character];
        
        if (charCount == kCryptoExportImportManagerPublicNumberOfCharactersInALine) {
            [resultString appendString:currentLine];
            [resultString appendString:@"\n"];
            charCount = 0;
            currentLine = [@"" mutableCopy];
        }
    }
    
    // final line (if any)
    if (currentLine.length > 0) {
        [resultString appendString:currentLine];
        [resultString appendString:@"\n"];
    }
    // final tag
    [resultString appendString:kCryptoExportImportManagerPublicKeyFinalTag];
    
    return resultString;
}

-(NSData *) exportRSAPublicKeyToDER:(NSData *)rawPublicKeyBytes keyType:(NSString *)keyType keySize:(int)keySize {
    // first we create the space for the ASN.1 header and decide about its length
    NSMutableData *headerData = [[NSMutableData alloc] initWithLength:kCryptoExportImportManagerASNHeaderLengthForRSA];
    
    int bitstringEncodingLength = bytesNeededForRepresentingInteger((int)rawPublicKeyBytes.length);
    // start building the ASN.1 header
    char* headerBuffer = headerData.mutableBytes;
    
    headerBuffer[0] = kCryptoExportImportManagerASNHeaderSequenceMark; // sequence start
    
    // total size (OID + encoding + key size) + 2 (marks)
    int totalSize = (int)kCryptoExportImportManagerRSAOIDHeaderLength + bitstringEncodingLength + (int)rawPublicKeyBytes.length + 3;
    int totalSizebitstringEncodingLength = encodeASN1LengthParameter(totalSize, &(headerBuffer[1]));
    
    // bitstring header
    NSMutableData *bitstringData = [[NSMutableData alloc] initWithLength:kCryptoExportImportManagerASNHeaderLengthForRSA];
    char* bitstringBuffer = bitstringData.mutableBytes;
    bitstringBuffer[0] = kCryptoExportImportManagerASNHeaderBitstringMark; // key length mark
    int keyLengthBytesEncoded = encodeASN1LengthParameter((int)rawPublicKeyBytes.length+1, &(bitstringBuffer[1]));
    bitstringBuffer[keyLengthBytesEncoded + 1] = 0x00;
    
    // build DER key.
    NSMutableData *derKey = [[NSMutableData alloc] initWithCapacity:(totalSize + totalSizebitstringEncodingLength)];
    [derKey appendBytes:headerBuffer length:(totalSizebitstringEncodingLength + 1)]; // add sequence and total size
    [derKey appendBytes:kCryptoExportImportManagerRSAOIDHeader length:kCryptoExportImportManagerRSAOIDHeaderLength]; // Add OID header
    [derKey appendBytes:bitstringBuffer length:(keyLengthBytesEncoded + 2)]; // 0x03 + key bitstring length + 0x00
    [derKey appendData:rawPublicKeyBytes]; // public key raw data.
    
    return derKey;
}

- (NSString *)getKeyForJavaServer:(NSData*)keyBits {
    
    static const unsigned char _encodedRSAEncryptionOID[15] = {
        
        /* Sequence of length 0xd made up of OID followed by NULL */
        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        
    };
    
    // That gives us the "BITSTRING component of a full DER
    // encoded RSA public key - We now need to build the rest
    
    unsigned char builder[15];
    NSMutableData * encKey = [[NSMutableData alloc] init];
    int bitstringEncLength;
    
    // When we get to the bitstring - how will we encode it?
    
    if  ([keyBits length ] + 1  < 128 )
        bitstringEncLength = 1 ;
    else
        bitstringEncLength = (int)(([keyBits length ] +1 ) / 256 ) + 2 ;
    
    // Overall we have a sequence of a certain length
    builder[0] = 0x30;    // ASN.1 encoding representing a SEQUENCE
    // Build up overall size made up of -
    // size of OID + size of bitstring encoding + size of actual key
    size_t i = sizeof(_encodedRSAEncryptionOID) + 2 + bitstringEncLength +
    [keyBits length];
    size_t j = encodeLength(&builder[1], i);
    [encKey appendBytes:builder length:j +1];
    
    // First part of the sequence is the OID
    [encKey appendBytes:_encodedRSAEncryptionOID
                 length:sizeof(_encodedRSAEncryptionOID)];
    
    // Now add the bitstring
    builder[0] = 0x03;
    j = encodeLength(&builder[1], [keyBits length] + 1);
    builder[j+1] = 0x00;
    [encKey appendBytes:builder length:j + 2];
    
    // Now the actual key
    [encKey appendData:keyBits];
    
    // base64 encode encKey and return
    return [encKey base64EncodedStringWithOptions:0];
    
}

- (NSData *)readKeyBits:(NSData *)tag keyType:(CFTypeRef)keyType {
    
    OSStatus sanityCheck = noErr;
    CFTypeRef  _publicKeyBitsReference = NULL;
    
    NSMutableDictionary * queryPublicKey = [NSMutableDictionary dictionaryWithCapacity:0];
    
    // Set the public key query dictionary.
    [queryPublicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    [queryPublicKey setObject:tag forKey:(__bridge id)kSecAttrApplicationTag];
    [queryPublicKey setObject:(__bridge id)keyType forKey:(__bridge id)kSecAttrKeyType];
    [queryPublicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnData];
    
    // Get the key bits.
    sanityCheck = SecItemCopyMatching((__bridge CFDictionaryRef)queryPublicKey, (CFTypeRef *)&_publicKeyBitsReference);
    
    if (sanityCheck != noErr) {
        _publicKeyBitsReference = NULL;
    }
    
    _publicKeyRef = (SecKeyRef)_publicKeyBitsReference;
    
    return (__bridge NSData*)_publicKeyBitsReference;
    
}

-(NSString *)exportPublicKeyRSA {
    NSData *pKeyData = [self readKeyBits:_publicTag keyType:kSecAttrKeyTypeRSA];
    
    NSString *exportablePEMKey = [self PEMKeyFromDERKey:[self exportRSAPublicKeyToDER:pKeyData keyType:(NSString *)kSecAttrKeyTypeRSA keySize:kSecAttrKeySizeInBitsLength]];
    
    return exportablePEMKey;
}

- (void)generateKeyPairRSA {
    OSStatus sanityCheck = noErr;
    _publicKeyRef = NULL;
    _privateKeyRef = NULL;
    
    // First delete current keys.
    @try {
        [self deleteAsymmetricKeys];
    } @catch (NSException *exception) {
        NSLog(@"Monkey - No previous rsa keys generated");
    }
    
    // Container dictionaries.
    NSMutableDictionary * privateKeyAttr = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableDictionary * publicKeyAttr = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableDictionary * keyPairAttr = [NSMutableDictionary dictionaryWithCapacity:0];
    
    // Set top level dictionary for the keypair.
    [keyPairAttr setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [keyPairAttr setObject:[NSNumber numberWithUnsignedInteger:kSecAttrKeySizeInBitsLength] forKey:(__bridge id)kSecAttrKeySizeInBits];
    
    // Set the private key dictionary.
    [privateKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecAttrIsPermanent];
    [privateKeyAttr setObject:_privateTag forKey:(__bridge id)kSecAttrApplicationTag];
    // See SecKey.h to set other flag values.
    
    // Set the public key dictionary.
    [publicKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecAttrIsPermanent];
    [publicKeyAttr setObject:_publicTag forKey:(__bridge id)kSecAttrApplicationTag];
    // See SecKey.h to set other flag values.
    
    // Set attributes to top level dictionary.
    [keyPairAttr setObject:privateKeyAttr forKey:(__bridge id)kSecPrivateKeyAttrs];
    [keyPairAttr setObject:publicKeyAttr forKey:(__bridge id)kSecPublicKeyAttrs];
    
    // SecKeyGeneratePair returns the SecKeyRefs just for educational purposes.
    sanityCheck = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &_publicKeyRef, &_privateKeyRef);
    NSAssert( sanityCheck == noErr && _publicKeyRef != NULL && _privateKeyRef != NULL, @"Something really bad went wrong with generating the key pair." );
}

#pragma mark - Encrypt and Decrypt
- (NSString *)rsaEncryptString:(NSString *)plainString{
    NSData *data = [self rsaEncryptData:[plainString dataUsingEncoding:NSUTF8StringEncoding] withKeyRef:self.publicKeyRef];
    
    data = [data base64EncodedDataWithOptions:0];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSString *)rsaDecryptString:(NSString *)encryptedString{
    NSData *data = [NSData mok_dataFromBase64String:encryptedString];
    data = [self rsaDecryptData:data withKeyRef:self.privateKeyRef];
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];;
}

- (NSData *)rsaEncryptData:(NSData *)data publicKey:(NSString *)pubKey{
    if(!data || !pubKey){
        return nil;
    }
    SecKeyRef keyRef = [self addPublicKey:pubKey];
    if(!keyRef){
        return nil;
    }
    return [self rsaEncryptData:data withKeyRef:keyRef];
}

- (NSData *)stripPublicKeyHeader:(NSData *)d_key{
    // Skip ASN.1 public key header
    if (d_key == nil) return(nil);
    
    unsigned long len = [d_key length];
    if (!len) return(nil);
    
    unsigned char *c_key = (unsigned char *)[d_key bytes];
    unsigned int  idx	 = 0;
    
    if (c_key[idx++] != 0x30) return(nil);
    
    if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    // PKCS #1 rsaEncryption szOID_RSA_RSA
    static unsigned char seqiod[] =
    { 0x30,   0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
        0x01, 0x05, 0x00 };
    if (memcmp(&c_key[idx], seqiod, 15)) return(nil);
    
    idx += 15;
    
    if (c_key[idx++] != 0x03) return(nil);
    
    if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    if (c_key[idx++] != '\0') return(nil);
    
    // Now make a new NSData from this buffer
    return([NSData dataWithBytes:&c_key[idx] length:len - idx]);
}

static NSData *base64_decode(NSString *str){
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return data;
}

- (SecKeyRef)addPublicKey:(NSString *)key{
    NSRange spos = [key rangeOfString:@"-----BEGIN PUBLIC KEY-----"];
    NSRange epos = [key rangeOfString:@"-----END PUBLIC KEY-----"];
    if(spos.location != NSNotFound && epos.location != NSNotFound){
        NSUInteger s = spos.location + spos.length;
        NSUInteger e = epos.location;
        NSRange range = NSMakeRange(s, e-s);
        key = [key substringWithRange:range];
    }
    key = [key stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@" "  withString:@""];
    
    // This will be base64 encoded, decode it.
    NSData *data = base64_decode(key);
    data = [self stripPublicKeyHeader:data];
    if(!data){
        return nil;
    }
    
    //a tag to read/write keychain storage
    NSString *tag = @"RSAUtil_PubKey";
    NSData *d_tag = [NSData dataWithBytes:[tag UTF8String] length:[tag length]];
    
    // Delete any old lingering key with the same tag
    NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
    [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
    SecItemDelete((__bridge CFDictionaryRef)publicKey);
    
    // Add persistent version of the key to system keychain
    [publicKey setObject:data forKey:(__bridge id)kSecValueData];
    [publicKey setObject:(__bridge id) kSecAttrKeyClassPublic forKey:(__bridge id)
     kSecAttrKeyClass];
    [publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)
     kSecReturnPersistentRef];
    
    CFTypeRef persistKey = nil;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)publicKey, &persistKey);
    if (persistKey != nil){
        CFRelease(persistKey);
    }
    if ((status != noErr) && (status != errSecDuplicateItem)) {
        return nil;
    }
    
    [publicKey removeObjectForKey:(__bridge id)kSecValueData];
    [publicKey removeObjectForKey:(__bridge id)kSecReturnPersistentRef];
    [publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    
    // Now fetch the SecKeyRef version of the key
    SecKeyRef keyRef = nil;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey, (CFTypeRef *)&keyRef);
    if(status != noErr){
        return nil;
    }
    return keyRef;
}

- (NSData *)rsaEncryptData:(NSData *)data withKeyRef:(SecKeyRef) keyRef{
    const uint8_t *srcbuf = (const uint8_t *)[data bytes];
    size_t srclen = (size_t)data.length;
    
    size_t block_size = SecKeyGetBlockSize(keyRef) * sizeof(uint8_t);
    void *outbuf = malloc(block_size);
    size_t src_block_size = block_size - 11;
    
    NSMutableData *ret = [[NSMutableData alloc] init];
    for(int idx=0; idx<srclen; idx+=src_block_size){
        //NSLog(@"%d/%d block_size: %d", idx, (int)srclen, (int)block_size);
        size_t data_len = srclen - idx;
        if(data_len > src_block_size){
            data_len = src_block_size;
        }
        
        size_t outlen = block_size;
        OSStatus status = noErr;
        status = SecKeyEncrypt(keyRef,
                               kSecPaddingPKCS1,
                               srcbuf + idx,
                               data_len,
                               outbuf,
                               &outlen
                               );
        if (status != 0) {
            NSLog(@"SecKeyEncrypt fail. Error Code: %d", (int)status);
            ret = nil;
            break;
        }else{
            [ret appendBytes:outbuf length:outlen];
        }
    }
    
    free(outbuf);
    CFRelease(keyRef);
    return ret;
}

- (NSData *)rsaDecryptData:(NSData *)data withKeyRef:(SecKeyRef) keyRef{
    const uint8_t *srcbuf = (const uint8_t *)[data bytes];
    size_t srclen = (size_t)data.length;
    
    size_t block_size = SecKeyGetBlockSize(keyRef) * sizeof(uint8_t);
    UInt8 *outbuf = malloc(block_size);
    size_t src_block_size = block_size;
    
    NSMutableData *ret = [[NSMutableData alloc] init];
    for(int idx=0; idx<srclen; idx+=src_block_size){
        //NSLog(@"%d/%d block_size: %d", idx, (int)srclen, (int)block_size);
        size_t data_len = srclen - idx;
        if(data_len > src_block_size){
            data_len = src_block_size;
        }
        
        size_t outlen = block_size;
        OSStatus status = noErr;
        status = SecKeyDecrypt(keyRef,
                               kSecPaddingNone,
                               srcbuf + idx,
                               data_len,
                               outbuf,
                               &outlen
                               );
        if (status != 0) {
            NSLog(@"SecKeyEncrypt fail. Error Code: %d", (int)status);
            ret = nil;
            break;
        }else{
            //the actual decrypted data is in the middle, locate it!
            int idxFirstZero = -1;
            int idxNextZero = (int)outlen;
            for ( int i = 0; i < outlen; i++ ) {
                if ( outbuf[i] == 0 ) {
                    if ( idxFirstZero < 0 ) {
                        idxFirstZero = i;
                    } else {
                        idxNextZero = i;
                        break;
                    }
                }
            }
            
            [ret appendBytes:&outbuf[idxFirstZero+1] length:idxNextZero-idxFirstZero-1];
        }
    }
    
    free(outbuf);
    CFRelease(keyRef);
    return ret;
}

#pragma mark - RSA utils
- (NSString *)rsaEncryptString:(NSString *)str publicKey:(NSString *)pubKey{
    NSData *data = [self rsaEncryptData:[str dataUsingEncoding:NSUTF8StringEncoding] publicKey:pubKey];
    NSString *ret = [data mok_base64EncodedString];
    return ret;
}


#pragma mark - Get Refs

- (void)getKeyRefFor:(NSData *)tag {
    
    OSStatus resultCode = noErr;
    
    NSMutableDictionary * queryPublicKey = [NSMutableDictionary dictionaryWithCapacity:0];
    
    // Set the public key query dictionary.
    [queryPublicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    
    [queryPublicKey setObject:tag forKey:(__bridge id)kSecAttrApplicationTag];
    
    [queryPublicKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    
    [queryPublicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
    
    // Get the key.
    resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryPublicKey, (CFTypeRef *)&_publicKeyRef);
    //NSLog(@"getPublicKey: result code: %ld", resultCode);
    
    if(resultCode != noErr)
    {
        _publicKeyRef = NULL;
    }
    
    queryPublicKey =nil;
}

-(NSString *)stripGarbage:(NSString *)s {
    
    //NSLog(@"antes:%@",s);
    NSString *sb=@"";
    for (int i = 0; i < [s length]; i++) {
        char ch = [s characterAtIndex:i];
        if ((ch >= 'A' && ch <= 'Z') ||
            (ch >= 'a' && ch <= 'z') ||
            (ch >= '0' && ch <= '9') ||
            ch == '%' || ch == '_' ||
            ch == '-' || ch == '!' ||
            ch == '.' || ch == '~' ||
            ch == '(' || ch == ')' ||
            ch == '*' || ch == '\'' ||
            ch == ';' || ch == '/' ||
            ch == '?' || ch == ':' ||
            ch == '@' || ch == '=' ||
            ch == '&' || ch == '$' ||
            ch == ',' || ch == '+') {
            sb=[NSString stringWithFormat:@"%@%c",sb,ch];
        }
        else
            break;
    }
    //NSLog(@"despues:%@",sb);
    
    return [sb stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - AES encryption and decryption
-(NSData *)aesEncryptData:(NSData *)data fromUser:(NSString *)userId{
    return [self aesEncryptData:data withKey:[NSData mok_dataFromBase64String:[self getAESbase64forUser:userId]] andIV:[NSData mok_dataFromBase64String:[self getIVbase64forUser:userId]]] ;
}
-(NSData *)aesDecryptData:(NSData *)data fromUser:(NSString *)userId{
    return [self aesDecryptData:data withKey:[NSData mok_dataFromBase64String:[self getAESbase64forUser:userId]] andIV:[NSData mok_dataFromBase64String:[self getIVbase64forUser:userId]]];
}
-(NSString *)aesEncryptText:(NSString *)text fromUser:(NSString *)userId{
    NSString *aesbase64 = [self getAESbase64forUser:userId];
    NSData *aesdata = [NSData mok_dataFromBase64String:aesbase64];
    NSString *ivbase64 = [self getIVbase64forUser:userId];
    
    NSData *ivdata = [[NSData alloc]initWithBase64EncodedString:ivbase64 options:0];
    //    NSData *ivdata = [NSData mok_dataFromBase64String:ivbase64];
    
    return [[self aesEncryptData:[text dataUsingEncoding:NSUTF8StringEncoding] withKey:aesdata andIV:ivdata] mok_base64EncodedString];
}

-(NSString *)aesDecryptText:(NSString *)text fromUser:(NSString *)userId{
    return [[NSString alloc]initWithData:[self aesDecryptData:[NSData mok_dataFromBase64String:text] withKey:[NSData mok_dataFromBase64String:[self getAESbase64forUser:userId]] andIV:[NSData mok_dataFromBase64String:[self getIVbase64forUser:userId]]] encoding:NSUTF8StringEncoding];
}

-(NSString *)aesDecryptKeyAndClean:(NSString *)encryptedString fromUser:(NSString *)userId{
    NSString *aesandiv = [self aesDecryptText:encryptedString fromUser:userId];
    NSRange range= [aesandiv rangeOfString:@"=" options:NSBackwardsSearch];
    
    //stripping the garbage at the end
    NSString *finalbase64aesandiv = [aesandiv substringToIndex:range.location+1];
    if (finalbase64aesandiv != nil) {
        finalbase64aesandiv = [NSString stringWithUTF8String:[finalbase64aesandiv UTF8String]];
    }
    
    return finalbase64aesandiv;
}

-(NSData *)aesEncryptData:(NSData *)data withKey:(NSData *)key andIV:(NSData *)iv{
    return [BBAES encryptedDataFromData:data IV:iv key:key options:0];
}
-(NSData *)aesDecryptData:(NSData *)data withKey:(NSData *)key andIV:(NSData *)iv{
    return [BBAES decryptedDataFromData:data IV:iv key:key];
}



#pragma mark - AES Key
- (NSString *)generateAESKeyAndIV{
    NSData *salt = [BBAES randomDataWithLength:BBAESSaltDefaultLength];
    NSData *aesKey = [BBAES keyBySaltingPassword:@"3xtr45cur3" salt:salt keySize:BBAESKeySize256 numberOfIterations:BBAESPBKDF2DefaultIterationsCount];
    NSData *iv = [BBAES randomIV];
    NSString *base64_iv = [iv mok_base64EncodedString];
    
    NSString *base64_aesKey = [aesKey mok_base64EncodedString];
    
    NSString *aesandiv = [NSString stringWithFormat:@"%@:%@", base64_aesKey, base64_iv];
    
    return aesandiv;
}

#pragma mark - Base 64
-(NSString *)decodeBase64:(NSString *)encodedString{
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    
    return decodedString;
}
-(NSString *)encodeBase64:(NSString *)plainString{
    return [[plainString dataUsingEncoding:NSUTF8StringEncoding] mok_base64EncodedString];
}
@end
