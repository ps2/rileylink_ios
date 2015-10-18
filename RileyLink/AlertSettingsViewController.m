//
//  AlertSettingsViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 10/17/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "AlertSettingsViewController.h"
#import "SWRevealViewController.h"
#import "Config.h"

@interface AlertSettingsViewController () {
  IBOutlet UISwitch *alertsSwitch;
  IBOutlet UIBarButtonItem *menuButton;
}
@end

@implementation AlertSettingsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  if (self.revealViewController != nil) {
    menuButton.target = self.revealViewController;
    [menuButton setAction:@selector(revealToggle:)];
    [self.view addGestureRecognizer: self.revealViewController.panGestureRecognizer];
  }
  
  alertsSwitch.on = [[Config sharedInstance] alertsEnable];
}

- (IBAction)alertsEnableSwitchToggled:(id)sender {
  [[Config sharedInstance] setAlertsEnable:alertsSwitch.on];
}



@end
