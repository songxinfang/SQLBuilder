//
//  publicTitle.m
//  SQLBuilder
//
//  Created by  on 2016/12/22.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import "publicTitle.h"
#import <UIKit/UIKit.h>

int offCount = 6;

int flagIndex = 100;

@implementation publicTitle

+ (void)publicTitleSearch
{
    [self cutTitle];
    
    [self sameCutTitleFirstStep];
    
    [self sameCutTitleSecondStep];

    [self checkSameCutTitle];
}

+ (void)sameCutTitleFirstStep
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray])
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        [_sqlDb inDatabase:^(FMDatabase *db)
         {
             // 二位数组记录结果
             NSMutableArray *bigArray = [NSMutableArray array];

             FMResultSet *rs =  [db executeQuery:@"select * from QUESTION_INFO_BEAN where type = 0 and CUT_TITLE <> ''"];
             
             while (rs.next)
             {
                 NSString *cut_title = [rs stringForColumn:@"cut_title"];
                 if (cut_title.length > 80){ cut_title = [cut_title substringToIndex:cut_title.length-20];}
                 else if (cut_title.length > 50){ cut_title = [cut_title substringToIndex:cut_title.length - 10];}
                 NSString *query = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year=%d and unit='%@' and type = 0 and CUT_TITLE like '%%%@%%' order by NUMBER_NUMBER asc",[rs intForColumn:@"year"],[rs stringForColumn:@"unit"],cut_title];
                 FMResultSet *rs2 =  [db executeQuery:query];
               
                 NSMutableArray *smallArray = [NSMutableArray array];

                 int question_id = 0;
                 int number_number = 0;
                 while (rs2.next)
                 {
                     if (question_id == 0)
                     {
                         question_id = [rs2 intForColumn:@"QUESTION_ID"];
                         number_number = [rs2 intForColumn:@"NUMBER_NUMBER"];
                     }
                     else
                     {
                         int question_id2 = [rs2 intForColumn:@"QUESTION_ID"];
                         int number_number2 = [rs2 intForColumn:@"NUMBER_NUMBER"];
                         if (number_number2 - number_number < 5)
                         {
                             [smallArray addObject:[NSNumber numberWithInt:question_id]];
                         }
                         else
                         {
                             // 记录最后那个id
                             if (smallArray.count) {
                                 [smallArray addObject:[NSNumber numberWithInt:question_id]];
                                 [bigArray addObject:smallArray];
                             }
                             smallArray = [NSMutableArray array];
                         }
                         question_id = question_id2;
                         number_number = number_number2;
                     }
                 }
                 // 记录最后那个id
                 if (smallArray.count) {
                     [smallArray addObject:[NSNumber numberWithInt:question_id]];
                     [bigArray addObject:smallArray];
                 }
                 smallArray = [NSMutableArray array];
                 
                 [rs2 close];
             }
             
             // 匹配成功以后直接更新，以免重复匹配
             if (bigArray.count)
             {
                 for (NSArray *arr in bigArray)
                 {
                     NSMutableString *firstStr = [NSMutableString string];
                     
                     for (NSNumber *number in arr)
                     {
                         [firstStr appendFormat:@"%@,",number];
                     }
                     
                     if (firstStr.length)
                     {
                         flagIndex ++;

                         NSString *temp = [firstStr substringToIndex:firstStr.length-1];
                         NSString *typeStr = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set TYPE = 1,TYPE_FLAG = %d where QUESTION_ID in (%@)", flagIndex, temp];
                         BOOL ssss = [db executeUpdate:typeStr];
                         if (!ssss) {
                             NSLog(@"update error");
                         }
                     
                         NSLog(@"1111_flag_index = %d",flagIndex);
                     }
                 }
             }

             [rs close];
         }];
    }
}

// 截断句号 逗号，提取题干更新到cut_title
+ (void)cutTitle
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    for (NSString * name in [self getDBNameArray]) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        NSLog(@"filePath:%@",filePath);

        NSInteger minLength = 10;
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            {
                // 1、 添加字段COMBINE_ANSWER,设置内容为空
                [db executeUpdate:@"alter table QUESTION_INFO_BEAN add COLUMN CUT_TITLE TEXT DEFAULT NULL"];
                [db executeUpdate:@"alter table QUESTION_INFO_BEAN add COLUMN TYPE_FLAG INTEGER DEFAULT 0"];
            }

            {
                // 2、提取最后一个句号之前的内容，然后去掉逗号和句号
                FMResultSet *rs =  [db executeQuery:@"select TITLE,QUESTION_ID from QUESTION_INFO_BEAN where type = 0"];
                
                while (rs.next)
                {
                    NSString *title = [rs stringForColumn:@"TITLE"];
                    
                    if ([title containsString:@"。"])
                    {
                        // 太简单的类似XX，XX岁。pass
                        NSRange range = [title rangeOfString:@"。" options:NSBackwardsSearch];
                        NSString *first = [title substringToIndex:range.location+range.length];
                        
                        first = [self SymbolfilterWithStr:first];
                        
                        if (first.length > minLength)
                        {
                            // 插入答案
                            if ([first containsString:@"'"])
                            {
                                first = [first stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                            }
                            NSInteger questionid = [rs intForColumn:@"QUESTION_ID"];
                            
                            NSString *updateSql = [NSString stringWithFormat:@"UPDATE QUESTION_INFO_BEAN SET CUT_TITLE = '%@',TYPE_FLAG = 1 where QUESTION_ID=%ld", first, questionid];
                            [ db executeUpdate:updateSql];
                        }
                    }
                }
                
                [rs close];
            }
            
            {
                // 3、再将包含两个以上逗号，最后一个逗号之前的内容提取出来
                FMResultSet *rs =  [db executeQuery:@"select TITLE,QUESTION_ID from QUESTION_INFO_BEAN where type = 0 and CUT_TITLE = '' and TYPE_FLAG = 0"];
                
                while (rs.next)
                {
                    NSString *title = [rs stringForColumn:@"TITLE"];
                    NSArray *array = [title componentsSeparatedByString:@"，"];
                    if (array.count > 3)
                    {
                        NSRange range = [title rangeOfString:@"，" options:NSBackwardsSearch];
                        NSString *first = [title substringToIndex:range.location+range.length];
                        
                        first = [self SymbolfilterWithStr:first];
                        
                        if (first.length > minLength)
                        {
                            // 插入答案
                            if ([first containsString:@"'"])
                            {
                                first = [first stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                            }
                            NSInteger questionid = [rs intForColumn:@"QUESTION_ID"];
                            
                            NSString *updateSql = [NSString stringWithFormat:@"UPDATE QUESTION_INFO_BEAN SET CUT_TITLE = '%@' ,TYPE_FLAG = 1 where QUESTION_ID=%ld", first, questionid];
                            [ db executeUpdate:updateSql];
                        }
                    }
                }
                
                [rs close];
            }
        }];
    }
}


+ (NSString *)SymbolfilterWithStr:(NSString *) str
{
    static NSString * charSetStr = @",，.。的、：； ";
    
    NSCharacterSet * charSet = [NSCharacterSet characterSetWithCharactersInString:charSetStr];
    
    NSArray * arr = [str componentsSeparatedByCharactersInSet:charSet];
    NSString * newStr = nil;
    for (NSString* s  in arr) {
        
        if (!newStr) {
            newStr = s;
        }else{
            newStr = [NSString  stringWithFormat:@"%@%@" , newStr , s];
            
        }
    }
    
    return newStr;
}

// 找出相似并且连续的题，认证为公共题干
+ (void)sameCutTitleSecondStep
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    for (NSString * name in [self getDBNameArray])
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];

        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];


        [_sqlDb inDatabase:^(FMDatabase *db){
            // 找到每年每单元的起始与截止位置
            NSString *sql = @"select year,unit,min(NUMBER_NUMBER) as min ,max(NUMBER_NUMBER) as max from QUESTION_INFO_BEAN where type = 1 group by year,unit order by year,unit,NUMBER_NUMBER ";

            int count = 0;
            FMResultSet *rs =  [db executeQuery:sql];
            while (rs.next)
            {
                // 找出区域内断开的数据
                NSString *sql2 = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year=%d and unit='%@' and NUMBER_NUMBER between %d and %d order by NUMBER_NUMBER asc",[rs intForColumn:@"year"],[rs stringForColumn:@"unit"],[rs intForColumn:@"min"]-offCount, [rs intForColumn:@"max"]+offCount];

                NSMutableArray *dataArray = [NSMutableArray array];

                FMResultSet *rs2 =  [db executeQuery:sql2];
                while (rs2.next)
                {
                    QuestionData *data = [[QuestionData alloc] init];
                    data.question_Id = [rs2 stringForColumn:@"question_Id"];
                    data.title = [rs2 stringForColumn:@"title"];
                    data.year = [rs2 intForColumn:@"year"];
                    data.unit = [rs2 stringForColumn:@"unit"];
                    data.number_number = [rs2 intForColumn:@"number_number"];
                    data.type = [rs2 intForColumn:@"type"];
                    data.type_flag = [rs2 intForColumn:@"type_flag"];
                    data.cut_title = [rs2 stringForColumn:@"cut_title"];
                    [dataArray addObject:data];
                    if (data.type == 0 && data.title.length > 50)
                    {
                        count ++;
                    }
                }
                [rs2 close];
                
                NSArray *updateStrArray = [self searchSimilarTitleQuestion:dataArray];
                for (NSString * sql in updateStrArray) {
                    if (sql) {
                        bool result = [db executeUpdate:sql];
                        if (!result) {
                            NSLog(@"update error");
                            break;
                        }
                    }
                }
            }

            [rs close];
        }];
    }
}

+ (NSArray *)searchSimilarTitleQuestion:(NSArray *)dataArray
{
    if (dataArray.count <= 1)
    {
        return nil;
    }
    NSMutableArray *resultArray = [NSMutableArray array];
    // 开始找type = 0
    for (int i = 1; i< dataArray.count-1; i++)
    {
        QuestionData *bigData = dataArray[i];
        
        if (bigData.type == 0)
        {
            // 找到所有组织
            NSMutableArray *allSame = [NSMutableArray array];
            [self getSameTitleArray:dataArray index:i direction:0 result:allSame];
            if (allSame.count > 1)
            {
                // 找到他们曾经的flag
                int getFlag = 0;

                for (QuestionData *flagData in allSame)
                {
                    if (flagData.type_flag > 1)
                    {
                        getFlag = flagData.type_flag;
                        break;
                    }
                }
                
                if (getFlag == 0)
                {
                    flagIndex ++;
                    getFlag = flagIndex;
                    
                    NSLog(@"22222_flag_index = %d",flagIndex);

                }
                
                for (QuestionData *flagData in allSame)
                {
                    flagData.type = 1;
                    flagData.type_flag = getFlag;

                    [resultArray addObject:[NSString stringWithFormat:@"update QUESTION_INFO_BEAN set type = 1,type_flag = %d where question_id = %@;\n",getFlag,flagData.question_Id]];
                }

//                NSLog(@"---------------------------------------------------------------------------------------------------------");
            }
        }
    }

    return [NSArray arrayWithArray:resultArray];
}

// 递归找组织算法：direction:0在中间 -1向前 1向后
+ (void)getSameTitleArray:(NSArray *)origin index:(NSInteger)index direction:(int)direction result:(NSMutableArray *)result
{
    QuestionData *indexData = origin[index];
    if (direction == 0)
    {
        [result addObject:indexData];
        [self getSameTitleArray:origin index:index direction:1 result:result];
        [self getSameTitleArray:origin index:index direction:-1 result:result];
    }
    else
    {
        if (index+direction<origin.count && index+direction>=0)
        {
            QuestionData *directionData = origin[index+direction];
            if ((indexData.type_flag > 2 && indexData.type_flag == directionData.type_flag)
                ||[self isSimilarStr:indexData.title Second:directionData.title])
            {
                [result addObject:directionData];
                [self getSameTitleArray:origin index:index+direction direction:direction result:result];
            }
        }
    }
}


+ (BOOL)isSimilarStr:(NSString *)first  Second:(NSString *)second
{
    if (first.length < 30 || second.length < 30)
    {
        if (first.length < 50 && second.length < 50)
        {
            return NO;
        }
    }
    
    if ([first containsString:@"。"])
    {
        NSRange range = [first rangeOfString:@"。" options:NSBackwardsSearch];
        NSString *temp = [first substringToIndex:range.location];
        if (temp.length > 20)
        {
            first = temp;
        }
    }

    if ([second containsString:@"。"])
    {
        NSRange range = [second rangeOfString:@"。" options:NSBackwardsSearch];
        NSString *temp = [second substringToIndex:range.location];
        if (temp.length > 20)
        {
            second = temp;
        }
    }

    
    if ([first isEqualToString:second] ||[second containsString:first] ||[first containsString:second])
    {
        return YES;
    }

    if (first.length > 80) {first = [first substringToIndex:first.length - 20];}
    else if (first.length > 50) { first = [first substringToIndex:first.length - 10];}
    
    if (second.length > 80){ second = [second substringToIndex:second.length - 20];}
    else if (second.length > 50) { second = [second substringToIndex:second.length - 10];}
    
    if ([first isEqualToString:second] ||[first containsString:second] ||[second containsString:first]){ return YES; }
    
    NSInteger smallLength = first.length;
    if (first.length > second.length){ first = [first substringToIndex:second.length]; smallLength = second.length;}
    else if (second.length > first.length) {second = [second substringToIndex:first.length];}
    
    // 公共题干允许12个字差异
    static NSInteger segmentationCount = 16;
    

    NSInteger differentCount  = 0;

    for (NSInteger i = 0 ; i < smallLength; i++)
    {
        NSString *temp  = [first substringWithRange:NSMakeRange( i, 1)] ;
        if (![second containsString:temp])
        {
            differentCount++;
        }
    }
    if (differentCount <= segmentationCount)
    {
        float ff = (float)differentCount/smallLength;
        if (ff > 0.26)
        {
            return NO;
        }
        else
        {
            return YES;
        }
    }
    
    return false;
}

// 找出异常点，然后人工识别纠错
+ (void)checkSameCutTitle
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray])
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        NSLog(@"filePath:%@",filePath);
        
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db)
         {
             // 找出遗漏的特异点
             {
                 NSString *sqlT = @"select year,unit,min(NUMBER_NUMBER) as min ,max(NUMBER_NUMBER) as max from QUESTION_INFO_BEAN where type = 1 group by year,unit order by year,unit,NUMBER_NUMBER ";
                 FMResultSet *rsT =  [db executeQuery:sqlT];
                 NSMutableArray *dataArray = [NSMutableArray array];
                 
                 while (rsT.next)
                 {
                     // 找出区域内断开的数据
                     NSString *sqlT2 = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year=%d and unit='%@' and NUMBER_NUMBER between %d and %d order by NUMBER_NUMBER asc",[rsT intForColumn:@"year"],[rsT stringForColumn:@"unit"],[rsT intForColumn:@"min"], [rsT intForColumn:@"max"]];
                     
                     FMResultSet *rsT2 =  [db executeQuery:sqlT2];
                     while (rsT2.next)
                     {
                         QuestionData *data = [[QuestionData alloc] init];
                         data.question_Id = [rsT2 stringForColumn:@"question_Id"];
                         data.title = [rsT2 stringForColumn:@"title"];
                         data.year = [rsT2 intForColumn:@"year"];
                         data.unit = [rsT2 stringForColumn:@"unit"];
                         data.number_number = [rsT2 intForColumn:@"number_number"];
                         data.type = [rsT2 intForColumn:@"type"];
                         data.type_flag = [rsT2 intForColumn:@"type_flag"];
                         data.cut_title = [rsT2 stringForColumn:@"cut_title"];
                         [dataArray addObject:data];
                     }
                     
                     [rsT2 close];
                 }
                 
                 [rsT close];
                 
                 
                 if (dataArray.count > 0)
                 {
                     for (int i = 1; i< dataArray.count-1; i++)
                     {
                         QuestionData *currData = dataArray[i];
                         QuestionData *pre = dataArray[i-1];
                         QuestionData *next = dataArray[i+1];
                         if (currData.type==0 && pre.type==1 && next.type==1)
                         {
                             NSLog(@"%d_%@_%d_%@",currData.year,currData.unit,currData.number_number,currData.title);
                         }
                     }
                 }
             }
             
             {
                 // 找出间断的不连续的隔离出来得公共题干
                 NSString *sql = @"select year,unit from QUESTION_INFO_BEAN  where type = 1 group by year,unit order by year,unit asc";
                 FMResultSet *rs =  [db executeQuery:sql];
                 
                 while(rs.next)
                 {
                     // 找出区域内断开的数据
                     NSString *sql2 = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN  where year = %d and unit = '%@' and type = 1 order by NUMBER_NUMBER asc",[rs intForColumn:@"year"],[rs stringForColumn:@"unit"]] ;
                     FMResultSet *rs2 =  [db executeQuery:sql2];
                     
                     NSMutableArray *bigArray = [NSMutableArray array];
                     NSMutableArray *smallArray = [NSMutableArray array];
                     int lastNumber=0;
                     while (rs2.next)
                     {
                         if (lastNumber == 0)
                         {
                             // 开头
                         }
                         else if ([rs2 intForColumn:@"NUMBER_NUMBER"] == lastNumber + 1)
                         {
                             // 连续题目
                         }
                         else
                         {
                             // 间断了
                             if (smallArray.count>1)
                             {
                                 [bigArray addObject:smallArray];
                                 smallArray = [NSMutableArray array];
                             }
                         }
                         
                         lastNumber = [rs2 intForColumn:@"NUMBER_NUMBER"];
                         
                         QuestionData *data = [[QuestionData alloc] init];
                         data.question_Id = [rs2 stringForColumn:@"question_Id"];
                         data.title = [rs2 stringForColumn:@"title"];
                         data.year = [rs2 intForColumn:@"year"];
                         data.unit = [rs2 stringForColumn:@"unit"];
                         data.number_number = [rs2 intForColumn:@"number_number"];
                         data.type = [rs2 intForColumn:@"type"];
                         data.type_flag = [rs2 intForColumn:@"type_flag"];
                         data.cut_title = [rs2 stringForColumn:@"cut_title"];
                         
                         [smallArray addObject:data];
                         
                     }
                     
                     if (smallArray.count>1)
                     {
                         [bigArray addObject:smallArray];
                     }
                     
                     for (NSArray *small in bigArray)
                     {
                         if (small.count < 6)
                         {
                             for (QuestionData *data in small)
                             {
                                 NSLog(@"%d_%@_%d_%@",data.year,data.unit,data.number_number,data.title);
                             }
                         }
                     }
                     
                     [rs2 close];
                 }
                 
                 [rs close];
             }
         }];
    }
}


@end
