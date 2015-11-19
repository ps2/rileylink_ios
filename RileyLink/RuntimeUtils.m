//
//  RuntimeUtils.m
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <objc/runtime.h>

#import "RuntimeUtils.h"

@implementation RuntimeUtils

+ (NSArray *)classStringsForClassesOfType:(Class)filterType {
  
  int numClasses = 0, newNumClasses = objc_getClassList(NULL, 0);
  Class *classList = NULL;
  
  while (numClasses < newNumClasses) {
    numClasses = newNumClasses;
    classList = (Class*)realloc(classList, sizeof(Class) * numClasses);
    newNumClasses = objc_getClassList(classList, numClasses);
  }
  
  NSMutableArray *classesArray = [NSMutableArray array];
  
  for (int i = 0; i < numClasses; i++) {
    Class superClass = classList[i];
    do {
      // recursively walk the inheritance hierarchy
      superClass = class_getSuperclass(superClass);
      if (superClass == filterType) {
        [classesArray addObject:NSStringFromClass(classList[i])];
        break;
      }
    } while (superClass);
  }
  
  free(classList);
  
  return classesArray;
}

@end
