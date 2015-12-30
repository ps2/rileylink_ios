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
#import "SendAndListenCmd.h"
#import "SendPacketCmd.h"

#define EXPECTED_MAX_BLE_LATENCY_MS 5000

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

@property (nonatomic, nullable, copy) void (^completionHandler)(MessageSendOperation *operation);

@property (nonatomic, nonnull, strong) RileyLinkBLEDevice *device;

@property (nonatomic) MessageSendState state;

@property (nonatomic, nonnull, strong) MessageBase *message;

@property (nonatomic, nullable, strong) CmdBase *cmd;

@end

@implementation MessageSendOperation

- (nonnull instancetype)initWithDevice:(nonnull RileyLinkBLEDevice *)device
                               message:(nonnull MessageBase *)message
                     completionHandler:(void (^ _Nullable)(MessageSendOperation * _Nonnull operation))completionHandler
{
  self = [super init];
  if (self) {
    _completionHandler = [completionHandler copy];
    _device = device;
    _repeatCount = 0;
    _listenChannel = 2;
    _sendChannel = 0;
    _message = message;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnected:) name:RILEYLINK_EVENT_DEVICE_CONNECTED object:device];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDisconnected:) name:RILEYLINK_EVENT_DEVICE_DISCONNECTED object:device];
    
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

- (void)receivedResponse:(NSData *)response
{
  @synchronized(self) {
    if (self.state == MessageSendStateWaitingForReponse) {
      
      if (response.length == 1 && ((uint8_t*)[response bytes])[0] == 0) {
        NSLog(@"Packet timeout");
      }
      else if (response.length < 4) {
        NSLog(@"Short packet")
      }
      else {
        MinimedPacket *rxPacket = [[MinimedPacket alloc] initWithData:response];
      
        if (self.responseMessageType == 0 || (self.message.packetType == rxPacket.packetType &&
                                              [self.message.address isEqualToString:rxPacket.address] &&
                                              rxPacket.messageType == self.responseMessageType))
        {
          NSLog(@"%s with matching packet %02x", __PRETTY_FUNCTION__, rxPacket.messageType);
          self.responsePacket = rxPacket;
        } else {
          NSLog(@"%s for non-matching packet %02x", __PRETTY_FUNCTION__, rxPacket.messageType);
        }
      }
      [self finishAfterWaiting:0];
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
          if (_completionHandler != nil) {
            _completionHandler(self);
          } else {
            NSLog(@"_completionHandler = %@", _completionHandler);
          }
        });
      }
    }
  }
}

- (void)start
{
  if ([self isCancelled]) {
    return;
  }
  NSLog(@"%s: %@", __PRETTY_FUNCTION__, self);
  
  if (self.isReady) {
    self.state = MessageSendStateWaitingForReponse;
    
    if ([self isCancelled]) {
      return;
    }
    
    if (_waitTimeMS > 0) {
      SendAndListenCmd *sendAndListen = [[SendAndListenCmd alloc] init];
      sendAndListen.sendChannel = _sendChannel;
      sendAndListen.repeatCount = _repeatCount;
      sendAndListen.msBetweenPackets = _msBetweenPackets;
      sendAndListen.listenChannel = _listenChannel;
      sendAndListen.timeoutMS = _waitTimeMS;
      sendAndListen.retryCount = _retryCount;
      sendAndListen.packet = [MinimedPacket encodeData:_message.data];
      self.cmd = sendAndListen;
    } else {
      SendPacketCmd *send = [[SendPacketCmd alloc] init];
      send.sendChannel = _sendChannel;
      send.repeatCount = _repeatCount;
      send.msBetweenPackets = _msBetweenPackets;
      send.packet = [MinimedPacket encodeData:_message.data];
      self.cmd = send;
    }
    
    NSLog(@"Running cmd: %@, %@", self.cmd, _message);
    [self.device doCmd:self.cmd withCompletionHandler:^(CmdBase * _Nonnull cmd) {
      [self receivedResponse:self.cmd.response];
    }];
    
    __weak typeof(self)weakSelf = self;
    
    int64_t totalWaitTime = self.waitTimeMS * (self.retryCount + 1) + EXPECTED_MAX_BLE_LATENCY_MS;
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, totalWaitTime * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
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

#pragma mark - NSOperation

- (BOOL)isAsynchronous
{
  return YES;
}

- (void)cancel
{
  NSLog(@"%s: %@", __PRETTY_FUNCTION__, self);
  [super cancel];
  self.state = MessageSendStateFinished;
  if (self.cmd != nil) {
    [self.device cancelCommand:self.cmd];
  }
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
