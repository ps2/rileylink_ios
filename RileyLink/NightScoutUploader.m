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
#import "PumpState.h"
#import "PumpModel.h"
#import "PumpOps.h"
#import "HistoryPage.h"
#import "PumpHistoryEventBase.h"
#import "NSData+Conversion.h"
#import "NightScoutBolus.h"
#import "NightScoutPump.h"
#import "AppDelegate.h"

#define RECORD_RAW_PACKETS NO

typedef NS_ENUM(unsigned int, DexcomSensorError) {
  DX_SENSOR_NOT_ACTIVE = 1,
  DX_SENSOR_NOT_CALIBRATED = 5,
  DX_BAD_RF = 12,
};


@interface NightScoutUploader () {
  BOOL dumpHistoryScheduled;
  NSDate *lastHistoryAttempt;
}

@property (strong, nonatomic) NSMutableArray *entries;
@property (strong, nonatomic) NSMutableArray *deviceStatuses;
@property (strong, nonatomic) NSMutableArray *treatmentsQueue;
@property (strong, nonatomic) ISO8601DateFormatter *dateFormatter;
@property (nonatomic, assign) NSInteger codingErrorCount;
@property (strong, nonatomic) NSString *pumpSerial;
@property (strong, nonatomic) NSData *lastSGV;
@property (strong, nonatomic) MeterMessage *lastMeterMessage;
@property (strong, nonatomic) NSTimer *pumpPollTimer;
@property (strong, nonatomic) RileyLinkBLEDevice *activeRileyLink;
@property (strong, nonatomic) NSTimer *getHistoryTimer;
@property (strong, nonatomic) NSString *pumpModel;
@property (strong, nonatomic) NSMutableSet *sentTreatments;
@property (nonatomic, strong) PumpOps *pumpOps;



@end


@implementation NightScoutUploader

static NSString *defaultNightscoutEntriesPath = @"/api/v1/entries.json";
static NSString *defaultNightscoutTreatmentPath = @"/api/v1/treatments.json";
static NSString *defaultNightscoutDeviceStatusPath = @"/api/v1/devicestatus.json";

- (instancetype)init
{
  self = [super init];
  if (self) {
    _entries = [[NSMutableArray alloc] init];
    _sentTreatments = [NSMutableSet set];
    _treatmentsQueue = [[NSMutableArray alloc] init];
    _deviceStatuses = [[NSMutableArray alloc] init];
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceReady:) name:RILEYLINK_EVENT_DEVICE_READY object:nil];
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    lastHistoryAttempt = [NSDate date];
    self.getHistoryTimer = [NSTimer scheduledTimerWithTimeInterval:(5.0 * 60) target:self selector:@selector(timerTriggered:) userInfo:nil repeats:YES];
    
    // This triggers one dump right away (in 10s).d
    //[self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:10];
    
    // This is to just test decoding history
    //[self performSelector:@selector(testDecodeHistory) withObject:nil afterDelay:1];
    
    // Test storing MySentry packet:
    //[self performSelector:@selector(testHandleMySentry) withObject:nil afterDelay:10];
    
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Testing

- (void)testHandleMySentry {
  NSMutableData *dataWithHeader = [[NSData dataWithHexadecimalString:@"0101"] mutableCopy];
  NSData *packet = [NSData dataWithHexadecimalString:@"a259705504e9401334001001050000000001d7040205e4000000000054000001240000000000000000dd"];
  packet = [MinimedPacket encodeData:packet];
  [dataWithHeader appendData:packet];
  MinimedPacket *mySentryPacket = [[MinimedPacket alloc] initWithData:dataWithHeader];
  [self handlePumpStatus:mySentryPacket fromDevice:nil withRSSI:1];
  [self flushAll];
}

- (void)testDecodeHistory {
  NSData *page = [NSData dataWithHexadecimalString:@"010034003400000020424c05105b0018510c0510095000b44b500000140000000014965c113416c01038d01642d0164cd05056d0010014001400340018514c05105b0006440f6510285000b44b500000580000000058965c0b14a9c034bdc010dfd0010058005800040006444f65107b060040100510200e005b0015651265102d5000784b500000940000000094965c0e22d4c036dec0147ed03492d0010094009400000015655265107b0700401305102610000a7236633465103f0e3663546510c527ad7b0800401505102a13000afd0c443765103f1f0c44b76510c527ad5bfd1544170510005000b455503000000000000030965c08940dd022dfd0010030003000000016445705100af33b663765103f1e3b66776510c527ad7b000040000610000e00070000033305900000006e05900500b253fd090000033301432701f03d00990100003000c0000003010200000000000000000000000000000000000000007b0100400106100208007b020040040610080e007b0300400606100c10000aa216742866103f141674486610c527ad7b0400400a0610140b007b0500400c0610180a000a081e432c66903f211e430c6610c527ad5b0806440c06103d5100b44b503c008400000000c0960100c000c000000006444c06100a3f2a712f66103f072a71ef6610c527ad7b060040100610200e005b00194e106610145000784b500000400000000040965c088af9c03603d00100400040000000194e5066105b0001721166100a5000784b500000200000000020965c0e1c5fc02469c08a59d03663d00100200020001800017251661021001443120610030000003537433206107b060747120610200e00030003000339461206107b0700401306102610005b000c791406100c5000784b500000280000000028965c0b20c0c01c1ad02424d001002800280000000d795406107b0800401506102a1300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005751"];
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

- (void)deviceReady:(NSNotification *)note
{
  RileyLinkBLEDevice *device = [note object];
  [device enableIdleListeningOnChannel:0];
  
  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
  _pumpOps = [[PumpOps alloc] initWithPumpState:appDelegate.pump andDevice:device];
}

- (void)timerTriggered:(id)sender {
  if ([lastHistoryAttempt timeIntervalSinceNow] < (- 5 * 60)) {
    NSLog(@"No dumpHistory for over five minutes.  Triggering one");
    [self fetchHistory:nil];
  }
  [self flushAll];
}


- (void)packetReceived:(NSNotification*)notification {
  NSDictionary *attrs = notification.userInfo;
  MinimedPacket *packet = attrs[@"packet"];
  RileyLinkBLEDevice *device = notification.object;
  [self addPacket:packet fromDevice:device];
  
  //TODO: find some way to sleep for 4 mins to save on RL battery?
}

#pragma mark - Polling

- (void) fetchHistory:(id)sender {
  lastHistoryAttempt = [NSDate date];

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
  
  if (!_pumpOps) {
    NSLog(@"No pumpOps available");
  }
  
  [self.pumpOps getHistoryPage:0 withHandler:^(NSDictionary * _Nonnull res) {
    if (!res[@"error"]) {
      NSData *page = res[@"pageData"];
      self.pumpModel = res[@"pumpModel"];
      NSLog(@"dumpHistory succeeded with base frequency: %@", res[@"baseFrequency"]);
      [self decodeHistoryPage:page];
    } else {
      NSLog(@"dumpHistory failed: %@", res[@"error"]);
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
  [self flushAll];
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
  
  if ([packet packetType] == PacketTypeSentry &&
      [packet messageType] == MESSAGE_TYPE_PUMP_STATUS &&
      [packet.address isEqualToString:[[Config sharedInstance] pumpID]]) {
    // Make this RL the active one, for history dumping.
    self.activeRileyLink = device;
    [self handlePumpStatus:packet fromDevice:device withRSSI:packet.rssi];
    // Just got a MySentry packet; in 25s would be a good time to poll.
    if (!dumpHistoryScheduled) {
      [self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:25];
      dumpHistoryScheduled = YES;
    }

  } else if ([packet packetType] == PacketTypeMeter) {
    [self handleMeterMessage:packet];
  }
  
  [self flushAll];
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
  
  if ([packet.address isEqualToString:[[Config sharedInstance] pumpID]]) {
  
    NSDate *validTime = msg.sensorTime;
    
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
      case SENSOR_STATUS_MISSING:
        glucose = DX_SENSOR_NOT_ACTIVE;
        validTime = msg.pumpTime;
        break;
      default:
        break;
    }
  
    NSNumber *epochTime = @([validTime timeIntervalSince1970] * 1000);
    
    NSMutableDictionary *status = [NSMutableDictionary dictionary];
    
    status[@"device"] = device.deviceURI;
    status[@"created_at"] = [self.dateFormatter stringFromDate:[NSDate date]];
    
    // TODO: use battery monitoring to post updates if we're not hearing from pump?
    UIDevice *uploaderDevice = [UIDevice currentDevice];
    if (uploaderDevice.isBatteryMonitoringEnabled) {
      NSNumber *batteryPct = @((int)([[UIDevice currentDevice] batteryLevel] * 100));
      status[@"uploader"] = @{@"battery":batteryPct};
    }
    
    status[@"pump"] = @{
                        @"iob": @{
                          @"timestamp": [self.dateFormatter stringFromDate:validTime],
                          @"bolusiob": @(msg.activeInsulin),
                        },
                        @"reservoir": @(msg.insulinRemaining),
                        @"battery": @{
                            @"percent": @(msg.batteryPct)
                            }
                        };
    
    if (msg.sensorStatus != SENSOR_STATUS_MISSING) {
      status[@"sensor"] = @{
                            @"sensorAge": @(msg.sensorAge),
                            @"sensorRemaining": @(msg.sensorRemaining),
                            @"sensorStatus": msg.sensorStatusString
                            };
    }
    [self.deviceStatuses addObject:status];

    // Do not store sgv values if sensor missing; we're likely just
    // using MySentry to gather pump status.
    if (msg.sensorStatus != SENSOR_STATUS_MISSING) {
      NSDictionary *entry =
      @{@"date": epochTime,
        @"dateString": [self.dateFormatter stringFromDate:validTime],
        @"sgv": @(glucose),
        @"previousSGV": @(msg.previousGlucose),
        @"direction": [self trendToDirection:msg.trend],
        @"device": device.deviceURI,
        @"rssi": @(rssi),
        @"type": @"sgv"
        };
      [self.entries addObject:entry];
    }
    
    
  } else {
    NSLog(@"Dropping mysentry packet for pump: %@", packet.address);
  }
}

- (void) handleMeterMessage:(MinimedPacket*)packet {
  MeterMessage *msg = [[MeterMessage alloc] initWithData:packet.data];
  
  if (msg.isAck) {
    return;
  }
  
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

- (void) flushAll {
  
  NSArray *logEntries = [Log popLogEntries];
  if (logEntries.count > 0) {
    NSDate *date = [NSDate date];
    NSTimeInterval seconds = [date timeIntervalSince1970];
    NSNumber *epochTime = @(seconds * 1000);

    NSDictionary *entry =
    @{@"date": epochTime,
      @"dateString": [self.dateFormatter stringFromDate:date],
      @"entries": logEntries,
      @"type": @"logs"
      };
    [self.entries addObject:entry];
  }
  
  [self flushDeviceStatuses];
  [self flushEntries];
  [self flushTreatments];
}

- (void) flushDeviceStatuses {
  
  if (self.deviceStatuses.count == 0) {
    return;
  }
  
  NSArray *inFlightDeviceStatuses = self.deviceStatuses;
  self.deviceStatuses = [[NSMutableArray alloc] init];
  [self reportJSON:inFlightDeviceStatuses toNightScoutEndpoint:defaultNightscoutDeviceStatusPath completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
    if (httpResponse.statusCode != 200) {
      NSLog(@"Requeuing %d device statuses: %@", inFlightDeviceStatuses.count, error);
      [self.deviceStatuses addObjectsFromArray:inFlightDeviceStatuses];
    } else {
      //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      //NSLog(@"Submitted %d device statuses to nightscout: %@", inFlightDeviceStatuses.count, resp);
    }
  }];
}

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
      //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      //NSLog(@"Submitted %d entries to nightscout: %@", inFlightEntries.count, resp);
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
      //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      [self.sentTreatments addObjectsFromArray:inFlightTreatments];
      //NSLog(@"Submitted %d treatments to nightscout: %@", inFlightTreatments.count, resp);
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
  //NSString *jsonPost = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
  //NSLog(@"Posting to %@, %@", [uploadURL absoluteString], jsonPost);
  [request setHTTPMethod:@"POST"];
  
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
  [request setValue:[self.APISecret sha1] forHTTPHeaderField:@"api-secret"];
  
  [request setHTTPBody: sendData];
  
  [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completionHandler] resume];
}

@end
