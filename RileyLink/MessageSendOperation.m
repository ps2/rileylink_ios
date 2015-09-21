//
//  MessageSendOperation.m
//  RileyLink
//
//  Created by Nathan Racklyeft on 8/23/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "MessageSendOperation.h"
#import "RileyLinkBLEManager.h"
#import "MinimedPacket.h"

typedef NS_ENUM(NSUInteger, MessageSendState) {
    MessageSendStateDisconnected,
    MessageSendStateReady,
    MessageSendStateWaitingForReponse,
    MessageSendStateCoolDown,
    MessageSendStateFinished,
};

typedef NS_ENUM(NSInteger, MessageSendError) {
    MessageSendErrorTimeout = -1001
};

static NSString * const ErrorDomain = @"com.ps2.RileyLink.error";

NSString * KeyPathForMessageSendState(MessageSendState state) {
    switch (state) {
        case MessageSendStateDisconnected:
            return @"isDisconnected";
        case MessageSendStateReady:
            return @"isReady";
        case MessageSendStateWaitingForReponse:
            return @"isExecuting";
        case MessageSendStateCoolDown:
            return @"isCoolDown";
        case MessageSendStateFinished:
            return @"isFinished";
    }
}

@interface MessageSendOperation ()

@property (nonatomic) NSTimeInterval timeout;

@property (nonatomic, nullable, copy) void (^completionHandler)(MessageSendOperation *operation);

@property (nonatomic, nonnull, strong) RileyLinkBLEDevice *device;



@property (nonatomic, nonnull, strong) MessageBase *message;

@property (nonatomic) MessageSendState state;

@end

@implementation MessageSendOperation

- (instancetype)initWithDevice:(RileyLinkBLEDevice *)device message:(MessageBase *)message completionHandler:(void (^ _Nullable)(MessageSendOperation * _Nonnull))completionHandler
{
    self = [super init];
    if (self) {
        _completionHandler = [completionHandler copy];
        _device = device;
        _message = message;
        _repeatInterval = 0;
        _timeout = 10;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnected:) name:RILEYLINK_EVENT_DEVICE_CONNECTED object:device];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnected:) name:RILEYLINK_EVENT_DEVICE_DISCONNECTED object:device];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidReceivePacket:) name:RILEYLINK_EVENT_PACKET_RECEIVED object:device];

        if (device.peripheral.state == CBPeripheralStateConnected) {
            _state = MessageSendStateReady;
        } else {
            _state = MessageSendStateDisconnected;
        }
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RILEYLINK_EVENT_DEVICE_CONNECTED object:self.device];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RILEYLINK_EVENT_DEVICE_DISCONNECTED object:self.device];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RILEYLINK_EVENT_PACKET_RECEIVED object:self.device];
}

- (void)setRepeatInterval:(NSTimeInterval)repeatInterval
{
    _repeatInterval = repeatInterval;

    if (repeatInterval > 0) {
        self.timeout = 30;
    }
}

#pragma mark - Device updates

- (void)deviceConnected:(NSNotification *)note
{
    self.state = MessageSendStateReady;
}

- (void)deviceDisconnected:(NSNotification *)note
{
    [self cancel];
}

- (void)deviceDidReceivePacket:(NSNotification *)note
{
    @synchronized(self) {
        if (self.state == MessageSendStateWaitingForReponse) {
            MinimedPacket *rxPacket = note.userInfo[@"packet"];

            if (self.message.packetType == rxPacket.packetType &&
                [self.message.address isEqualToString:rxPacket.address] &&
                rxPacket.messageType == self.responseMessageType)
            {
                NSLog(@"%s with matching packet %02x", __PRETTY_FUNCTION__, rxPacket.messageType);

                self.responsePacket = rxPacket;

                NSTimeInterval waitTime = 0;

                if (self.repeatInterval > 0) {
                    [self.device cancelSending];
                    waitTime = 1;
                }

                [self finishAfterWaiting:waitTime];
            } else {
                NSLog(@"%s for non-matching packet %02x", __PRETTY_FUNCTION__, rxPacket.messageType);
            }
        }
    }
}

#pragma mark - State machine

- (void)setState:(MessageSendState)state
{
    @synchronized(self) {
        MessageSendState oldState = self.state;
        MessageSendState newState = state;

        BOOL isValid = NO;

        switch (oldState) {
            case MessageSendStateDisconnected:
                switch (newState) {
                    case MessageSendStateReady:
                        isValid = YES;
                        break;
                    default:
                        break;
                }
            case MessageSendStateReady:
                switch (newState) {
                    case MessageSendStateWaitingForReponse:
                        isValid = YES;
                        break;
                    case MessageSendStateFinished:
                        if (self.isCancelled) {
                            isValid = YES;
                        }
                        break;
                    default:
                        break;
                }
                break;
            case MessageSendStateWaitingForReponse:
                switch (newState) {
                    case MessageSendStateCoolDown:
                        isValid = YES;
                        break;
                    case MessageSendStateFinished:
                        isValid = YES;
                    default:
                        break;
                }
                break;
            case MessageSendStateCoolDown:
                switch (newState) {
                    case MessageSendStateFinished:
                        isValid = YES;
                        break;
                    default:
                        break;
                }
                break;
            case MessageSendStateFinished:
                break;
        }

        if (isValid) {
            NSString *oldKeyPath = KeyPathForMessageSendState(oldState);
            NSString *newKeyPath = KeyPathForMessageSendState(newState);

            NSLog(@"%@ -> %@", oldKeyPath, newKeyPath);

            [self willChangeValueForKey:newKeyPath];
            [self willChangeValueForKey:oldKeyPath];
            _state = newState;
            [self didChangeValueForKey:oldKeyPath];
            [self didChangeValueForKey:newKeyPath];

            if (newState == MessageSendStateFinished && _completionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _completionHandler(self);
                });
            }
        }
    }
}

#pragma mark - NSOperation

- (BOOL)isAsynchronous
{
    return YES;
}

- (void)start
{
    if (self.isReady) {
        self.state = MessageSendStateWaitingForReponse;

        NSData *packetData = [MinimedPacket encodeData:self.message.data];

        if (self.repeatInterval > 0) {
            NSLog(@"%s sending message %02x every %.02fs", __PRETTY_FUNCTION__, self.message.messageType, self.repeatInterval);

            [self.device sendPacketData:packetData withCount:self.timeout / self.repeatInterval andTimeBetweenPackets:self.repeatInterval];
        } else {
            NSLog(@"%s sending message %02x", __PRETTY_FUNCTION__, self.message.messageType);

            [self.device sendPacketData:packetData];
        }

        if (self.responseMessageType == 0) {
            NSLog(@"%s not waiting for response", __PRETTY_FUNCTION__);
            self.state = MessageSendStateFinished;
        } else {
            __weak typeof(self)weakSelf = self;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (weakSelf && !weakSelf.isFinished) {
                    NSLog(@"MessageSendOperation timeout");
                    weakSelf.error = [NSError errorWithDomain:ErrorDomain
                                                         code:MessageSendErrorTimeout
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Timeout waiting for response message"}];
                    [weakSelf cancel];
                }
            });
        }
    }
}

- (void)cancel
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super cancel];
    self.state = MessageSendStateFinished;
}

- (void)finishAfterWaiting:(NSTimeInterval)waitTime
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (waitTime > 0) {
        self.state = MessageSendStateCoolDown;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.state = MessageSendStateFinished;
        });
    } else {
        self.state = MessageSendStateFinished;
    }
}

- (BOOL)isExecuting
{
    return self.state == MessageSendStateWaitingForReponse;
}

- (BOOL)isFinished
{
    return self.state == MessageSendStateFinished;
}

- (BOOL)isReady
{
    return self.state == MessageSendStateReady && super.isReady;
}

@end
