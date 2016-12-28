//
//  PublicAnswers.m
//  SQLBuilder
//
//  Created by  on 2016/12/22.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import "PublicAnswers.h"

@implementation PublicAnswers


// 公共选项
+ (void)publicAnswerSearch
{
    [self sameAnswerList];
    
    [self checkSameAnswers];
}
// 公共选项
+ (void)sameAnswerList
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray])
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        
        [_sqlDb inDatabase:^(FMDatabase *db)
         {
             {
                 // 1、 添加字段COMBINE_ANSWER,设置内容为空
                 [db executeUpdate:@"alter table QUESTION_INFO_BEAN add COLUMN TYPE_FLAG INTEGER DEFAULT 0"];
             }

             // 二位数组记录结果
             NSMutableArray *dataArray = [NSMutableArray array];
             
             FMResultSet *rs =  [db executeQuery:@"select * from QUESTION_INFO_BEAN where type = 0 group by year,unit"];
             
             while (rs.next)
             {
                 NSString *query = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year=%d and unit='%@' and type = 0 order by NUMBER_NUMBER asc",[rs intForColumn:@"year"],[rs stringForColumn:@"unit"]];
                 FMResultSet *rs2 =  [db executeQuery:query];
                 
                 while (rs2.next)
                 {
                     QuestionData *data = [[QuestionData alloc] init];
                     data.question_Id = [rs2 stringForColumn:@"question_Id"];
                     data.year = [rs2 intForColumn:@"year"];
                     data.unit = [rs2 stringForColumn:@"unit"];
                     data.number_number = [rs2 intForColumn:@"number_number"];
                     data.type = [rs2 intForColumn:@"type"];
                     data.type_flag = [rs2 intForColumn:@"type_flag"];
                     data.COMBINE_ANSWER = [rs2 stringForColumn:@"COMBINE_ANSWER"];
                     [dataArray addObject:data];
                 }
                 
                 [rs2 close];
             }
             
             NSArray *updateStrArray = [self searchSimilarAnswers:dataArray];
             for (NSString * sql in updateStrArray) {
                 if (sql) {
                     bool result = [db executeUpdate:sql];
                     if (!result) {
                         NSLog(@"update error");
                         break;
                     }
                 }
             }
             
             [rs close];
         }];
    }
}

+ (NSArray *)searchSimilarAnswers:(NSArray *)dataArray
{
    if (dataArray.count <= 1)
    {
        return nil;
    }
    NSMutableArray *resultArray = [NSMutableArray array];
    int flag_start = 10000;

    // 开始找type = 0
    for (int i = 0; i< dataArray.count; i++)
    {
        QuestionData *bigData = dataArray[i];
        if (bigData.type == 0)
        {
            // 找到所有组织
            NSMutableArray *allSame = [NSMutableArray array];
            [self getSameAnswers:dataArray index:i direction:0 result:allSame];
            if (allSame.count > 1)
            {
                int tempFlag = flag_start ++;
                for (QuestionData *flagData in allSame)
                {
                    flagData.type = 3;
                    flagData.type_flag = tempFlag;
                    
                    NSLog(@"%@",flagData.COMBINE_ANSWER);
                    
                    [resultArray addObject:[NSString stringWithFormat:@"update QUESTION_INFO_BEAN set type = 3,type_flag = %d where question_id = %@;\n",flagData.type_flag,flagData.question_Id]];
                }
                
                NSLog(@"---------------------------------------------------------------------------------------------------------");
            }
        }
    }
        
    return [NSArray arrayWithArray:resultArray];
}

// 递归找组织算法：direction:0在中间 -1向前 1向后
+ (void)getSameAnswers:(NSArray *)origin index:(NSInteger)index direction:(int)direction result:(NSMutableArray *)result
{
    QuestionData *indexData = origin[index];
    if (direction == 0)
    {
        [result addObject:indexData];
        [self getSameAnswers:origin index:index direction:1 result:result];
        //        [self getSameAnswers:origin index:index direction:-1 result:result];
    }
    else
    {
        if (index+direction<origin.count && index+direction>=0)
        {
            QuestionData *directionData = origin[index+direction];
            if ([self isSimilarStr:indexData.COMBINE_ANSWER Second:directionData.COMBINE_ANSWER])
            {
                [result addObject:directionData];
                [self getSameAnswers:origin index:index+direction direction:direction result:result];
            }
        }
    }
}


+ (BOOL)isSimilarStr:(NSString *)first  Second:(NSString *)second
{
    if ([first isEqualToString:second])
    {
        return YES;
    }
    
    return false;
}

// 找出异常点，然后人工识别纠错
+ (void)checkSameAnswers
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
                 NSString *sqlT = @"select year,unit,min(NUMBER_NUMBER) as min ,max(NUMBER_NUMBER) as max from QUESTION_INFO_BEAN where type = 3 group by year,unit order by year,unit,NUMBER_NUMBER ";
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
                         data.year = [rsT2 intForColumn:@"year"];
                         data.unit = [rsT2 stringForColumn:@"unit"];
                         data.number_number = [rsT2 intForColumn:@"number_number"];
                         data.type = [rsT2 intForColumn:@"type"];
                         data.type_flag = [rsT2 intForColumn:@"type_flag"];
                         data.COMBINE_ANSWER = [rsT2 stringForColumn:@"COMBINE_ANSWER"];
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
                             NSLog(@"%d_%@_%d_%@",currData.year,currData.unit,currData.number_number,currData.COMBINE_ANSWER);
                         }
                     }
                 }
             }
             
             {
                 // 找出间断的不连续的隔离出来得公共题干
                 NSString *sql = @"select year,unit from QUESTION_INFO_BEAN  where type = 3 group by year,unit order by year,unit asc";
                 FMResultSet *rs =  [db executeQuery:sql];
                 
                 while(rs.next)
                 {
                     // 找出区域内断开的数据
                     NSString *sql2 = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN  where year = %d and unit = '%@' and type = 3 order by NUMBER_NUMBER asc",[rs intForColumn:@"year"],[rs stringForColumn:@"unit"]] ;
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
                         data.year = [rs2 intForColumn:@"year"];
                         data.unit = [rs2 stringForColumn:@"unit"];
                         data.number_number = [rs2 intForColumn:@"number_number"];
                         data.type = [rs2 intForColumn:@"type"];
                         data.type_flag = [rs2 intForColumn:@"type_flag"];
                         data.COMBINE_ANSWER = [rs2 stringForColumn:@"COMBINE_ANSWER"];
                         
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
                                 NSLog(@"%d_%@_%d_%@",data.year,data.unit,data.number_number,data.COMBINE_ANSWER);
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
