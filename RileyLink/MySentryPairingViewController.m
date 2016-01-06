//
//  MySentryPairingViewController.m
//  RileyLink
//
//  Created by Nathan Racklyeft on 8/14/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "MySentryPairingViewController.h"
#import "Config.h"
#import "MinimedPacket.h"
#import "NSData+Conversion.h"
#import "RileyLinkBLEManager.h"
#import "GetPacketCmd.h"
#import "SendAndListenCmd.h"
#import "DeviceLinkMessage.h"
#import "FindDeviceMessage.h"
#import "PumpStatusMessage.h"

typedef NS_ENUM(NSUInteger, PairingState) {
  PairingStateComplete,
  PairingStateNeedsConfig,
  PairingStateReady,
  PairingStateStarted,
  PairingStateReceivedFindPacket,
  PairingStateReceivedLinkPacket
};


@interface MySentryPairingViewController () <UITextFieldDelegate> {
  BOOL wasDismissed;
}

@property (weak, nonatomic) IBOutlet UILabel *instructionLabel;
@property (weak, nonatomic) IBOutlet UITextField *deviceIDTextField;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) UITapGestureRecognizer *flailGestureRecognizer;

@property (nonatomic) PairingState state;
@property (nonatomic) unsigned char sendCounter;

@end

@implementation MySentryPairingViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.sendCounter = 0;
  self.state = PairingStateNeedsConfig;
  
  self.deviceIDTextField.text = [self.device.peripheral.identifier.UUIDString substringToIndex:6];
  self.deviceIDTextField.delegate = self;
  [self.view addGestureRecognizer:self.flailGestureRecognizer];
  
  [self textFieldDidEndEditing:self.deviceIDTextField];
}

- (void)viewDidDisappear:(BOOL)animated {
  wasDismissed = YES;
}

- (void)listenForPairing {
  if (wasDismissed) {
    return;
  }
  GetPacketCmd *cmd = [[GetPacketCmd alloc] init];
  cmd.listenChannel = 2;
  cmd.timeoutMS = 30000;
  
  [self.device doCmd:cmd withCompletionHandler:^(CmdBase * _Nonnull cmd) {
    if (cmd.response) {
      MinimedPacket *rxPacket = [[MinimedPacket alloc] initWithData:cmd.response];
      [self packetReceived:rxPacket];
    }
  }];
}

- (void)handleResponse:(NSData*)response {
  if (response) {
    MinimedPacket *rxPacket = [[MinimedPacket alloc] initWithData:response];
    [self packetReceived:rxPacket];
  }
}

- (UITapGestureRecognizer *)flailGestureRecognizer
{
  if (!_flailGestureRecognizer) {
    _flailGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeKeyboard:)];
    _flailGestureRecognizer.cancelsTouchesInView = NO;
    _flailGestureRecognizer.enabled = NO;
  }
  return _flailGestureRecognizer;
}

- (void)setState:(PairingState)state {
  if (state == _state) {
    return;
  }
  
  _state = state;
  
  switch (state) {
    case PairingStateNeedsConfig:
      self.startButton.enabled = NO;
      self.startButton.hidden = YES;
      self.instructionLabel.text = NSLocalizedString(@"Enter a 6-digit numeric value to identify your MySentry.",
                                                     @"Device ID instruction");
      self.instructionLabel.hidden = NO;
      break;
    case PairingStateReady:
      self.startButton.enabled = YES;
      self.startButton.hidden = NO;
      self.progressView.progress = 0;
      
      self.instructionLabel.hidden = YES;
      break;
    case PairingStateStarted:
      self.startButton.enabled = NO;
      self.startButton.hidden = YES;
      self.deviceIDTextField.enabled = NO;
      [self.progressView setProgress:1.0 / 4.0 animated:YES];
      
      self.instructionLabel.text = NSLocalizedString(@"On your pump, go to the Find Device screen and select \"Find Device\"."
                                                     @"\n"
                                                     @"\nMain Menu >"
                                                     @"\nUtilities >"
                                                     @"\nConnect Devices >"
                                                     @"\nOther Devices >"
                                                     @"\nOn >"
                                                     @"\nFind Device",
                                                     @"Pump find device instruction");
      self.instructionLabel.hidden = NO;
      break;
    case PairingStateReceivedFindPacket:
      [self.progressView setProgress:2.0 / 4.0 animated:YES];
      
      self.instructionLabel.text = NSLocalizedString(@"Pairing in process, please wait.",
                                                     @"Pairing waiting instruction");
      break;
    case PairingStateReceivedLinkPacket:
      [self.progressView setProgress:3.0 / 4.0 animated:YES];
      self.instructionLabel.text = NSLocalizedString(@"Pump accepted pairing. "
                                                     @"Waiting for MySentry update from pump. "
                                                     @"This could take up to five minutes...",
                                                     @"Pairing waiting instruction");
      break;
    case PairingStateComplete:
      [self.progressView setProgress:4.0 / 4.0 animated:YES];
      
      self.instructionLabel.text = NSLocalizedString(@"Congratulations! Pairing is complete.",
                                                     @"Pairing waiting instruction");
      break;
  }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  self.flailGestureRecognizer.enabled = YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  self.flailGestureRecognizer.enabled = NO;
  
  if (textField.text.length == 6) {
    self.state = PairingStateReady;
  } else if (PairingStateReady == self.state) {
    self.state = PairingStateNeedsConfig;
  }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
  NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
  
  if (newString.length > 6) {
    return NO;
  } else if (newString.length == 6) {
    textField.text = newString;
    [textField resignFirstResponder];
    return NO;
  } else if (PairingStateReady == self.state) {
    self.state = PairingStateNeedsConfig;
  }
  
  return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  return YES;
}

#pragma mark - Actions

- (void)packetReceived:(MinimedPacket *)packet {
  
  BOOL handled = NO;
  
  if (packet &&
      PacketTypeSentry == packet.packetType &&
      [packet.address isEqualToString:[Config sharedInstance].pumpID])
  {
    MessageBase *msg = [packet toMessage];
    if ([msg class] == [FindDeviceMessage class]) {
      [self handleFindDevice:(FindDeviceMessage*)msg];
      handled = YES;
    }
    else if ([msg class] == [DeviceLinkMessage class]) {
      [self handleDeviceLink:(DeviceLinkMessage*)msg];
      handled = YES;
    }
    else if ([msg class] == [PumpStatusMessage class]) {
      [self handlePumpStatus:(PumpStatusMessage*)msg];
      handled = YES;
    }
  }
  if (!handled) {
    // Other random packet; ignore and start listening again.
    [self performSelector:@selector(listenForPairing) withObject:nil afterDelay:0];
  }
}

- (CmdBase *)makeCommandForAckAndListen:(uint8_t)sequence forMessageType:(uint8_t)messageType {
  NSString *replyString = [NSString stringWithFormat:@"%02x%@%02x%02x%@00%02x000000",
                           PacketTypeSentry,
                           [Config sharedInstance].pumpID,
                           MESSAGE_TYPE_ACK,
                           sequence,
                           self.deviceIDTextField.text,
                           messageType
                           ];
  NSData *data = [NSData dataWithHexadecimalString:replyString];
  SendAndListenCmd *send = [[SendAndListenCmd alloc] init];
  send.sendChannel = 0;
  send.timeoutMS = 180;
  send.listenChannel = 2;
  send.packet = [MinimedPacket encodeData:data];
  return send;
}

- (void)runCommand:(CmdBase*) cmd {
  [self.device doCmd:cmd withCompletionHandler:^(CmdBase * _Nonnull cmd) {
    if (cmd.response) {
      [self handleResponse:cmd.response];
    }
  }];
}

- (void)handleFindDevice:(FindDeviceMessage *)msg
{
  if (PairingStateStarted == self.state) {
    self.state = PairingStateReceivedFindPacket;
  }
  
  CmdBase *cmd = [self makeCommandForAckAndListen:msg.sequence forMessageType:(uint8_t)msg.messageType];
  
  [self performSelector:@selector(runCommand:) withObject:cmd afterDelay:1];
  //[self runCommand:cmd];
}

- (void)handleDeviceLink:(DeviceLinkMessage *)msg
{
  if (PairingStateReceivedFindPacket == self.state) {
    self.state = PairingStateReceivedLinkPacket;
  }
  
  CmdBase *cmd = [self makeCommandForAckAndListen:msg.sequence forMessageType:(uint8_t)msg.messageType];
  [self performSelector:@selector(runCommand:) withObject:cmd afterDelay:1];
  //[self runCommand:cmd];
}

- (void)handlePumpStatus:(PumpStatusMessage *)msg {
  if (PairingStateReceivedLinkPacket == self.state) {
    self.state = PairingStateComplete;
  }
  CmdBase *cmd = [self makeCommandForAckAndListen:0 forMessageType:(uint8_t)msg.messageType];
  [self performSelector:@selector(runCommand:) withObject:cmd afterDelay:1];
  //[self runCommand:cmd];
}

- (void)closeKeyboard:(id)sender
{
  [self.view endEditing:YES];
}

- (IBAction)startPairing:(id)sender {
  if (PairingStateReady == self.state) {
    self.state = PairingStateStarted;
    [self listenForPairing];
  }
}

@end
