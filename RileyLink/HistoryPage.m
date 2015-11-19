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

@implementation HistoryPage

- (nonnull instancetype)initWithData:(nonnull NSData *)data andPumpModel:(nullable NSString *)model
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
        [invocation setSelector:selector];
        [invocation setTarget:eventClass];
        [invocation invoke];
        int returnValue;
        [invocation getReturnValue:&returnValue];
        NSLog(@"Returned %d", returnValue);
        NSNumber *eventCode = [NSNumber numberWithInt:returnValue];
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
  while (offset < length) {
    event = [self matchEvent:offset];
    if (event) {
      [events addObject:event];
      offset += [event length];
    } else {
      // TODO: Track bytes we skipped over
      offset += 1;
    }
  }
  return events;
}

- (nonnull const unsigned char *) bytes {
  return [_data bytes];
}

- (PumpHistoryEventBase*) matchEvent:(NSUInteger) offset {
  NSNumber *code = [NSNumber numberWithInt:[self bytes][offset]];
  Class klazz = _registry[code];
  if (klazz) {
    NSData *eventData = [_data subdataWithRange:NSMakeRange(offset, _data.length - offset)];
    return [[klazz alloc] initWithData:eventData andPumpModel:_pumpModel];
  }
  return nil;
}

@end
