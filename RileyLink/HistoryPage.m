//
//  HistoryPage.m
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "HistoryPage.h"
#import "RuntimeUtils.h"
#import "PumpHistoryEventBase.h"
#import "PHEUnabsorbedInsulin.h"
#import "PHEBolusNormal.h"
@import MinimedKit;

@implementation HistoryPage

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (nonnull instancetype)initWithData:(nonnull NSData *)data andPumpModel:(nullable PumpModel *)model
{
  self = [super init];
  if (self) {
    _data = data;
    _pumpModel = model;
  
    //@registry = self.class.type_registry
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *classStr in [RuntimeUtils classStringsForClassesOfType:[PumpHistoryEventBase class]]) {
      Class eventClass = NSClassFromString(classStr);
      SEL selector = NSSelectorFromString(@"eventTypeCode");
      if ([eventClass respondsToSelector:selector]) {
        NSMethodSignature *sig = [[eventClass class] methodSignatureForSelector:selector];
        if (sig == nil) {
          [NSException raise:@"Missing class method" format:@"%@ does not implement +eventTypeCode.", eventClass];
        }
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        invocation.selector = selector;
        invocation.target = eventClass;
        [invocation invoke];
        int returnValue;
        [invocation getReturnValue:&returnValue];
        NSNumber *eventCode = @(returnValue);
        d[eventCode] = eventClass;
      }
    }
    _registry = d;
  }
  return self;
}

- (NSArray*) decode {
  NSMutableArray *events = [NSMutableArray array];
  NSUInteger offset = 0;
  NSUInteger length = _data.length;
  PumpHistoryEventBase *event;
  PHEUnabsorbedInsulin *unabsorbedInsulinRecord;
  while (offset < length) {
    event = [self matchEvent:offset];
    if (event) {
      if ([event class] == [PHEBolusNormal class] && unabsorbedInsulinRecord != nil) {
        PHEBolusNormal *bolus = (PHEBolusNormal*)event;
        bolus.unabsorbedInsulinRecord = unabsorbedInsulinRecord;
        unabsorbedInsulinRecord = nil;
      }
      if ([event class] == [PHEUnabsorbedInsulin class]) {
        unabsorbedInsulinRecord = (PHEUnabsorbedInsulin*)event;
      } else {
        [events addObject:event];
      }
      offset += [event length];
    } else {
      // TODO: Track bytes we skipped over
      offset += 1;
    }
  }
  return events;
}

- (BOOL) isCRCValid {
  // TODO: temporarily using the incomplete swift version for this
  return [[[HistoryPageTemp alloc] initWithPageData:_data] crcOK];
}

- (nonnull const unsigned char *) bytes {
  return _data.bytes;
}

- (PumpHistoryEventBase*) matchEvent:(NSUInteger) offset {
  NSNumber *code = [NSNumber numberWithInt:[self bytes][offset]];
  Class klazz = _registry[code];
  if (klazz) {
    NSData *eventData = [_data subdataWithRange:NSMakeRange(offset, _data.length - offset)];
    PumpHistoryEventBase *event = [[klazz alloc] initWithData:eventData andPumpModel:self.pumpModel];
    if (event.length > event.data.length) {
      return nil;
    }
    return event;
  }
  return nil;
}

@end
