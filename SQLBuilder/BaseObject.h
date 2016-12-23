//
//  BaseObject.h
//  SQLBuilder
//
//  Created by  on 2016/12/22.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"
#import "NSData+AES256.h"
#import "QuestionData.h"
#import <UIKit/UIKit.h>

@interface BaseObject : NSObject

+ (NSArray *)getDBNameArray;

@end
