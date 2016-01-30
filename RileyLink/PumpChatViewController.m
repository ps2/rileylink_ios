//
//  PumpChatViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 8/8/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "PumpChatViewController.h"
#import "MessageBase.h"
#import "MinimedPacket.h"
#import "NSData+Conversion.h"
#import "Config.h"
#import "RileyLinkBLEManager.h"
#import "HistoryPage.h"
#import "PumpHistoryEventBase.h"
#import "SendAndListenCmd.h"
#import "AppDelegate.h"
#import "PumpOpsSynchronous.h"
#import "PumpOps.h"

@interface PumpChatViewController () {
  IBOutlet UITextView *output;
  IBOutlet UILabel *batteryVoltage;
  IBOutlet UILabel *pumpIdLabel;
}

@property (nonatomic, strong) NSOperationQueue *pumpCommQueue;
@property (nonatomic, strong) PumpOps *pumpOps;

@end

@implementation PumpChatViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  pumpIdLabel.text = [NSString stringWithFormat:@"PumpID: %@", [[Config sharedInstance] pumpID]];
  
  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
  _pumpOps = [[PumpOps alloc] initWithPumpState:appDelegate.pump andDevice:_device];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addOutputMessage:(NSString*)msg
{
  output.text = [output.text stringByAppendingFormat:@"%@\n", msg];
  NSLog(@"addOutputMessage: %@", msg);
}


- (IBAction)dumpHistoryButtonPressed:(id)sender {
  [_pumpOps getHistoryPage:0 withHandler:^(NSDictionary * _Nonnull res) {
    if (!res[@"error"]) {
      NSData *page = res[@"pageData"];
      NSLog(@"Got page data: %@", [page hexadecimalString]);
      [self decodeHistoryPage:page withModel:res[@"pumpModel"]];
    } else {
      NSString *log = [NSString stringWithFormat:@"Dump of page 0 failed: %@", res[@"error"]];
      [self addOutputMessage:log];
    }
  }];
}

- (void) decodeHistoryPage:(NSData*)data withModel:(NSString*)model {
  
  PumpModel *m = [PumpModel find:model];
  HistoryPage *page = [[HistoryPage alloc] initWithData:data andPumpModel:m];
  
  NSArray *events = [page decode];
  
  for (PumpHistoryEventBase *event in events) {
    [self addOutputMessage:[NSString stringWithFormat:@"Event: %@", event]];
    NSLog(@"Event: %@", event);
  }
}

- (IBAction)pressDownButtonPressed:(id)sender {
  [_pumpOps pressButton];
}

- (IBAction)queryPumpButtonPressed:(id)sender {
  
  [_pumpOps getPumpModel:^(NSString * _Nonnull model) {
    if (model) {
      [self addOutputMessage:[NSString stringWithFormat:@"Pump Model: %@", model]];
    } else {
      [self addOutputMessage:@"Get pump model failed."];
    }
  }];
  
  [_pumpOps getBatteryVoltage:^(NSString * _Nonnull status, float value) {
    [self addOutputMessage:[NSString stringWithFormat:@"Battery Level: %@, %0.02f volts", status, value]];
  }];
}

- (IBAction)tuneButtonPressed:(id)sender {
  [_pumpOps tunePump:^(NSDictionary * _Nonnull res) {
    [self addOutputMessage:[NSString stringWithFormat:@"Tuning results: %@", res]];
  }];
}


@end
