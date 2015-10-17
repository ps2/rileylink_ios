//
//  AlertManager.m
//  RileyLink
//
//  Created by Pete Schwamb on 10/16/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "AlertManager.h"
#import "RileyLinkBLEManager.h"
#import "MinimedPacket.h"
#import "AlertMessage.h"

@implementation AlertManager

- (instancetype)init
{
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(packetReceived:)
                                                 name:RILEYLINK_EVENT_PACKET_RECEIVED
                                               object:nil];

  }
  return self;
}

- (void)packetReceived:(NSNotification*)notification {
  NSDictionary *attrs = notification.userInfo;
  MinimedPacket *packet = attrs[@"packet"];
  
  if (packet.packetType == PACKET_TYPE_PUMP && packet.messageType == MESSAGE_TYPE_ALERT) {
    AlertMessage *msg = [[AlertMessage alloc] initWithData:packet.data];
    
    
  }
}


@end
