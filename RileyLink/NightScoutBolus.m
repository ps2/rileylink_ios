//
//  NightScoutBolus.m
//  RileyLink
//
//  Created by Pete Schwamb on 11/27/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//
//  Based on https://github.com/openaps/oref0/blob/master/lib/bolus.js
//

#import "NightScoutBolus.h"

@interface NightScoutBolus () {
  NSMutableArray *results;
  NSMutableDictionary *state;
  NSMutableArray *previous;
  NSArray *treatments;
  NSDateFormatter *dateFormatter;
}

@end


@implementation NightScoutBolus

- (instancetype)init
{
  self = [super init];
  if (self) {
    results = [NSMutableArray array];
    state = [NSMutableDictionary dictionary];
    previous = [NSMutableArray array];
    dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
  }
  return self;
}

- (BOOL) inPrevious:(NSMutableDictionary *)ev {
  for (NSMutableDictionary *elem in previous) {
    if ([elem[@"timestamp"] isEqualToString:ev[@"timestamp"]] &&
        [ev[@"_type"] isEqualToString:elem[@"_type"]]) {
      return YES;
    }
  }
  return NO;
}

- (NSArray*) withinMinutesFrom:(NSMutableDictionary*)origin tail:(NSArray*)tail minutes:(NSInteger)minutes {
  NSInteger ms = minutes * 1000 * 60;
  NSDate *ts = [dateFormatter dateFromString:origin[@"timestamp"]];
  NSMutableArray *candidates = [NSMutableArray array];
  for (NSDictionary *elem in tail) {
    NSDate *dt = [dateFormatter dateFromString:elem[@"timestamp"]];
    if ([ts timeIntervalSinceDate:dt] < ms) {
      [candidates addObject:elem];
    }
  }
  return candidates;
}

- (void) bolus:(NSMutableDictionary*)ev remaining:(NSArray*)remaining {
  if (!ev) {
    NSLog(@"Error: XXX: bad event for bolus processing");
    return;
  }
  
  if ([ev[@"_type"] isEqualToString:@"BolusWizardBolusEstimate"]) {
    state[@"carbs"] = [ev[@"carb_input"] stringValue];
    state[@"ratio"] = [ev[@"carb_ratio"] stringValue];
    if ([ev[@"bg"] integerValue] > 0) {
      state[@"bg"] = [ev[@"bg"] stringValue];
      state[@"glucose"] = [ev[@"bg"] stringValue];
      state[@"glucoseType"] = ev[@"_type"];
    }
    state[@"wizard"] = ev;
    state[@"timestamp"] = ev[@"timestamp"];
    state[@"created_at"] = ev[@"timestamp"];
    [previous addObject:ev];
  }
  
  if ([ev[@"_type"] isEqualToString:@"BolusNormal"]) {
    state[@"duration"] = [ev[@"duration"] stringValue];
    if (ev[@"duration"] && [ev[@"duration"] integerValue] > 0) {
      state[@"square"] = ev;
    } else {
      state[@"bolus"] = ev;
    }
    state[@"timestamp"] = ev[@"timestamp"];
    state[@"created_at"] = ev[@"timestamp"];
    [previous addObject:ev];
  }
  
  BOOL haveBoth = state[@"bolus"] && state[@"wizard"];
  
  if (remaining.count > 0 && !haveBoth) {
    // keep recursing
    [self bolus:remaining[0] remaining:[remaining subarrayWithRange:NSMakeRange(1, remaining.count-1)]];
    return;
  } else {
    state[@"eventType"] = @"<none>";
    
    float insulin = 0;
    if (state[@"square"]) {
      insulin += [state[@"square"][@"amount"] floatValue];
    }
    if (state[@"bolus"]) {
      insulin += [state[@"bolus"][@"amount"] floatValue];
    }
    state[@"insulin"] = @(insulin);
    
    BOOL has_insulin = insulin > 0;
    BOOL has_carbs = state[@"carbs"] && [state[@"carbs"] floatValue] > 0;
    BOOL has_wizard = state[@"wizard"] ? YES : NO;
    BOOL has_bolus = state[@"bolus"] ? YES : NO;
    
    if (state[@"square"] && has_bolus) {
      [self annotate:@"DualWave bolus for", state[@"square"][@"duration"], @"minutes", nil];
    } else if (state[@"square"] && has_wizard) {
      [self annotate:@"Square wave bolus for", state[@"square"][@"duration"], @"minutes", nil];
    } else if (state[@"square"]) {
      [self annotate:@"Solo Square wave bolus for", state[@"square"][@"duration"], @"minutes", nil];
      [self annotate:@"No bolus wizard used.", nil];
    } else if (state[@"bolus"] && has_wizard) {
      [self annotate:@"Normal bolus with wizard.", nil];
    } else if (state[@"bolus"]) {
      [self annotate:@"Normal bolus (solo, no bolus wizard).", nil];
    }
    
    if (state[@"bolus"]) {
      [self annotate:@"Programmed bolus", state[@"bolus"][@"programmed"], nil];
      [self annotate:@"Delivered bolus", state[@"bolus"][@"amount"], nil];
      int percent = [state[@"bolus"][@"amount"] floatValue] / [state[@"bolus"][@"programmed"] floatValue] * 100;
      [self annotate:@"Percent delivered: ", [NSString stringWithFormat:@"%d%%", percent], nil];
    }
    if (state[@"square"]) {
      [self annotate:@"Programmed square", state[@"square"][@"programmed"], nil];
      [self annotate:@"Delivered square", state[@"square"][@"amount"], nil];
      int percent = [state[@"square"][@"amount"] floatValue] / [state[@"square"][@"programmed"] floatValue] * 100;
      [self annotate:@"Success: ", [NSString stringWithFormat:@"%d%%", percent], nil];
    }
    if (has_wizard) {
      state[@"created_at"] = state[@"wizard"][@"timestamp"];
      [self annotate:@"Food estimate", state[@"wizard"][@"food_estimate"], nil];
      [self annotate:@"Correction estimate", state[@"wizard"][@"correction_estimate"], nil];
      [self annotate:@"Bolus estimate", state[@"wizard"][@"bolus_estimate"], nil];
      [self annotate:@"Target low", state[@"wizard"][@"bg_target_low"], nil];
      [self annotate:@"Target high", state[@"wizard"][@"bg_target_high"], nil];
      float delta = [state[@"wizard"][@"sensitivity"] floatValue] * [state[@"insulin"] floatValue] * -1;
      [self annotate:@"Hypothetical glucose delta", [NSString stringWithFormat:@"%d", (int)delta], nil];
      if (state[@"bg"] && [state[@"bg"] integerValue] > 0) {
        [self annotate:@"Glucose was:", state[@"bg"], nil];
        // TODO: annotate prediction
      }
    }
    if (state[@"carbs"] && state[@"insulin"] && state[@"bg"]) {
      state[@"eventType"] = @"Meal Bolus";
    } else {
      if (has_carbs && !has_insulin) {
        state[@"eventType"] = @"Carb Correction";
      }
      if (!has_carbs && has_insulin) {
        state[@"eventType"] = @"Correction Bolus";
      }
    }
    if (state[@"notes"] && [state[@"notes"] count] > 0) {
      state[@"notes"] = [state[@"notes"] componentsJoinedByString:@"\n"];
    }
    if (state[@"insulin"]) {
      state[@"insulin"] = [state[@"insulin"] stringValue];
    }
    
    [results addObject:state];
    state = [NSMutableDictionary dictionary];
  }

}
       
 - (void) annotate:(NSString *)firstStr, ... NS_REQUIRES_NIL_TERMINATION {
   NSMutableArray *argArray = [NSMutableArray array];
   va_list args;
   va_start(args, firstStr);
   for (NSString *arg = firstStr; arg != nil; arg = va_arg(args, NSString*))
   {
     [argArray addObject:arg];
   }
   va_end(args);
   NSString *msg = [argArray componentsJoinedByString:@" "];
   if (!state[@"notes"]) {
     state[@"notes"] = [NSMutableArray array];
   }
   [state[@"notes"] addObject:msg];
 }

- (void) step:(NSMutableDictionary *)current withIndex:(NSInteger)index {
  if ([self inPrevious:current]) {
    return;
  }
  
  if ([current[@"_type"] isEqualToString:@"BolusNormal"] ||
      [current[@"_type"] isEqualToString:@"BolusWizardBolusEstimate"]) {
    NSArray *tail = [treatments subarrayWithRange:NSMakeRange(index+1, treatments.count-index-1)];
    tail = [self withinMinutesFrom:current tail:tail minutes:4];
    [self bolus:current remaining:tail];
  } else {
    [results addObject:current];
  }
  
}

- (NSArray*) reduce:(NSArray*)newTreatments {
  treatments = newTreatments;
  for (int i=0; i<treatments.count; i++) {
    NSMutableDictionary *current = treatments[i];
    [self step:current withIndex:i];
  }
  return results;
}

+ (NSArray*) process:(NSArray*)treatments {
  return [[[NightScoutBolus alloc] init] reduce: treatments];
}


@end
