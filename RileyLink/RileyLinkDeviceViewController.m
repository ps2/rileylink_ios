//
//  RileyLinkViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "RileyLinkDeviceViewController.h"
#import "PacketLogViewController.h"
#import "PumpChatViewController.h"
#import "PacketGeneratorViewController.h"
#import "RileyLinkBLEManager.h"

@interface RileyLinkDeviceViewController () {
  IBOutlet UILabel *deviceIDLabel;
  IBOutlet UITextField *nameView;
  IBOutlet UISwitch *autoConnectSwitch;
  IBOutlet UIActivityIndicatorView *connectingIndicator;
}

@end

@implementation RileyLinkDeviceViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  deviceIDLabel.text = self.rlRecord.peripheralId;
  nameView.text = self.rlRecord.name;
  
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(deviceDisconnected:)
                                               name:RILEYLINK_EVENT_DEVICE_DISCONNECTED
                                             object:self.rlDevice];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(deviceConnected:)
                                               name:RILEYLINK_EVENT_DEVICE_CONNECTED
                                             object:self.rlDevice];


  [self updateConnectedHighlight];
  autoConnectSwitch.on = [self.rlRecord.autoConnect boolValue];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)updateConnectedHighlight {
  switch (self.rlDevice.state) {
    case RILEYLINK_STATE_CONNECTING:
      nameView.backgroundColor = [UIColor clearColor];
      nameView.text = @"Connecting...";
      [connectingIndicator startAnimating];
      break;
    case RILEYLINK_STATE_CONNECTED:
      nameView.backgroundColor = [UIColor greenColor];
      nameView.text = self.rlDevice.name;
      [connectingIndicator stopAnimating];
      break;
    case RILEYLINK_STATE_DISCONNECTED:
      nameView.backgroundColor = [UIColor clearColor];
      nameView.text = self.rlDevice.name;
      [connectingIndicator stopAnimating];
      break;
  }
}

- (void)deviceDisconnected:(NSNotification*)notification {
  [self updateConnectedHighlight];
}

- (void)deviceConnected:(NSNotification*)notification {
  [self updateConnectedHighlight];
}


- (IBAction)autoConnectSwitchToggled:(id)sender {
  self.rlRecord.autoConnect = @(autoConnectSwitch.isOn);

  NSError *error;
  if (![self.managedObjectContext save:&error]) {
    NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
  }
  
  if (autoConnectSwitch.isOn) {
    // TODO: Use KVO on a device property instead
    [[RileyLinkBLEManager sharedManager] removeDeviceFromAutoConnectList:self.rlDevice];


    [self.rlDevice connect];
  } else {
    [[RileyLinkBLEManager sharedManager] removeDeviceFromAutoConnectList:self.rlDevice];

    [self.rlDevice disconnect];
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
  [field resignFirstResponder];
  [self.rlDevice setCustomName:nameView.text];
  return YES;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.destinationViewController respondsToSelector:@selector(setDevice:)]) {
      [segue.destinationViewController performSelector:@selector(setDevice:) withObject:self.rlDevice];
  }
}

@end
