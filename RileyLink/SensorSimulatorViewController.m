//
//  SensorSimulatorViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 9/24/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "SensorSimulatorViewController.h"
#import "NSData+Conversion.h"
#import "MinimedPacket.h"

#define GLUCOSE_HISTORY_LENGTH 9

@interface SensorSimulatorViewController () {
  IBOutlet UITextField *sensorIDTextField;
  IBOutlet UISwitch *continuousSendSwitch;

  int sequenceNum;
  int duplicateNum;
  int glucoseHistory[GLUCOSE_HISTORY_LENGTH];
  float currentGlucose;
  float glucoseD1;
  float glucoseD2;
  NSTimer *timer;
  NSArray *recorded;
  NSInteger recordIdx;
}

@end

@implementation SensorSimulatorViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  sequenceNum = 0;
  duplicateNum = 0;
  
  currentGlucose = 100;
  glucoseD1 = 5;
  glucoseD2 = -0.8;
  
  recorded = @[
               @"ab0f25c1230d1d21000b59106e0067679d110611d512a5133c1374133c12a5006be1",
               @"ab0f25c1230d1d21010b59106e0067679d110611d512a5133c1374133c12a5005ce2",
               ];
  
  recordIdx = 0;
  
  for (int i=0; i<GLUCOSE_HISTORY_LENGTH; i++) {
    [self updateGlucose];
  }
}

- (void)sendRecordedPacket {
  NSString *dataStr = recorded[recordIdx];
  [self.device setTXChannel:0];
  [_device sendPacketData:[MinimedPacket encodeData:[NSData dataWithHexadecimalString:dataStr]]];
  recordIdx+=1;
  if (recordIdx >= recorded.count) {
    recordIdx = 0;
  }
}

- (void)timerFired:(id)sender {
//  [self updateGlucose];
//  [self sendSensorPacket];
//  [self performSelector:@selector(sendSensorPacket) withObject:nil afterDelay:15];
  [self sendRecordedPacket];
}


- (IBAction)continuousSendSwitchToggled:(id)sender {
  [timer invalidate];
  if (continuousSendSwitch.on) {
    timer = [NSTimer timerWithTimeInterval:(10) target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    [self timerFired:nil];
  }
}


- (void)updateGlucose {
  for (int i=GLUCOSE_HISTORY_LENGTH-1; i>0; i--) {
    glucoseHistory[i] = glucoseHistory[i-1];
  }
  glucoseHistory[0] = currentGlucose;
  currentGlucose += glucoseD1;
  glucoseD1 += glucoseD2;
  sequenceNum += 1;
  if (sequenceNum == 8) {
    sequenceNum = 0;
  }
  duplicateNum = 0;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)sendPacketButtonPressed:(id)sender {
  [self sendSensorPacket];
}

- (int)isigFromGlucose: (float) glucose {
  return (int)(round(glucose * 166.0 / 4.0)) & 0x0000FFFF;
}

- (void)sendSensorPacket {
  [self.device setTXChannel:0];
  
  unsigned char d[32];
  
  // AB 0F 25 C1 23 0D 1D 21 00 0B 59 10 6E 00 67 67 9D 11 06 11 D5 12 A5 13 3C 13 74 13 3C 12 A5 00 XX XX
  
  d[0] = 0xab; // Normal
  d[1] = 0x0f;
  NSInteger sensorID = [sensorIDTextField.text integerValue] & 0xffffff;
  d[2] = (sensorID & 0xff0000) >> 16;
  d[3] = (sensorID & 0xff00) >> 8;
  d[4] = (sensorID & 0xff);
  d[5] = 0x0d;
  d[6] = 0x1d;
  d[7] = 0x21; // ISIG adjustment
  d[8] = ((sequenceNum << 4) & 0xf0) + duplicateNum;
  for (int i=0; i<2; i++) {
    int isig = [self isigFromGlucose:glucoseHistory[i]];
    d[9 + i * 2] = isig >> 8 & 0xff;
    d[10 + i * 2] = isig & 0xff;
  }
  d[13] = 0x00;
  d[14] = 0x67;
  d[15] = 0x67;
  d[16] = 0x9D;
  for (int i=2; i<9; i++) {
    int isig = [self isigFromGlucose:glucoseHistory[i]];
    d[17 + (i-2) * 2] = isig >> 8 & 0xff;
    d[18 + (i-2) * 2] = isig & 0xff;
  }
  d[31] = 0x00;
  // 32 & 33 are crc16
  
  NSData *data = [NSData dataWithBytes:d length:32];
  NSLog(@"data before crc16: %@", [data hexadecimalString]);

  [_device sendPacketData:[MinimedPacket encodeAndCRC16Data:data]];
  
  duplicateNum++;
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
