//
//  TestPacketSenderViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 7/31/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "PacketGeneratorViewController.h"
#import "NSData+Conversion.h"
#import "SendPacketCmd.h"

@interface PacketGeneratorViewController () {
    int testPacketNum;
    int txChannel;
    IBOutlet UILabel *testPacketNumberLabel;
    IBOutlet UISwitch *continuousSendSwitch;
    IBOutlet UISwitch *encodeDataSwitch;
    IBOutlet UITextField *channelNumberTextField;
    IBOutlet UILabel *packetData;
    NSTimer *timer;
}


@end

@implementation PacketGeneratorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updatePacketNumberLabel];
    
    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleBlackTranslucent;
    numberToolbar.items = @[[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc]initWithTitle:@"Apply" style:UIBarButtonItemStyleDone target:self action:@selector(doneChangingChannel)]];
    [numberToolbar sizeToFit];
    channelNumberTextField.inputAccessoryView = numberToolbar;
}

- (void)doneChangingChannel {
    txChannel = (channelNumberTextField.text).intValue;
    [channelNumberTextField resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updatePacketNumberLabel {
    testPacketNumberLabel.text = [NSString stringWithFormat:@"Test Packet Number: %03d", testPacketNum];
}

- (void)incrementPacketNum {
    testPacketNum += 1;
    if (testPacketNum > 255) {
        testPacketNum = 0;
    }
    [self updatePacketNumberLabel];
}

- (void)sendTestPacket {
    NSString *packetStr = [@"614C05E077" stringByAppendingFormat:@"%02x", testPacketNum];
    NSData *data = [NSData dataWithHexadecimalString:packetStr];
    //  if (encodeDataSwitch.on) {
    //    data = [MinimedPacket encodeData:data];
    //  }
    packetData.text = data.hexadecimalString;
    SendPacketCmd *cmd = [[SendPacketCmd alloc] init];
    cmd.sendChannel = txChannel;
    cmd.repeatCount = 0;
    cmd.msBetweenPackets = 0;
    [_device runSession:^(RileyLinkCmdSession * _Nonnull session) {
        [session doCmd:cmd withTimeoutMs:1000];
    }];
}

- (IBAction)sendPacketButtonPressed:(id)sender {
    [self sendTestPacket];
    [self incrementPacketNum];
}

- (void)timerFired:(id)sender {
    [self sendTestPacket];
    [self incrementPacketNum];
}

- (IBAction)continuousSendSwitchToggled:(id)sender {
    [timer invalidate];
    if (continuousSendSwitch.on) {
        timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    }
}


/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
