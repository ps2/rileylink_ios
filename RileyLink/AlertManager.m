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
#import "Config.h"

@implementation AlertManager

- (instancetype)init
{
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(packetReceived:)
                                                 name:RILEYLINK_EVENT_PACKET_RECEIVED
                                               object:nil];
    
//    UIApplication* app = [UIApplication sharedApplication];
//
//    UIUserNotificationSettings *settings = app.currentUserNotificationSettings;
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)packetReceived:(NSNotification*)notification {
  NSDictionary *attrs = notification.userInfo;
  MinimedPacket *packet = attrs[@"packet"];

  if ([[Config sharedInstance] alertsEnable]) {
    if (packet.packetType == PACKET_TYPE_PUMP && packet.messageType == MESSAGE_TYPE_ALERT) {
      AlertMessage *msg = [[AlertMessage alloc] initWithData:packet.data];
      if ([[msg address] isEqualToString:[[Config sharedInstance] pumpID]]) {
        [self soundAlert:msg];
      }
    }
  }
}

- (void)soundAlert:(AlertMessage *)msg {
  UIApplication* app = [UIApplication sharedApplication];
  NSArray*    oldNotifications = [app scheduledLocalNotifications];
  
  NSString *soundName;
  
  switch (msg.alertType) {
    case ALERT_TYPE_HIGH_PREDICTED:
    case ALERT_TYPE_HIGH_GLUCOSE:
      soundName = @"high.aif";
      break;
    case ALERT_TYPE_LOW_PREDICTED:
    case ALERT_TYPE_LOW_GLUCOSE:
      soundName = @"low.aif";
      break;
    default:
      soundName = @"flat.aif";
      break;
  }
  
  // Clear out the old notification before scheduling a new one.
  if ([oldNotifications count] > 0)
    [app cancelAllLocalNotifications];
  
  // Create a new notification.
  UILocalNotification* alarm = [[UILocalNotification alloc] init];
  if (alarm)
  {
    alarm.repeatInterval = 0;
    alarm.soundName = soundName;
    alarm.alertBody = msg.alertTypeStr;
    [app presentLocalNotificationNow:alarm];
  }
}


@end
