//
//  SGSConnection.m
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import "MOKSGSConnection.h"
#import "MOKSGSContext.h"
#import "MOKSGSSession.h"
#import "MOKSGSMessage.h"
#import "MOKSGSProtocol.h"

#import <CFNetwork/CFNetwork.h>

#define SGS_CONNECTION_IMPL_IO_BUFSIZE	SGS_MSG_MAX_LENGTH

@interface MOKCustomException : NSException
@end
@implementation MOKCustomException
@end

@interface MOKSGSConnection (PrivateMethods)

- (void)openStreams;
- (void)closeStreams;
- (void)connectionClosed;
- (void)resetBuffers;
- (BOOL)processOutgoingBytes;
- (BOOL)processIncomingBytes;

@end


@implementation MOKSGSConnection

@synthesize socket;
@synthesize state;
@synthesize context;
@synthesize session;
@synthesize inBuf;
@synthesize outBuf;
@synthesize expectingDisconnect;
@synthesize inRedirect;

- (id)initWithContext:(MOKSGSContext *)aContext {
    if(self = [super init]) {
        // Save reference to our context
        self.context = aContext;
        
        // Set some defaults
        _streamChanged = false;
        _portions = @"15";
        _delay = @"2";
        expectingDisconnect = NO;
        inRedirect = NO;
        state = MOKSGSConnectionStateDisconnected;
        session = [[MOKSGSSession alloc] initWithConnection:self];
        
        // Create our io buffers
        inBuf = [[NSMutableData alloc] init];
        outBuf = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)disconnect {
    NSLog(@"MONKEY - ???disconnect FUnction called por aca habian releases?");
    [self closeStreams];
    expectingDisconnect = NO;
    state = MOKSGSConnectionStateDisconnected;
    
    if(inRedirect) {
        // Just reset the buffers if we are being redirected
        [self resetBuffers];
    }
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password {
#ifdef DEBUG
    NSLog(@"MONKEY - login credentials, username: %@ password: %@, hostname: %@, port: %ld", username, password, context.hostname, (long)context.port);
#endif
    
    if(self.state==MOKSGSConnectionStateConnecting)
        return;
    
    
    self.state=MOKSGSConnectionStateConnecting;

    CFStringRef hostname = CFStringCreateWithCString(kCFAllocatorDefault, [context.hostname UTF8String], kCFStringEncodingASCII);
    CFHostRef host = CFHostCreateWithName(kCFAllocatorDefault, hostname);
    
    // Pre buffer the login request
    [session loginWithLogin:username password:password];
    
    // Try and connect to the socket
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    
    
    CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, host, (SInt32)context.port, &readStream, &writeStream);
    if(readStream && writeStream) {
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        inputStream = (__bridge NSInputStream *)readStream;
        outputStream = (__bridge NSOutputStream *)writeStream;
        
        [self openStreams];
        
        self.state = MOKSGSConnectionStateConnecting;
        
    }
}

- (void)logout:(BOOL)force {
    if(force) {
        [self connectionClosed];
        return;
    }
    
    expectingDisconnect = YES;
    if(inRedirect) {
        return;
    }
    
    [session logout];
}

- (BOOL)sendMessage:(MOKSGSMessage *)msg {
    
    [outBuf appendBytes:[msg bytes] length:[msg length]];
    return [self processOutgoingBytes];
    
    
}

#pragma mark NSStreamDelegate Impl

- (void) stream:(NSStream*)stream handleEvent:(NSStreamEvent)eventCode {
    //NSLog(@"MONKEY - STREAM handleEvent has bytes comming");
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
        {
            if(stream == outputStream) {
                // Output stream is connected
                // Update our state on this
                state = MOKSGSConnectionStateConnected;
            }
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {//0x8b
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self readInputProcess];
            });
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
            [self processOutgoingBytes];
            break;
        }
        case NSStreamEventEndEncountered:
        {
            [self connectionClosed];
            [self notifyConnectionClosed];
            break;
        }
        case NSStreamEventErrorOccurred:
            [self connectionClosed];
            [self notifyConnectionClosed];
            break;
        default:
            break;
    }
}

-(void) readInputProcess{

    @try {
        // read data from the buffer
        uint8_t buf[1024];
        uint8_t *buffer;
        NSUInteger ilen = 0;
        @synchronized(inBuf){
            if(![inputStream getBuffer:&buffer length:&ilen]) {
                NSInteger amount;
                
                while([inputStream hasBytesAvailable]) {
                    
                    amount = [inputStream read:buf maxLength:sizeof(buf)];
                    if(amount>0)
                        [inBuf appendBytes:buf length:amount];
                    
                    //NSLog(@"MONKEY - new *** Opcode : 0x%x", buf[2]);
                }//end while
                
                
                
                
            } else {
#ifdef DEBUG
                NSLog(@"MONKEY - ELSE inputStream not available APPEND -- bbuffer");
#endif
                // We have a reference to the buffer
                // copy the buffer over to our input buffer and begin processing
                [inBuf appendBytes:buffer length:ilen];
            }

        }
        do {} while([self processIncomingBytes]);
        
        
    }@catch (MOKCustomException *ce){
        if (!self.streamChanged) {
            self.streamChanged = true;
            
            int streamPortions = [self.portions intValue];
            streamPortions = streamPortions - 1;
            if (streamPortions < 5 ) {
                streamPortions = 5;
            }

            self.portions = [NSString stringWithFormat:@"%d",streamPortions];

            // Delay execution of my block for 10 seconds.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                self.portions = @"15";
                self.streamChanged = false;
            });
        }
    }
    @catch (NSException *e) {
        NSLog(@"MONKEY - gettin disconnect %@",e);
        [self disconnect];
        [self notifyConnectionClosed];
    }
}
#pragma mark Private Methods

- (void)openStreams {
    inputStream.delegate = self;
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream open];
    outputStream.delegate = self;
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream open];
    
}

- (void)closeStreams {
    
    if(inputStream) {
        [inputStream close];
        [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
    
    if(outputStream) {
        [outputStream close];
        [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)connectionClosed {
    if(inRedirect){
        return;
    }
    
    [self disconnect];
}

-(void)notifyConnectionClosed{
    //antes fuera de disconnect
    if([context.delegate respondsToSelector:@selector(sgsContext:disconnected:)]) {
        [context.delegate sgsContext:context disconnected:self];
    }
}


- (void)resetBuffers {
    inBuf = [[NSMutableData alloc] init];
    outBuf = [[NSMutableData alloc] init];
    
    NSLog(@"MONKEY - ________reseting buffers___");
}

- (BOOL)isConnectionAvailable {
    
    if((![outputStream hasSpaceAvailable] || state==MOKSGSConnectionStateDisconnected || !inputStream) && state!=MOKSGSConnectionStateConnecting) {
        return NO;
    }
    
    return YES;
}

- (BOOL)processOutgoingBytes {
    
    if(![outputStream hasSpaceAvailable]) {
        //        NSLog(@"MONKEY - NO SPACE AVAILABLE TO GO");
        return NO;
    }
    
    NSUInteger olen = [outBuf length];
    if(0 < olen) {
        NSUInteger writ = [outputStream write:[outBuf bytes] maxLength:olen];
        if(writ < olen) {
            memmove([outBuf mutableBytes], [outBuf mutableBytes] + writ, olen - writ);
            [outBuf setLength:olen - writ];
            return YES;
        }
        
        [outBuf setLength:0];
    }
    
    return YES;
}

- (BOOL)processIncomingBytes {
    // See if we have enough bytes to read the message length
    NSUInteger ilen = [inBuf length];
    
    if(ilen < MOKSGS_MSG_LENGTH_OFFSET) {
        return NO;
    }
    @synchronized(inBuf){
        
        // We have enough bytes, get the message length -  the first 2 bytes is the length of the message
        uint32_t mlen;
        [inBuf getBytes:&mlen length:MOKSGS_MSG_LENGTH_OFFSET];
        mlen = ntohs(mlen);//network to host short /  computed valid short
        //ntohs 2 byte short
        
        // Copy the bytes to the message buffer and clear them from the input buffer
        size_t len = mlen + MOKSGS_MSG_LENGTH_OFFSET;// message len + the 2 bytes telling the leng is the total of the message
        
        NSMutableData *messageBuffer;
        
        if(len>[inBuf length])//el LEN calculado es mayor al que tiene el buffer realmente
        {
            @throw [[MOKCustomException alloc] initWithName:@"Bytes Error Exception" reason:@"Exceding Bytes" userInfo:nil];
            return YES;
        }
        else{
            
            messageBuffer = [NSMutableData dataWithLength:len];
            
            // copia al messageBuffer lo de inBuf
            memcpy([messageBuffer mutableBytes], [inBuf bytes], len);
            memmove([inBuf mutableBytes], [inBuf bytes] + len, [inBuf length] - len);
            
            [inBuf setLength:ilen - len];
        }
        
        // Build the message with the message buffer
        MOKSGSMessage *mess = [MOKSGSMessage messageWithData:messageBuffer];
        [session receiveMessage:mess];
    }
    return YES;
}

@end
