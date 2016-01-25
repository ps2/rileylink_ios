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
#import "PumpCommManager.h"
#import "HistoryPage.h"
#import "PumpHistoryEventBase.h"
#import "SendAndListenCmd.h"

@interface PumpChatViewController () {
  IBOutlet UITextView *output;
  IBOutlet UILabel *batteryVoltage;
  IBOutlet UILabel *pumpIdLabel;
  NSString *model;
  PumpCommManager *mgr;
}

@property (nonatomic, strong) NSOperationQueue *pumpCommQueue;

@end

@implementation PumpChatViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  model = @"551";

  // Do any additional setup after loading the view.

  self.pumpCommQueue = [[NSOperationQueue alloc] init];
  self.pumpCommQueue.maxConcurrentOperationCount = 1;
  self.pumpCommQueue.qualityOfService = NSQualityOfServiceUserInitiated;

  mgr = [[PumpCommManager alloc] initWithPumpId:[[Config sharedInstance] pumpID] andDevice:self.device];
  pumpIdLabel.text = [NSString stringWithFormat:@"PumpID: %@", [[Config sharedInstance] pumpID]];
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
  [mgr dumpHistoryPage:0 completionHandler:^(NSDictionary *res) {
    if (!res[@"error"]) {
      NSData *page = res[@"pageData"];
      NSLog(@"Got page data: %@", [page hexadecimalString]);
      [self decodeHistoryPage:page];
    } else {
      NSString *log = [NSString stringWithFormat:@"Dump of page 0 failed: %@", res[@"error"]];
      [self addOutputMessage:log];
    }
  }];
}

- (void) decodeHistoryPage:(NSData*)data {
  
  PumpModel *m = [PumpModel find:model];
  HistoryPage *page = [[HistoryPage alloc] initWithData:data andPumpModel:m];
  
  NSArray *events = [page decode];
  
  for (PumpHistoryEventBase *event in events) {
    [self addOutputMessage:[NSString stringWithFormat:@"Event: %@", event]];
    NSLog(@"Event: %@", event);
  }
  

}

- (IBAction)pressDownButtonPressed:(id)sender {
  
  [mgr pressButton];
}

- (IBAction)queryPumpButtonPressed:(id)sender {
  
  [mgr getPumpModel:^(NSString* returnedModel) {
    if (returnedModel) {
      model = returnedModel;
      [self addOutputMessage:[NSString stringWithFormat:@"Pump Model: %@", model]];
    } else {
      [self addOutputMessage:@"Get pump model failed."];
    }
  }];
  
  [mgr getBatteryVoltage:^(NSString *indicator, float volts) {
    [self addOutputMessage:[NSString stringWithFormat:@"Battery Level: %@, %0.02f volts", indicator, volts]];
  }];
}


@end
