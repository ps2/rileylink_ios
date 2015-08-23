//
//  MenuHeaderTableViewCell.m
//  RileyLink
//
//  Created by Nathan Racklyeft on 8/22/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import "MenuHeaderTableViewCell.h"

@interface MenuHeaderTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end

@implementation MenuHeaderTableViewCell

- (void)setTitle:(NSString *)title
{
    self.titleLabel.text = title;
}

- (NSString *)title
{
    return self.titleLabel.text;
}

@end
