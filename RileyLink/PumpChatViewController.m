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
  [mgr dumpHistory:^(NSDictionary *res) {
    if (res) {
      NSData *page = res[@"page0"];
      NSLog(@"Got page: %@", [page hexadecimalString]);
      [self decodeHistoryPage:page];
    } else {
      [self addOutputMessage:@"Dump of page 0 failed"];
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
  SendAndListenCmd *sendAndListen = [[SendAndListenCmd alloc] init];
  sendAndListen.sendChannel = 0;
  sendAndListen.repeatCount = 0;
  sendAndListen.msBetweenPackets = 0;
  sendAndListen.listenChannel = 2;
  sendAndListen.timeoutMS = 5000;
  sendAndListen.packet = [NSData dataWithHexadecimalString:@"a968e55658e594d57257156a5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555559950"];

  [self.device doCmd:sendAndListen withCompletionHandler:nil];
  return;
  
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
