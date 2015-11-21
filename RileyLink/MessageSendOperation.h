//
//  MessageSendOperation.h
//  RileyLink
//
//  Created by Nathan Racklyeft on 8/23/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageBase.h"
#import "MinimedPacket.h"
#import "RileyLinkBLEDevice.h"

@interface MessageSendOperation : NSOperation

/**
Initializes the send operation with a device and message and a completion block

@param device            The device on which to perform the send
@param message           The message to send
@param completionHandler A block to execute when the operation finishes. This block has no return value and takes the finished operation as its only argument. It will be executed on the main queue.

@return A newly-initialized send operation
*/
- (nonnull instancetype)initWithDevice:(nonnull RileyLinkBLEDevice *)device
                               message:(nonnull MessageBase *)message
                               timeout:(NSTimeInterval)timeout
                     completionHandler:(void (^ _Nullable)(MessageSendOperation * _Nonnull operation))completionHandler;

/**
 The type of response to wait for before completing the operation.
 
 If not set, the operation will complete immediately after sending.
 */
@property (nonatomic) MessageType responseMessageType;

/**
 The interval at which to repeat the send until the response message is received.
 
 This value is 0 by default, indicating the message should only send once.
 */
@property (nonatomic) NSTimeInterval repeatInterval;

/**
 The error, if any, that occurred while sending or receiving
 */
@property (nonatomic, nonnull, strong) NSError *error;

/**
 The response packet, if one was received
 */
@property (nonatomic, nullable, strong) MinimedPacket *responsePacket;

@end
