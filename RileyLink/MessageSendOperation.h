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
                     completionHandler:(void (^ _Nullable)(MessageSendOperation * _Nonnull operation))completionHandler;

/**
 The type of response to wait for before completing the operation.
 
 If not set, the operation will accept any packet type as a response.
 */
@property (nonatomic) MessageType responseMessageType;

/**
 Delay time in ms to wait between repeating the send packet.
 */
@property (nonatomic) uint8_t msBetweenPackets;

/**
 Time in ms to wait for a response.
 If set to 0 (default), the operation will complete immediately after sending.
 */
@property (nonatomic) uint16_t waitTimeMS;

/**
 Number of times to repeat message. Defaults to 0, which means only send one packet. I.E. no repeat.
 */
@property (nonatomic) uint8_t repeatCount;

/**
 If we don't get a packet within the waitTime, send the message again, and listen again.
 */
@property (nonatomic) uint8_t retryCount;

/**
 The channel to listen for a response on. Defaults to 2.
 */
@property (nonatomic) uint8_t listenChannel;

/**
 The channel to send the message on. Defaults to 0.
 */
@property (nonatomic) uint8_t sendChannel;

/**
 The error, if any, that occurred while sending or receiving.
 */
@property (nonatomic, nonnull, strong) NSError *error;

/**
 The response packet, if one was received
 */
@property (nonatomic, nullable, strong) MinimedPacket *responsePacket;

@end
