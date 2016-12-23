//
//  BaseObject.m
//  SQLBuilder
//
//  Created by  on 2016/12/22.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import "BaseObject.h"
#import "AppDelegate.h"

@implementation BaseObject

+ (NSArray *)getDBNameArray
{
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    return delegate.DBNameArray;
}

@end
