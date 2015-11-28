//
//  NightScoutUploader.m
//  GlucoseLink
//
//  Created by Pete Schwamb on 5/23/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//
// Based on code found in https://github.com/bewest/share2nightscout-bridge

#import "NightScoutUploader.h"
#import "NSString+Hashes.h"
#import "MinimedPacket.h"
#import "PumpStatusMessage.h"
#import "ISO8601DateFormatter.h"
#import "MeterMessage.h"
#import "RileyLinkBLEManager.h"
#import "Config.h"
#import "NSData+Conversion.h"
#import "PumpCommManager.h"
#import "PumpModel.h"
#import "HistoryPage.h"
#import "PumpHistoryEventBase.h"
#import "NSData+Conversion.h"
#import "NightScoutBolus.h"
#import "NightScoutPump.h"

#define RECORD_RAW_PACKETS NO

typedef NS_ENUM(unsigned int, DexcomSensorError) {
  DX_SENSOR_NOT_ACTIVE = 1,
  DX_SENSOR_NOT_CALIBRATED = 5,
  DX_BAD_RF = 12,
};


@interface NightScoutUploader ()

@property (strong, nonatomic) NSMutableArray *entries;
@property (strong, nonatomic) NSMutableArray *treatmentsQueue;
@property (strong, nonatomic) ISO8601DateFormatter *dateFormatter;
@property (nonatomic, assign) NSInteger codingErrorCount;
@property (strong, nonatomic) NSString *pumpSerial;
@property (strong, nonatomic) NSData *lastSGV;
@property (strong, nonatomic) MeterMessage *lastMeterMessage;
@property (strong, nonatomic) NSTimer *pumpPollTimer;
@property (strong, nonatomic) RileyLinkBLEDevice *activeRileyLink;
@property (strong, nonatomic) NSTimer *getHistoryTimer;
@property (strong, nonatomic) PumpCommManager *commManager;
@property (strong, nonatomic) NSString *pumpModel;


@end


@implementation NightScoutUploader

static NSString *defaultNightscoutEntriesPath = @"/api/v1/entries.json";
static NSString *defaultNightscoutTreatmentPath = @"/api/v1/treatments.json";
static NSString *defaultNightscoutBatteryPath = @"/api/v1/devicestatus.json";

- (instancetype)init
{
  self = [super init];
  if (self) {
    _entries = [[NSMutableArray alloc] init];
    _treatmentsQueue = [[NSMutableArray alloc] init];
    _dateFormatter = [[ISO8601DateFormatter alloc] init];
    _dateFormatter.includeTime = YES;
    _dateFormatter.useMillisecondPrecision = YES;
    _dateFormatter.defaultTimeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(packetReceived:)
                                                 name:RILEYLINK_EVENT_PACKET_RECEIVED
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnected:) name:RILEYLINK_EVENT_DEVICE_CONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDisconnected:) name:RILEYLINK_EVENT_DEVICE_DISCONNECTED object:nil];
    
    
    self.getHistoryTimer = [NSTimer scheduledTimerWithTimeInterval:(5.0 * 60) target:self selector:@selector(fetchHistory:) userInfo:nil repeats:YES];
    
    [self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:10];
    
    //[self performSelector:@selector(testDecodePacket) withObject:nil afterDelay:1];

  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Testing

- (void)testDecodePacket {
  NSData *page = [NSData dataWithHexadecimalString:@"0100200020000000a4f64d1a0f0ad692eb2e1a0f5bd6a3eb0e1a0f145000b44b5020002c00001c0030965c0b1430c00c3ac05852d00100300030001c00a4eb4e1a0f5b009fc20f1a0f145000b44b5000002c000000002c965c0e301bc01443c00c4dc05865d001002c002c0044009fc24f1a0f7b0680c0101a0f200e005b00adc8127a0f0950008c4b500000180000000018965c0e2cc1c030d5c014fdc00c07d00100180018000000adc8527a0f0a2f82e4321a8f5b2f8ce4121a0f0051008c4b505000000000180038965c11181fc02cddc030f1c01419d00c23d001004800480018008de4521a0f210097f9121a0f030000005182fa321a0f7b068ac2131a0f200e00030003000380c2131a0f7b0780c0151a0f2a11000adbabeb357a0f3f1babeb757a0fc527ad5bdb80ec151a0f005000b455502000000000000020965c1448bcc018dac02c98d030acd014d4d00cded0010028002800000080ec551a0f7b0080c0001b0f000e000700000279ba8f0000006eba8f0500b644db060000027901012901783b005600b800900030000004030100040000000000000000d62f00000000000000007b0180c0011b0f0208007b0280c0041b0f080e000a5eb1d0257b0f3f0bb1d0c57b0fc527ad7b0380c0061b0f0c10007b0480c00a1b0f140d000808a2c40a1b0f000e00020800080e000c1000140d00180a00200e002a1100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000908a2c40a1b0f000e00020800080e000c1000140b00180a00200e002a1100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007b04a3c40a1b0f140b000aeca2e42b1b0f5beca8e40b1b0f005000b44b502c0000000000002c9601002c002c000000a8e44b1b0f7b0580c00c1b0f180a000a7da5c42f7b0f3f0fa5c4af7b0fc527ad5b7da7cf0f7b0f195000b44b500000340000000034965c052cdcc00100340034000000a8cf4f7b0f7b0680c0101b0f200e000a4a83e0307b0f3f0983e0507b0fc527ad5b00a9d0117b0f1450008c4b500000380000000038965c083479c02c55d00100380038001000a9d0517b0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009f0b"];
  self.pumpModel = @"551";
  [self decodeHistoryPage:page];
}


#pragma mark - Device updates

- (void)deviceConnected:(NSNotification *)note
{
  self.activeRileyLink = [note object];
}

- (void)deviceDisconnected:(NSNotification *)note
{
  if (self.activeRileyLink == [note object]) {
    self.activeRileyLink = nil;
  }
}

- (void)packetReceived:(NSNotification*)notification {
  NSDictionary *attrs = notification.userInfo;
  MinimedPacket *packet = attrs[@"packet"];
  RileyLinkBLEDevice *device = notification.object;
  [self addPacket:packet fromDevice:device];
}

#pragma mark - Polling

- (void) fetchHistory:(id)sender {
  if (self.activeRileyLink && self.activeRileyLink.state != RileyLinkStateConnected) {
    self.activeRileyLink = nil;
  }
  
  if (self.activeRileyLink == nil) {
    for (RileyLinkBLEDevice *device in [[RileyLinkBLEManager sharedManager] rileyLinkList]) {
      if (device.state == RileyLinkStateConnected) {
        self.activeRileyLink = device;
        break;
      }
    }
  }
  
  if (self.activeRileyLink == nil) {
    NSLog(@"No connected rileylinks to attempt to pull history with. Aborting poll.");
    return;
  }
  
  NSLog(@"Using RileyLink \"%@\" to poll history.", self.activeRileyLink.name);
  
  if (self.commManager != nil && self.commManager.device != self.activeRileyLink) {
    // We need a new commManager for the new RL we want to talk to.
    self.commManager = nil;
  }
  
  if (self.commManager == nil) {
    self.commManager = [[PumpCommManager alloc]
                        initWithPumpId:[[Config sharedInstance] pumpID]
                        andDevice:self.activeRileyLink];
  }
  
  [self.commManager getPumpModel:^(NSString* returnedModel) {
    if (returnedModel) {
      self.pumpModel = returnedModel;
      NSLog(@"Got model: %@", returnedModel);
    } else {
      NSLog(@"Get pump model failed.");
    }
  }];

  
  [self.commManager dumpHistory:^(NSDictionary * _Nonnull res) {
    NSData *page = res[@"page0"];
    [self decodeHistoryPage:page];
  }];
  
}

#pragma mark - Decoding

- (void) decodeHistoryPage:(NSData*)data {
  NSLog(@"Got page: %@", [data hexadecimalString]);
  
  if (self.pumpModel == nil) {
    NSLog(@"Cannot decode history page without knowing the pump model. pumpModel == nil!");
    return;
  }
  
  PumpModel *m = [PumpModel find:self.pumpModel];
  HistoryPage *page = [[HistoryPage alloc] initWithData:data andPumpModel:m];
  
  if (![page isCRCValid]) {
    NSLog(@"Invalid CRC for history page %@", [data hexadecimalString]);
    return;
  }
  
  NSArray *events = [page decode];
  
  NSMutableArray *jsonEvents = [NSMutableArray array];
  
//  for (PumpHistoryEventBase *event in events) {
//    NSLog(@"Event: %@", [event asJSON]);
//  }
//  return ;

  
  // Processing code expects history in newest first order
  NSEnumerator *enumerator = [events reverseObjectEnumerator];
  for (PumpHistoryEventBase *event in enumerator) {
    [jsonEvents addObject:[event asJSON]];
  }
  
  NSArray *treatments = jsonEvents;
  
  treatments = [NightScoutPump process:treatments];
  treatments = [NightScoutBolus process:treatments];
  
  for (NSMutableDictionary *treatment in treatments) {
    NSLog(@"Treatment: %@", treatment);

    [self addTreatment:treatment fromModel:m];
  }
  [self flushTreatments];
}


- (void) addTreatment:(NSMutableDictionary*)treatment fromModel:(PumpModel*)m {
  treatment[@"enteredBy"] = [@"rileylink://medtronic/" stringByAppendingString:m.name];
  treatment[@"created_at"] = treatment[@"timestamp"];
  [self.treatmentsQueue addObject:treatment];
}

//var DIRECTIONS = {
//NONE: 0
//  , DoubleUp: 1
//  , SingleUp: 2
//  , FortyFiveUp: 3
//  , Flat: 4
//  , FortyFiveDown: 5
//  , SingleDown: 6
//  , DoubleDown: 7
//  , 'NOT COMPUTABLE': 8
//  , 'RATE OUT OF RANGE': 9
//};


- (NSString*)trendToDirection:(GlucoseTrend)trend {
  switch (trend) {
    case GLUCOSE_TREND_NONE:
      return @"";
    case GLUCOSE_TREND_UP:
      return @"SingleUp";
    case GLUCOSE_TREND_DOUBLE_UP:
      return @"DoubleUp";
    case GLUCOSE_TREND_DOWN:
      return @"SingleDown";
    case GLUCOSE_TREND_DOUBLE_DOWN:
      return @"DoubleDown";
    default:
      return @"NOT COMPUTABLE";
      break;
  }
}

//  Entries [ { sgv: 375,
//    date: 1432421525000,
//    dateString: '2015-05-23T22:52:05.000Z',
//    trend: 1,
//    direction: 'DoubleUp',
//    device: 'share2',
//    type: 'sgv' } ]

- (void)addPacket:(MinimedPacket*)packet fromDevice:(RileyLinkBLEDevice*)device {
  
  if (![packet isValid]) {
    return;
  }
  
  if (RECORD_RAW_PACKETS) {
    [self storeRawPacket:packet fromDevice:device];
  }
  
  if ([packet packetType] == PACKET_TYPE_PUMP && [packet messageType] == MESSAGE_TYPE_PUMP_STATUS) {
    [self handlePumpStatus:packet fromDevice:device withRSSI:packet.rssi];
  } else if ([packet packetType] == PACKET_TYPE_METER) {
    [self handleMeterMessage:packet];
  }
  
  [self flushEntries];
}

- (void) storeRawPacket:(MinimedPacket*)packet fromDevice:(RileyLinkBLEDevice*)device {
  NSDate *now = [NSDate date];
  NSTimeInterval seconds = [now timeIntervalSince1970];
  NSNumber *epochTime = @(seconds * 1000);
  
  NSDictionary *entry =
  @{@"date": epochTime,
    @"dateString": [self.dateFormatter stringFromDate:now],
    @"rfpacket": [packet.data hexadecimalString],
    @"device": device.deviceURI,
    @"rssi": @(packet.rssi),
    @"type": @"rfpacket"
    };
  [self.entries addObject:entry];
}

- (void) handlePumpStatus:(MinimedPacket*)packet fromDevice:(RileyLinkBLEDevice*)device withRSSI:(NSInteger)rssi {
  PumpStatusMessage *msg = [[PumpStatusMessage alloc] initWithData:packet.data];
  NSNumber *epochTime = @([msg.measurementTime timeIntervalSince1970] * 1000);
  
  if ([packet.address isEqualToString:[[Config sharedInstance] pumpID]]) {
    
    NSInteger glucose = msg.glucose;
    switch ([msg sensorStatus]) {
      case SENSOR_STATUS_HIGH_BG:
        glucose = 401;
        break;
      case SENSOR_STATUS_WEAK_SIGNAL:
        glucose = DX_BAD_RF;
        break;
      case SENSOR_STATUS_METER_BG_NOW:
        glucose = DX_SENSOR_NOT_CALIBRATED;
        break;
      case SENSOR_STATUS_LOST:
        glucose = DX_SENSOR_NOT_ACTIVE;
        break;
      default:
        break;
    }
    
    NSDictionary *entry =
    @{@"date": epochTime,
      @"dateString": [self.dateFormatter stringFromDate:msg.measurementTime],
      @"sgv": @(glucose),
      @"previousSGV": @(msg.previousGlucose),
      @"direction": [self trendToDirection:msg.trend],
      @"device": device.deviceURI,
      @"rssi": @(rssi),
      @"type": @"sgv"
      };
    [self.entries addObject:entry];
    
    // Also add pumpStatus entry
    NSMutableDictionary *pumpStatusEntry =
      [@{@"date": epochTime,
        @"dateString": [self.dateFormatter stringFromDate:msg.measurementTime],
        @"receivedAt": [self.dateFormatter stringFromDate:[NSDate date]],
        @"sensorAge": @(msg.sensorAge),
        @"sensorRemaining": @(msg.sensorRemaining),
        @"insulinRemaining": @(msg.insulinRemaining),
        @"device": device.deviceURI,
        @"iob": @(msg.activeInsulin),
        @"sensorStatus": msg.sensorStatusString,
        @"batteryPct": @(msg.batteryPct),
        @"rssi": @(rssi),
        @"pumpStatus": [msg.data hexadecimalString],
        @"type": @"pumpStatus",
        } mutableCopy];
    if (msg.nextCal != nil) {
      pumpStatusEntry[@"nextCal"] = [self.dateFormatter stringFromDate:msg.nextCal];
    }
    [self.entries addObject:pumpStatusEntry];
    
    
  } else {
    NSLog(@"Dropping mysentry packet for pump: %@", packet.address);
  }
}

- (void) handleMeterMessage:(MinimedPacket*)packet {
  MeterMessage *msg = [[MeterMessage alloc] initWithData:packet.data];
  msg.dateReceived = [NSDate date];
  NSTimeInterval seconds = [msg.dateReceived timeIntervalSince1970];
  NSNumber *epochTime = @(seconds * 1000);
  NSDictionary *entry =
  @{@"date": epochTime,
    @"dateString": [self.dateFormatter stringFromDate:msg.dateReceived],
    @"mbg": @(msg.glucose),
    @"device": @"Contour Next Link",
    @"type": @"mbg"
    };
  
  // Skip duplicates
  if (_lastMeterMessage &&
      [msg.dateReceived timeIntervalSinceDate:_lastMeterMessage.dateReceived] &&
      msg.glucose == _lastMeterMessage.glucose) {
    entry = nil;
  } else {
    [self.entries addObject:entry];
    _lastMeterMessage = msg;
  }
}

#pragma mark - Uploading



- (void) flushEntries {
  
  if (self.entries.count == 0) {
    return;
  }
  
  NSArray *inFlightEntries = self.entries;
  self.entries = [[NSMutableArray alloc] init];
  [self reportJSON:inFlightEntries toNightScoutEndpoint:defaultNightscoutEntriesPath completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
    if (httpResponse.statusCode != 200) {
      NSLog(@"Requeuing %d sgv entries: %@", inFlightEntries.count, error);
      [self.entries addObjectsFromArray:inFlightEntries];
    } else {
      NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      NSLog(@"Submitted %d entries to nightscout: %@", inFlightEntries.count, resp);
    }
  }];
}

- (void) flushTreatments {
  
  if (self.treatmentsQueue.count == 0) {
    return;
  }
  
  NSArray *inFlightTreatments = self.treatmentsQueue;
  self.treatmentsQueue = [NSMutableArray array];
  [self reportJSON:inFlightTreatments toNightScoutEndpoint:defaultNightscoutTreatmentPath completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
    if (httpResponse.statusCode != 200) {
      NSLog(@"Requeuing %d treatments: %@", inFlightTreatments.count, error);
      [self.treatmentsQueue addObjectsFromArray:inFlightTreatments];
    } else {
      NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      NSLog(@"Submitted %d treatments to nightscout: %@", inFlightTreatments.count, resp);
    }
  }];
}


- (void) reportJSON:(NSArray*)outgoingJSON toNightScoutEndpoint:(NSString*)endpoint
completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
  NSURL *uploadURL = [NSURL URLWithString:endpoint
                            relativeToURL:[NSURL URLWithString:self.siteURL]];
  NSMutableURLRequest *request = [[NSURLRequest requestWithURL:uploadURL] mutableCopy];
  NSError *error;
  NSData *sendData = [NSJSONSerialization dataWithJSONObject:outgoingJSON options:NSJSONWritingPrettyPrinted error:&error];
  NSString *jsonPost = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
  NSLog(@"Posting to %@, %@", [uploadURL absoluteString], jsonPost);
  [request setHTTPMethod:@"POST"];
  
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
  [request setValue:[self.APISecret sha1] forHTTPHeaderField:@"api-secret"];
  
  [request setHTTPBody: sendData];
  
  [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completionHandler] resume];
}

@end
