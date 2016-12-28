//
//  otherMethod.m
//  SQLBuilder
//
//  Created by  on 2016/12/22.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import "otherMethod.h"

@implementation otherMethod


+ (void)updateNumber_number
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray])
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        NSLog(@"%@",filePath);
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            FMResultSet *rs =  [db executeQuery:@"select * from QUESTION_INFO_BEAN"];
            
            while (rs.next)
            {
                NSString *numberText = [rs stringForColumn:@"NUMBER"];
                NSArray *array = [numberText componentsSeparatedByString:@"-"];
                if (array.count < 2) {
                    array = [numberText componentsSeparatedByString:@"N"];
                }
                if (array.count > 1)
                {
                    NSString *last = array.lastObject;
                    NSString *sql = nil;
                    
                    if ([last containsString:@"A"])
                    {
                        array = [last componentsSeparatedByString:@"A"];
                        sql = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set NUMBER_NUMBER = %@ where QUESTION_ID = %d;",array.firstObject,[rs intForColumn:@"QUESTION_ID"]];
                    }
                    else if ([last containsString:@"B"])
                    {
                        array = [last componentsSeparatedByString:@"B"];
                        sql = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set NUMBER_NUMBER = %@ where QUESTION_ID = %d;",array.firstObject,[rs intForColumn:@"QUESTION_ID"]];
                    }
                    else
                    {
                        sql = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set NUMBER_NUMBER = %@ where QUESTION_ID = %d;",array.lastObject,[rs intForColumn:@"QUESTION_ID"]];
                    }
                    
                    if (sql.length)
                    {
                        BOOL update = [db executeUpdate:sql];
                        if (!update)
                        {
                            NSLog(@"分割失败——%d",[rs intForColumn:@"QUESTION_ID"]);
                        }
                    }
                    else
                    {
                        NSLog(@"分割失败——%d",[rs intForColumn:@"QUESTION_ID"]);
                    }
                }
                else
                {
                    NSLog(@"分割失败——%d",[rs intForColumn:@"QUESTION_ID"]);
                }
            }
        }];
        
    }
}

// 答案合成
+ (void)getAndUpdateAnswerText
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray]) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            // 1、 添加字段COMBINE_ANSWER
            NSString *alert = @"alter table QUESTION_INFO_BEAN add COLUMN COMBINE_ANSWER TEXT DEFAULT NULL";
            BOOL result  = [ db executeUpdate:alert];
            
            
            // 2、合成答案
            FMResultSet *rs =  [db executeQuery:@"select QUESTION_ID from QUESTION_INFO_BEAN GROUP BY QUESTION_ID"];
            
            while (rs.next)
            {
                int QUESTION_ID = [rs intForColumn:@"QUESTION_ID"];
                NSString *qq = [NSString stringWithFormat:@"select * from QUESTION_OPTION_BEAN where QUESTION_ID=%d order by KEY asc",QUESTION_ID];
                
                FMResultSet *rs2 = [db executeQuery: qq];
                NSMutableString *str = [NSMutableString string];
                while (rs2.next)
                {
                    if (str.length) {
                        [str appendFormat:@"|"];
                    }
                    // 如果有单引号，匹配为两个单引号
                    NSString *value = [rs2 stringForColumn:@"VALUE"];
                    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if ([value containsString:@"'"])
                    {
                        value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                    }
                    // 如果最后一个字符是空格，做一个trim
                    if ([value hasPrefix:@" "] || [value hasSuffix:@" "])
                    {
                        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    }
                    [str appendString:value];
                    
                    //                    NSLog(@"%@:%@",[rs2 stringForColumn:@"KEY"],[rs2 stringForColumn:@"VALUE"]);
                }
                
                [rs2 close];
                
                // 插入答案
                NSString *updateSql = [NSString stringWithFormat:@"UPDATE QUESTION_INFO_BEAN SET COMBINE_ANSWER = '%@' where QUESTION_ID=%d", str, QUESTION_ID];
                BOOL result  = [ db executeUpdate:updateSql];
                if (!result) {
                    NSLog(@"ssssssssssssssssssssssssss");
                }
            }
            
            [rs close];
            
        }];
    }
}

// 删除完全重复数据
+ (void)deleteRepeatData
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray]) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            NSString *selectStr = @"select QUESTION_ID from QUESTION_INFO_BEAN group by TITLE,COMBINE_ANSWER having count(*) > 1";
            // 查询到重复的题目和答案
            FMResultSet *rs =  [db executeQuery:selectStr];
            
            if (rs.next)
            {
                // 删除重复
                NSString *deleteStr = [NSString stringWithFormat:@"delete from QUESTION_INFO_BEAN where QUESTION_ID in (%@)",selectStr];
                BOOL result  = [ db executeUpdate:deleteStr];
                if (result) {
                    NSLog(@"delete success");
                }
                
                [rs close];
                
                [self deleteRepeatData];
            }
        }];
    }
}

// 多选题 审核 并不能挑选
+ (void) multiChoice
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray])
    {
        
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            /*            NSInteger number = 0;
             
             FMResultSet *rs =  [db executeQuery:@"select * from QUESTION_INFO_BEAN"];
             
             while (rs.next)
             {
             NSString *answer = [rs stringForColumn:@"answer"];
             if (answer.length > 1) {
             number++;
             }
             }
             
             [rs close];
             
             NSLog(@"db:%@ num:%ld",name,number);
             
             FMResultSet *rs2 =  [db executeQuery:@"SELECT count() as count ,type from QUESTION_INFO_BEAN group by type"];
             while (rs2.next)
             {
             NSLog(@"type_%@: %d",[rs2 stringForColumn:@"type"],[rs2 intForColumn:@"count"]);
             }
             
             [rs2 close];
             */
            
            
            BOOL result  = [db executeUpdate:@"update QUESTION_INFO_BEAN set type = 0 where type <> 2"];
            if (!result) {
                NSLog(@"ssssssssssssssssssssssssss");
            }
            
        }];
    }
}

// 数据加密
+ (void)encryptionDate
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray])
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        NSLog(@"fileName:%@",name);
        
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            NSString * selectStr =@"select QUESTION_ID, ANSWER from QUESTION_INFO_BEAN";
            
            FMResultSet * rs = [db executeQuery:selectStr];
            
            while (rs.next) {
                
                NSString *  _id = [rs stringForColumn:@"QUESTION_ID"];
                NSString * CORRECT_ANSWER = [rs stringForColumn:@"ANSWER"];
                
                dic[_id] = CORRECT_ANSWER;
            }
        }];
        
        
        [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            
            NSString * CORRECT_ANSWER = (NSString *)obj;
            CORRECT_ANSWER = [NSData AES256EncryptWithPlainText:CORRECT_ANSWER];
            
            NSString * updateStr = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set ANSWER = '%@' where QUESTION_ID = %@ " , CORRECT_ANSWER , key];
            
            [_sqlDb  inDatabase:^(FMDatabase *db) {
                
                bool ret = [db executeUpdate:updateStr   ];
                if (!ret) {
                    NSLog(@"%d" ,ret);
                }
            }];
        }];

    }
}

// 打印最后的调整文本
+ (void)printText
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in [self getDBNameArray])
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        FMDatabaseQueue *_sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            int number = 0;
            NSString *selectStr = @"select TYPE_FLAG , count() as count from QUESTION_INFO_BEAN where TYPE_FLAG > 2  group by TYPE_FLAG having count > 1 order by count";

            FMResultSet * rs = [db executeQuery:selectStr];
            
            NSMutableString *deleteQueue = [NSMutableString string];
            NSMutableString *updateQueue = [NSMutableString string];
            
            while (rs.next)
            {
                number ++ ;
                
                NSMutableString *smallQueue = [NSMutableString string];
                
                int start_question_id = 0;

                NSString *sssssssql2 = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where TYPE_FLAG = %d order by NUMBER_NUMBER asc",[rs intForColumn:@"TYPE_FLAG"]];
                
                FMResultSet *rs2 = [db executeQuery:sssssssql2];

                while (rs2.next)
                {
                    if (start_question_id == 0)
                    {
                        start_question_id = [rs2 intForColumn:@"QUESTION_ID"];
                    }
                    else
                    {
                        [smallQueue appendFormat:@"%d,",[rs2 intForColumn:@"QUESTION_ID"]];
                    }
                }
                
                [rs2 close];
                
                if (smallQueue.length)
                {
                    [deleteQueue appendString:smallQueue];
                    [updateQueue appendFormat:@"update ANSWER SET QUESTION_ID = %d where QUESTION_ID in (%@);\n",start_question_id,[smallQueue substringToIndex:smallQueue.length-1]];
                }
            }
            
            [rs close];
            
            NSLog(@"deleteQueue:\n %@",deleteQueue);
            NSLog(@"updateQueue:\n %@",updateQueue);
            
            NSLog(@"特殊题个数：%d",number);
            
            NSString *deleteStr = [NSString stringWithFormat:@"delete from QUESTION where QUESTION_ID  in (%@)",[deleteQueue substringToIndex:deleteQueue.length-1]];
            NSString *resultStr = [NSString stringWithFormat:@"%@\n\n\n\n\n\n%@", deleteStr, updateQueue];
            NSFileManager *fm = [NSFileManager defaultManager];
            NSString* _filename = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.txt",[name substringToIndex:name.length - 3]]];
            //创建目录
            [fm createFileAtPath:_filename contents:[resultStr dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

        }];
    }
}

@end
