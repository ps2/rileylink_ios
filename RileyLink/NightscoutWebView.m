//
//  NightscoutWebView.m
//  RileyLink
//
//  Created by Pete Schwamb on 7/31/14.
//  Copyright (c) 2014 Pete Schwamb. All rights reserved.
//

#import "NightscoutWebView.h"
#import "UIAlertView+Blocks.h"
#import "SWRevealViewController.h"
#import "Config.h"
#import "ConfigureViewController.h"
#import "HistoryPage.h"
#import "NSData+Conversion.h"

@interface NightscoutWebView () <UIWebViewDelegate> {
  IBOutlet UIBarButtonItem *menuButton;
}

@end

@implementation NightscoutWebView

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // Just testing
  NSData *data = [NSData dataWithHexadecimalString:@"6ebf0f050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0180de08010f11220006040c1e80c051410f0c0488c411010f7b018ac411010f11220006040c1eb1e651410f1a008fee11010f060303688fee71010f0c040e400001070c030f4000010764001f4000010717003740000107180080f616080f07000001efa18f0000006ea18f050000000000000001ef01ef64000000000000000000000000000000000000000000000000000000000000000000000000210084f616080f0b6b0080f736a80f030000002085f736080f7b0297f716080f2c1c007b0080c000090f001600070000001ea88f0036166ea88f0500000000000000001e001e6400000000000000000000000000000000006000000000000000000000000000c0000000b07b0180de08090f1122007b0280c016090f2c1c007b0080c0000a0f00160007000002bea98f0000006ea98f050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0180de080a0f1122007b0280c0160a0f2c1c007b0080c0000b0f00160007000002beaa8f0000006eaa8f050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0180de080b0f1122007b0280c0160b0f2c1c007b0080c0000c0f00160007000002beab8f0000006eab8f050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0180de080c0f1122007b0280c0160c0f2c1c007b0080c0000d0f00160007000002beac8f0000006eac8f050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0180de080d0f1122007b0280c0160d0f2c1c007b0080c0000e0f00160007000002bead8f0000006ead8f050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0180de080e0f11220034649cf8140e0f0a6495fb340e0f5b64affb140e0f0f5000783c4100003200000000328c0100320032000000b0fb340e0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000095ba"];
  HistoryPage *page = [[HistoryPage alloc] initWithData:data andPumpModel:@"530g"];
  
  NSArray *events = [page decode];
  
  
  if (self.revealViewController != nil) {
    menuButton.target = self.revealViewController;
    [menuButton setAction:@selector(revealToggle:)];
    [self.view addGestureRecognizer: self.revealViewController.panGestureRecognizer];
    
    self.revealViewController.rearViewRevealWidth = 162;
    
    if (![[Config sharedInstance]  hasValidConfiguration]) {
      UINavigationController *configNav = [self.storyboard instantiateViewControllerWithIdentifier:@"configuration"];
      ConfigureViewController *configViewController = [configNav viewControllers][0];
      [configViewController doInitialConfiguration];
      [self.revealViewController setFrontViewController:configNav];
    }
  }
  
  [self loadPage];
}

- (void)loadPage {
  NSURL *url = [NSURL URLWithString:[[Config sharedInstance] nightscoutURL]];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [_webView loadRequest:request];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark UIWebViewDelegate methods

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
  [UIAlertView showWithTitle:@"Network Error"
                     message:[error localizedDescription]
           cancelButtonTitle:@"OK"
           otherButtonTitles:@[@"Retry"]
                    tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                      if (buttonIndex == 1) {
                        [self loadPage];
                      }
                      NSLog(@"Retrying");
                    }];
}

@end
