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

- (MessageBase *)buttonPressMessage
{
  return [self buttonPressMessageWithArgs:@"00"];
}

- (MessageBase *)buttonPressMessageWithArgs:(NSString *)args
{
  NSString *pumpId = [[Config sharedInstance] pumpID];
  
  NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@5B%@", pumpId, args];
  NSData *data = [NSData dataWithHexadecimalString:packetStr];
  
  return [[MessageBase alloc] initWithData:data];
}

- (MessageBase *)modelQueryMessage
{
    NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@%02x00", [[Config sharedInstance] pumpID], MESSAGE_TYPE_GET_PUMP_MODEL];
    NSData *data = [NSData dataWithHexadecimalString:packetStr];

    return [[MessageBase alloc] initWithData:data];
}

- (MessageBase *)batteryStatusMessage
{
    NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@%02x00", [[Config sharedInstance] pumpID], MESSAGE_TYPE_GET_BATTERY];
    NSData *data = [NSData dataWithHexadecimalString:packetStr];

    return [[MessageBase alloc] initWithData:data];
}

- (IBAction)queryPumpButtonPressed:(id)sender {
    [self enqueuePumpMessages];
}


- (void)enqueuePumpMessages {
  PumpCommManager *mgr = [[PumpCommManager alloc] initWithPumpId:[[Config sharedInstance] pumpID] andDevice:self.device];
  [mgr wakeup:300];
  
//  MessageSendOperation *buttonPressOperation = [[MessageSendOperation alloc] initWithDevice:self.device
//                                                                               message:[self buttonPressMessage]
//                                                                     completionHandler:^(MessageSendOperation * _Nonnull operation) {
//                                                                       if (operation.responsePacket != nil) {
//                                                                         [self updateStatusMessage:@"Pump acknowledged button press (no args)!"];
//                                                                       } else {
//                                                                         [self updateStatusMessage:[NSString stringWithFormat:@"Error sending button press: %@", operation.error]];
//                                                                       }
//                                                                     }];
//  buttonPressOperation.responseMessageType = MESSAGE_TYPE_PUMP_STATUS_ACK;
//  
//  MessageSendOperation *buttonPressArgsOperation = [[MessageSendOperation alloc] initWithDevice:self.device
//                                                                                   message:[self buttonPressMessageWithArgs:@"0104000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"]
//                                                                         completionHandler:^(MessageSendOperation * _Nonnull operation) {
//                                                                           if (operation.responsePacket != nil) {
//                                                                             [self updateStatusMessage:@"button press down!"];
//                                                                           } else {
//                                                                             [self updateStatusMessage:[NSString stringWithFormat:@"Button press error: %@", operation.error]];
//                                                                           }
//                                                                         }];
//  buttonPressArgsOperation.responseMessageType = MESSAGE_TYPE_PUMP_STATUS_ACK;
// 
//  
//  
//  
//
//    MessageSendOperation *modelQueryOperation = [[MessageSendOperation alloc] initWithDevice:self.device
//                                                                                     message:[self modelQueryMessage]
//                                                 completionHandler:^(MessageSendOperation * _Nonnull operation) {
//        if (operation.responsePacket != nil) {
//            NSString *version = [NSString stringWithCString:&[operation.responsePacket.data bytes][7] encoding:NSASCIIStringEncoding];
//
//            [self updateStatusMessage:[@"Pump Model: " stringByAppendingString:version]];
//        } else {
//            [self updateStatusMessage:[NSString stringWithFormat:@"Model query error: %@", operation.error]];
//        }
//    }];
//    modelQueryOperation.responseMessageType = MESSAGE_TYPE_GET_PUMP_MODEL;
//
//    MessageSendOperation *batteryStatusOperation = [[MessageSendOperation alloc] initWithDevice:self.device
//                                                                                        message:[self batteryStatusMessage]
//                                                                              completionHandler:^(MessageSendOperation * _Nonnull operation) {
//        if (operation.responsePacket != nil) {
//            unsigned char *data = (unsigned char *)[operation.responsePacket.data bytes] + 6;
//
//            NSInteger volts = (((int)data[1]) << 8) + data[2];
//            NSString *indicator = data[0] ? @"Low" : @"Normal";
//            batteryVoltage.text = [NSString stringWithFormat:@"Battery %@, %0.02f volts", indicator, volts/100.0];
//        } else {
//            [self updateStatusMessage:[NSString stringWithFormat:@"Get battery error: %@", operation.error]];
//        }
//    }];
//    batteryStatusOperation.responseMessageType = MESSAGE_TYPE_GET_BATTERY;
//
//    [self.pumpCommQueue addOperations:@[
//                                        wakeupOperation,
//                                        wakeupArgsOperation,
//                                        buttonPressOperation,
//                                        buttonPressArgsOperation,
//                                        modelQueryOperation,
//                                        batteryStatusOperation
//                                        ] waitUntilFinished:NO];
}

@end
