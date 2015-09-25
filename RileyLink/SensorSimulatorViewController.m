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
  int sequenceNum;
  int glucoseHistory[GLUCOSE_HISTORY_LENGTH];
  float currentGlucose;
  float glucoseD1;
  float glucoseD2;
}

@end

@implementation SensorSimulatorViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  sequenceNum = 0;
  
  currentGlucose = 100;
  glucoseD1 = 5;
  glucoseD2 = -0.8;
  
  for (int i=0; i<GLUCOSE_HISTORY_LENGTH; i++) {
    [self updateGlucose];
  }
}

- (void)updateGlucose {
  for (int i=GLUCOSE_HISTORY_LENGTH-1; i>0; i--) {
    glucoseHistory[i] = glucoseHistory[i-1];
  }
  glucoseHistory[0] = currentGlucose;
  currentGlucose += glucoseD1;
  glucoseD1 += glucoseD2;
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
  
  d[0] = 0xab; // Normal
  d[1] = 0x0f;
  NSInteger sensorID = [sensorIDTextField.text integerValue] & 0xffffff;
  d[2] = (sensorID & 0xff0000) >> 16;
  d[3] = (sensorID & 0xff00) >> 8;
  d[4] = (sensorID & 0xff);
  d[5] = 0x0d;
  d[6] = 0x1d;
  d[7] = 0x21; // ISIG adjustment
  d[8] = (sequenceNum << 4) & 0xf0;
  for (int i=0; i<2; i++) {
    int isig = [self isigFromGlucose:glucoseHistory[i]];
    d[9 + i * 2] = isig >> 8 & 0xff;
    d[10 + i * 2] = isig & 0xff;
  }
  d[13] = 0x00;
  d[14] = 0x67;
  d[15] = 0x67;
  d[16] = 0x9d;
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
