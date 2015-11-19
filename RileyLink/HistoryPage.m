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
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                    [[eventClass class] instanceMethodSignatureForSelector:selector]];
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

@end
