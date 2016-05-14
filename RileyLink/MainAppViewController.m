//
//  MainAppViewController.m
//  RileyLink
//
//  Created by Pete Schwamb on 6/28/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

@import RileyLinkBLEKit;

#import "NSData+Conversion.h"
#import "Config.h"
#import "RileyLinkRecord.h"
#import "MainAppViewController.h"
#import "RileyLink-Swift.h"


@interface MainAppViewController () {
  NSDictionary *lastStatus;
}

@end

@implementation MainAppViewController


- (void)viewDidLoad {
  [super viewDidLoad];
  
  // Hitting a crash like this:
  // http://stackoverflow.com/questions/26656342/uiwebview-random-crash-at-uiviewanimationstate-release-message-sent-to-deallo
  // Looks like switching NightscoutWebView to WKWebView should help. Until then:
  [UIView setAnimationsEnabled:NO];
  
  AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  self.managedObjectContext = appDelegate.managedObjectContext;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
