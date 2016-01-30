//
//  MainAppViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 6/28/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "RileyLinkBLEManager.h"
#import "NSData+Conversion.h"
#import "PumpStatusMessage.h"
#import "NightScoutUploader.h"
#import "Config.h"
#import "AppDelegate.h"
#import "RileyLinkRecord.h"
#import "RileyLinkBLEManager.h"
#import "PumpState.h"

#import "MainAppViewController.h"

@interface MainAppViewController () {
  NSDictionary *lastStatus;
}

@property (strong, nonatomic) NightScoutUploader *uploader;

@end

@implementation MainAppViewController


- (void)viewDidLoad {
  [super viewDidLoad];
  
  // Hitting a crash like this:
  // http://stackoverflow.com/questions/26656342/uiwebview-random-crash-at-uiviewanimationstate-release-message-sent-to-deallo
  // Looks like switching NightscoutWebView to WKWebView should help. Until then:
  [UIView setAnimationsEnabled:NO];
  
  self.uploader = [[NightScoutUploader alloc] init];
  self.uploader.siteURL = [[Config sharedInstance] nightscoutURL];
  self.uploader.APISecret = [[Config sharedInstance] nightscoutAPISecret];
  
  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
  self.managedObjectContext = appDelegate.managedObjectContext;

  [self setupAutoConnect];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];

  NSLog(@"Stopping scan");
  [RileyLinkBLEManager sharedManager].scanningEnabled = NO;
}

- (void)setupAutoConnect {
  
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"RileyLinkRecord"
                                            inManagedObjectContext:self.managedObjectContext];
  [fetchRequest setEntity:entity];
  NSError *error;
  NSMutableSet *autoConnectIds = [[NSMutableSet alloc] init];
  NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
  for (RileyLinkRecord *record in fetchedObjects) {
    NSLog(@"Loaded: %@ from db", record.name);
    if ([record.autoConnect boolValue]) {
      [autoConnectIds addObject:record.peripheralId];
    }
  }
  [[RileyLinkBLEManager sharedManager] setAutoConnectIds:autoConnectIds];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
