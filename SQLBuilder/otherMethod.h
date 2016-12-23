//
//  otherMethod.h
//  SQLBuilder
//
//  Created by  on 2016/12/22.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import "BaseObject.h"

@interface otherMethod : BaseObject

// 更新Number_number
+ (void)updateNumber_number;

// 答案合成
+ (void)getAndUpdateAnswerText;

// 删除完全重复数据
+ (void)deleteRepeatData;

// 多选题 审核 并不能挑选
+ (void) multiChoice;

// 数据加密
+ (void)encryptionDate;

// 打印最后的调整文本
+ (void)printText;

@end
