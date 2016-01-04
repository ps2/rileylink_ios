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


@interface NightScoutUploader () {
  BOOL dumpHistoryScheduled;
}

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
@property (strong, nonatomic) NSMutableSet *sentTreatments;


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
    _sentTreatments = [NSMutableSet set];
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
    
    
    // This is for doing a dumb 5-min history poll
    //self.getHistoryTimer = [NSTimer scheduledTimerWithTimeInterval:(5.0 * 60) target:self selector:@selector(fetchHistory:) userInfo:nil repeats:YES];
    
    // This triggers one dump right away (in 10s).d
    //[self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:10];
    
    // This is to just test decoding history
    //[self performSelector:@selector(testDecodeHistory) withObject:nil afterDelay:1];

  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Testing

- (void)testDecodeHistory {
  NSData *page = [NSData dataWithHexadecimalString:@"7b000040000310000e00070000042b02900000006e02900511119c6c0d0000042b01431e02e8460087016c017c0000000004090000040000000000000000d08600000000000000007b0100400103100208007b020040040310080e007b0300400603100c10000a0218552863903f201855486310c527ad5b020758086310005100784b5038000000000000389601003800380000000758486310190000410903101a0012500903101a012c500903107b032c500903100c10000a7004512903905b700651090310005100784b50740000000028004c965c080234c0363ec001004c004c002800065149031082010953090310001234567882010b5309031000a200069582010d5309031002a210144882010f5309031002a20014488101275409031000a2d577087d01275409031000a2d57708000000000000000000000000000000000000000000000000007d01135509031000a2d57708000000000000000000000000000000000000000000000000007b0400400a0310140b005b00154c0a63100a5000784b500000200000000020965c0b4c39c0026bc03675c00100200020004800154c4a63107b0500400c0310180a005b002c660e0310285000b44b500000580000000058965c0e2011d04c43d00275d0367fd001005800580000002c664e03107b060040100310200e000a5824703163903f2b2470116310c527ad5b583170110310175100784b5064004c00000000b0965c0858c1c020cfd00100b000b000000031705103102100006a1203100300000048206a3203107b06226d120310200e000300030003186d1203107b0700401303102610000acc24423363103f192442936310c527ad5b00216f1363100f5000784b500000300000000030965c08b07ac05838d00100300030002c00216f5363107b0800401503102a13000abd05513503100ad011513503105bd02c51156310005000b455501800000000180000965c0b305cc0b0d4c05892d001001800180018002c515563100ae9175c3603105be9185c160310005000b455502400000000140010965c0e1849c030a3c0b01bd058d9d00100100010001400195c5603100ad83a5e3663103f1b3a5e166310c527ad8201236116031000a2d577088101036216031000a2d577087d01036216031000a2d57708000000000000000000000000000000000000000000000000008201076816031000a2d577088101346816031000a2d577087d01346816031000a2d57708000000000000000000000000000000000000000000000000000adc0a753603105bdc0d75160310005000b455502000000000180008965c0e101cc01862c030bcc0b034d001000800080018000d75560310000000000000000000000000000000000000000000000000000000000000000000000000000000000cfb"];
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
  dumpHistoryScheduled = NO;
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

  
  [self.commManager dumpHistoryPage:0 completionHandler:^(NSDictionary * _Nonnull res) {
    if ([res[@"totalErrorCount"] intValue] == 0) {
      NSData *page = res[@"pageData"];
      [self decodeHistoryPage:page];
    } else {
      NSLog(@"dumpHistory failed: %@", res);
    }
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
  
  if ([self.sentTreatments member:treatment]) {
    NSLog(@"Already sent %@", treatment);
  } else {
    [self.treatmentsQueue addObject:treatment];
  }
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
    // Just got a MySentry packet; in 30s would be a good time to poll.
    if (!dumpHistoryScheduled) {
      [self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:30];
      dumpHistoryScheduled = YES;
    }

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
      [self.sentTreatments addObjectsFromArray:inFlightTreatments];
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
