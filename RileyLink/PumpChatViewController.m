//
//  PumpChatViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 8/8/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "PumpChatViewController.h"
#import "MessageSendOperation.h"
#import "MessageBase.h"
#import "MinimedPacket.h"
#import "NSData+Conversion.h"
#import "Config.h"
#import "RileyLinkBLEManager.h"
#import "PumpCommManager.h"

@interface PumpChatViewController () {
  IBOutlet UILabel *resultsLabel;
  IBOutlet UILabel *batteryVoltage;
  IBOutlet UILabel *pumpIdLabel;
}

@property (nonatomic, strong) NSOperationQueue *pumpCommQueue;

@end

@implementation PumpChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.pumpCommQueue = [[NSOperationQueue alloc] init];
    self.pumpCommQueue.maxConcurrentOperationCount = 1;
    self.pumpCommQueue.qualityOfService = NSQualityOfServiceUserInitiated;

  pumpIdLabel.text = [NSString stringWithFormat:@"PumpID: %@", [[Config sharedInstance] pumpID]];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateStatusMessage:(NSString*)msg
{
  resultsLabel.text = msg;
  NSLog(@"StatusUpdate: %@", msg);
}


- (IBAction)queryPumpButtonPressed:(id)sender {
  [self queryPump];
}


- (void)queryPump {
  
  PumpCommManager *mgr = [[PumpCommManager alloc] initWithPumpId:[[Config sharedInstance] pumpID] andDevice:self.device];
  
  [mgr dumpHistory:^(NSDictionary * _Nonnull res) {
    NSLog(@"Got: %@", res);
  }];
  
//  [mgr getPumpModel:^(NSString* model) {
//    [self updateStatusMessage:[@"Pump Model: " stringByAppendingString:model]];
//  }];
//  
//  [mgr getPumpModel:^(NSString* model) {
//    [self updateStatusMessage:[@"Pump Model: " stringByAppendingString:model]];
//  }];
//  
//  [mgr getBatteryVoltage:^(NSString *indicator, float volts) {
//    batteryVoltage.text = [NSString stringWithFormat:@"Battery %@, %0.02f volts", indicator, volts];
//  }];

  
  [mgr pressButton];
  
}

@end
