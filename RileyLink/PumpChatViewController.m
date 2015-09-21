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

- (MessageBase *)powerMessage
{
    return [self powerMessageWithArgs:@"00"];
}

- (MessageBase *)powerMessageWithArgs:(NSString *)args
{
    NSString *pumpId = [[Config sharedInstance] pumpID];

    NSString *packetStr = [@"a7" stringByAppendingFormat:@"%@5D%@", pumpId, args];
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
    resultsLabel.text = @"Sending wakeup packets...";

    __weak UILabel *label = resultsLabel;

    MessageSendOperation *wakeupOperation = [[MessageSendOperation alloc] initWithDevice:self.device
                                                                                 message:[self powerMessage]
                                                                       completionHandler:^(MessageSendOperation * _Nonnull operation) {
        if (operation.responsePacket != nil) {
            label.text = @"Pump acknowledged wakeup!";
        } else {
            label.text = [NSString stringWithFormat:@"Power on error: %@", operation.error];
        }
    }];

    wakeupOperation.repeatInterval = 0.078;
    wakeupOperation.responseMessageType = MESSAGE_TYPE_PUMP_STATUS_ACK;

    MessageSendOperation *wakeupArgsOperation = [[MessageSendOperation alloc] initWithDevice:self.device
                                                                                     message:[self powerMessageWithArgs:@"02010a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"]
                                                                           completionHandler:^(MessageSendOperation * _Nonnull operation) {
        if (operation.responsePacket != nil) {
            label.text = @"Power on for 10 minutes";
        } else {
            label.text = [NSString stringWithFormat:@"Power on error: %@", operation.error];
        }
    }];
    wakeupArgsOperation.responseMessageType = MESSAGE_TYPE_PUMP_STATUS_ACK;

    MessageSendOperation *modelQueryOperation = [[MessageSendOperation alloc] initWithDevice:self.device
                                                                                     message:[self modelQueryMessage]
                                                 completionHandler:^(MessageSendOperation * _Nonnull operation) {
        if (operation.responsePacket != nil) {
            NSString *version = [NSString stringWithCString:&[operation.responsePacket.data bytes][7] encoding:NSASCIIStringEncoding];

            label.text = [@"Pump Model: " stringByAppendingString:version];
        } else {
            label.text = [NSString stringWithFormat:@"Model query error: %@", operation.error];
        }
    }];
    modelQueryOperation.responseMessageType = MESSAGE_TYPE_GET_PUMP_MODEL;

    MessageSendOperation *batteryStatusOperation = [[MessageSendOperation alloc] initWithDevice:self.device
                                                                                        message:[self batteryStatusMessage]
                                                                              completionHandler:^(MessageSendOperation * _Nonnull operation) {
        if (operation.responsePacket != nil) {
            unsigned char *data = (unsigned char *)[operation.responsePacket.data bytes] + 6;

            NSInteger volts = (((int)data[1]) << 8) + data[2];
            NSString *indicator = data[0] ? @"Low" : @"Normal";
            batteryVoltage.text = [NSString stringWithFormat:@"Battery %@, %0.02f volts", indicator, volts/100.0];
        } else {
            label.text = [NSString stringWithFormat:@"Get battery error: %@", operation.error];
        }
    }];
    batteryStatusOperation.responseMessageType = MESSAGE_TYPE_GET_BATTERY;

    [self.pumpCommQueue addOperations:@[wakeupOperation,
                                        wakeupArgsOperation,
                                        modelQueryOperation,
                                        batteryStatusOperation] waitUntilFinished:NO];
}

@end
