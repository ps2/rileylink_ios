//
//  SensorSimulatorViewController.h
//  RileyLink
//
//  Created by Pete Schwamb on 9/24/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RileyLinkBLEDevice.h"

@interface SensorSimulatorViewController : UIViewController

@property (nonatomic, strong) RileyLinkBLEDevice *device;

@end
