//
//  QuestionData.h
//  SQLBuilder
//
//  Created by  on 2016/12/21.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QuestionData : NSObject

@property(nonatomic , strong) NSString * question_Id;

@property(nonatomic , strong) NSString * title;

@property(nonatomic , assign) int year;

@property(nonatomic , strong) NSString * unit;

@property(nonatomic , assign) int number_number;

@property(nonatomic , assign) int type;

@property(nonatomic , assign) int type_flag;

@property(nonatomic , strong) NSString * cut_title;

@property(nonatomic , strong) NSString * COMBINE_ANSWER;

@end
