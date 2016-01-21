//
//  HistoryFetcher.m
//  RileyLink
//
//  Created by Pete Schwamb on 1/20/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import "HistoryFetcher.h"

@interface HistoryFetcher () {
  uint8_t pageNum;
  void (^completionHandler)(NSDictionary * _Nonnull);
  NSDictionary *result;
}

@property (nonatomic, strong) NSOperationQueue *pumpCommQueue;

@end


@implementation HistoryFetcher

- (nonnull instancetype)initWithPumpId:(nonnull NSString *)a_pumpId andDevice:(nonnull RileyLinkBLEDevice *)a_device {
  self = [super init];
  if (self) {
    _pumpId = a_pumpId;
    _device = a_device;
    
  }
  return self;
}

- (instancetype)init NS_UNAVAILABLE
{
  return nil;
}

- (void) doFetch {
  // TODO: poll history:
  result = [NSDictionary dictionary];
  
  [self performSelectorOnMainThread:@selector(complete) withObject:nil waitUntilDone:NO];
}

- (void) complete {
  completionHandler(result);
}

- (void) fetchPage:(uint8_t)p completionHandler:(void (^ _Nullable)(NSDictionary * _Nonnull))h {
  if (completionHandler != nil) {
    [NSException raise:@"multiple invocation error" format:@"fetchPage on this instance of HistoryFetcher can only perform one fetch at time."];
  }
  pageNum = p;
  completionHandler = h;
  [self performSelectorInBackground:@selector(doFetch) withObject:nil];
}



@end
