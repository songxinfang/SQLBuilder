//
//  AppDelegate.m
//  SQLBuilder
//
//  Created by  on 2016/12/14.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import "AppDelegate.h"
#import "FMDB.h"
#import "NSData+AES256.h"

@interface AppDelegate ()

@property(nonatomic , strong) FMDatabaseQueue * sqlDb;
@property(nonatomic , strong) NSArray *DBNameArray;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    self.DBNameArray = @[@"口腔执业医师.db",
                          @"临床执业医师.db",
                          @"临床执业助理医师考试.db",
                          @"西药执业药师.db",
                          @"中西医结合执业助理医师考试.db",
                          @"中药执业药师.db",
                          @"中医执业医师考试_有题型.db"
                          ];

//    [self getAndUpdateAnswerText];
    
//    [self deleteRepeatData];
    
//    [self multiChoice];
    
//    [self cutTitle];

    [self sameCutTitle];
    
//    [self sameAnswerList];
    
//    [self encryptionDate];

    return YES;
}

// 答案合成
- (void)getAndUpdateAnswerText
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    for (NSString * name in _DBNameArray) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            // 1、 添加字段COMBINE_ANSWER
            NSString *alert = @"alter table QUESTION_INFO_BEAN add COLUMN COMBINE_ANSWER TEXT DEFAULT NULL";
            BOOL result  = [ db executeUpdate:alert];
            if (result) {
                NSLog(alert);
            }

            
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
- (void)deleteRepeatData
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in _DBNameArray) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
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


// 截断句号、找出相似题
- (void)cutTitle
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    _DBNameArray = @[@"临床执业医师.db"];
    for (NSString * name in _DBNameArray) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        NSInteger minLength = 20;
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            {
                // 1、 添加字段COMBINE_ANSWER,设置内容为空
                [db executeUpdate:@"alter table QUESTION_INFO_BEAN add COLUMN CUT_TITLE TEXT DEFAULT NULL"];
                [db executeUpdate:@"alter table QUESTION_INFO_BEAN add COLUMN TYPE_FLAG INTEGER DEFAULT 0"];

                [db executeUpdate:@"update QUESTION_INFO_BEAN set CUT_TITLE = '',TYPE_FLAG=0"];
            }
            
            {
                // 2、提取最后一个句号之前的内容，然后去掉逗号和句号
                FMResultSet *rs =  [db executeQuery:@"select TITLE,QUESTION_ID from QUESTION_INFO_BEAN where type = 0"];
                
                while (rs.next)
                {
                    NSString *title = [rs stringForColumn:@"TITLE"];
                    if ([title containsString:@"。"])
                    {
                        NSRange range = [title rangeOfString:@"。" options:NSBackwardsSearch];
                        NSString *first = [title substringToIndex:range.location+range.length];
                        
                        first = [first stringByReplacingOccurrencesOfString:@"kg" withString:@"公斤"];
                        first = [first stringByReplacingOccurrencesOfString:@"：" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"；" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"，" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"、" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"。" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"的" withString:@""];
                        if (first.length > minLength)
                        {
                            // 插入答案
                            if ([first containsString:@"'"])
                            {
                                first = [first stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                            }
                            NSInteger questionid = [rs intForColumn:@"QUESTION_ID"];
                            
                            NSString *updateSql = [NSString stringWithFormat:@"UPDATE QUESTION_INFO_BEAN SET CUT_TITLE = '%@',TYPE_FLAG = 1 where QUESTION_ID=%ld", first, questionid];
                            BOOL result  = [ db executeUpdate:updateSql];
                            if (!result) {
                                NSLog(@"ssssssssssssssssssssssssss");
                            }
                        }
//                        else
//                        {
//                            NSLog(@"比较短的——%@",first);
//                        }
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
                        
                        first = [first stringByReplacingOccurrencesOfString:@"kg" withString:@"公斤"];
                        first = [first stringByReplacingOccurrencesOfString:@"：" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"；" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"，" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"、" withString:@""];
                        first = [first stringByReplacingOccurrencesOfString:@"的" withString:@""];

                        if (first.length > minLength) {
                            // 插入答案
                            if ([first containsString:@"'"])
                            {
                                first = [first stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                            }
                            NSInteger questionid = [rs intForColumn:@"QUESTION_ID"];
                            
                            NSString *updateSql = [NSString stringWithFormat:@"UPDATE QUESTION_INFO_BEAN SET CUT_TITLE = '%@' ,TYPE_FLAG = 1 where QUESTION_ID=%ld", first, questionid];
                            BOOL result  = [ db executeUpdate:updateSql];
                            if (!result) {
                                NSLog(@"ssssssssssssssssssssssssss");
                            }
                        }
//                        else
//                        {
//                            NSLog(@"比较短的——%@",first);
//                        }
                    }
                }
                
                [rs close];
            }
            
            {
                // 太简单的匹配pass
                [db executeUpdate:@"update  QUESTION_INFO_BEAN set CUT_TITLE = '',TYPE_FLAG = 0 where CUT_TITLE like '%，%岁'"];
            }
        }];
    }
}

// 多选题 审核 并不能挑选
- (void) multiChoice
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in _DBNameArray)
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        NSLog(@"db:%@ path:%@",name,documentsPath);
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
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

// 公共题干
- (void)sameCutTitle
{
    NSArray *array = @[
                       // year,unit_U,startNUM,……,lastNUM
                       @"2000,U2,132,2,3,3,2,3,3,3,3,3,4,160",
                       @"2000,U3,126,3,4,3,3,2,2,2,2,4,4,4,2,160",
                       @"2000,U4,133,3,3,3,2,3,3,2,3,4,2,160",
                       @"2001,U2,129,2,3,3,3,2,2,2,3,3,3,2,2,2,160",
                       @"2001,U3,129,3,3,3,3,2,3,2,3,3,2,2,3,160",
                       @"2001,U4,133,2,2,2,3,2,2,2,2,3,2,3,3,160",
                       @"2002,U1,66,3,3,5,4,80",
                       @"2002,U1,149,2,2,2,2,2,2,160",
                       @"2002,U2,68,2,3,2,3,3,80",
                       @"2002,U2,151,2,3,2,3,160",
                       @"2002,U3,69,2,3,2,2,3,80",
                       @"2002,U3,148,2,2,1,3,3,2,160",
                       @"2002,U4,69,3,3,3,3,80",
                       @"2002,U4,149,4,3,3,2,160",
                       @"2003,U1,69,3,2,2,3,2,80",
                       @"2003,U1,149,3,4,3,2,160",
                       @"2003,U2,69,3,2,2,3,2,80",
                       @"2003,U2,149,3,4,3,2,160",
                       @"2003,U3,69,2,2,2,3,3,80",
                       @"2003,U3,149,2,1,2,2,3,2,160",
                       @"2003,U4,67,3,3,2,4,2,80",
                       @"2003,U4,146,3,3,3,3,3,160",
                       @"2004,U1,128,3,4,2,5,3,3,3,150",
                       @"2004,U2,128,3,2,2,3,5,2,2,4,150",
                       @"2004,U3,127,2,2,2,2,2,3,3,3,3,2,150",
                       @"2004,U4,126,3,3,3,2,2,2,3,2,5,150",
                       @"2005,U1,128,3,2,2,2,3,2,3,3,3,150",
                       @"2005,U2,128,3,4,3,5,4,4,150",
                       @"2005,U3,127,3,3,2,3,2,3,3,3,2,150",
                       @"2005,U4,126,3,3,2,3,2,2,3,2,3,2,150",
                       @"2006,U1,131,2,2,2,5,3,3,3,150",
                       @"2006,U2,128,3,2,2,3,2,3,2,2,4,150",
                       @"2006,U3,127,3,3,2,2,3,3,3,3,2,150",
                       @"2006,U4,126,3,3,2,3,2,2,3,2,3,2,150",
                       @"2007,U1,82,4,85",
                       @"2007,U1,131,3,3,3,2,3,2,2,2,150",
                       @"2007,U2,131,3,3,3,3,2,3,3,150",
                       @"2007,U3,127,3,3,3,3,4,3,3,2,150",
                       @"2007,U4,138,2,3,3,1,4,150",
                       @"2008,U1,128,3,2,2,2,3,2,3,3,3,150",
                       @"2008,U2,128,3,2,2,3,3,2,2,2,2,2,150",
                       @"2008,U3,125,3,3,2,4,3,3,3,3,2,150",
                       @"2009,U1,122,3,2,3,129",
                       @"2009,U1,143,3,3,2,150",
                       @"2009,U4,103,2,104",
                       @"2009,U4,116,3,3,121",
                       @"2009,U4,125,2,2,4,3,3,2,2,142",
                       @"2010,U1,106,4,4,3,3,119",
                       @"2010,U1,134,2,2,3,3,3,2,2,150",
                       @"2010,U2,114,3,2,3,3,3,4,3,2,2,3,3,2,3,149",
                       @"2010,U3,126,3,2,3,3,4,2,2,3,3,150",
                       @"2010,U4,145,2,2,2,150",
                       @"2011,U1,128,3,2,2,2,3,3,2,3,3,150",
                       @"2011,U2,116,2,3,2,2,2,2,3,2,2,2,2,2,2,2,2,3,150",
                       @"2011,U3,116,2,3,3,3,3,3,2,3,3,3,3,4,150",
                       @"2011,U4,144,2,3,2,150",
                       @"2012,U1,120,3,2,2,126",
                       @"2012,U2,109,2,2,2,2,2,2,2,2,2,2,2,2,2,134",
                       @"2012,U3,95,3,2,3,3,4,3,3,3,3,3,3,2,3,2,134",
                       @"2012,U4,111,2,2,2,3,2,2,3,3,3,2,3,137",
                       @"2013,U1,120,3,2,2,126",
                       @"2013,U2,109,2,2,3,3,3,2,2,3,2,2,2,2,136",
                       @"2013,U3,107,2,2,2,2,2,2,2,2,3,2,2,2,3,2,136",
                       @"2013,U4,101,2,3,2,3,3,3,3,3,5,2,3,3,135",
                       @"2014,U1,117,2,2,3,3,126",
                       @"2014,U2,109,2,2,3,3,2,4,2,3,3,2,134",
                       @"2014,U3,107,3,3,2,3,2,2,2,2,3,2,2,2,2,136",
                       @"2014,U4,101,5,2,3,2,3,3,3,3,3,3,3,2,135",
                       @"2015,U1,116,2,3,3,2,125",
                       @"2015,U2,109,2,2,2,2,3,2,2,2,4,4,3,136",
                       @"2015,U3,106,2,4,3,1,2,3,2,2,2,2,3,3,2,136",
                       @"2015,U4,101,2,2,3,3,3,3,3,4,3,3,3,3,135"
                       ];

    // 先教研数据正确性
    for (NSString *content in array)
    {
        NSArray *contentArray = [content componentsSeparatedByString:@","];
        NSInteger start = [[contentArray objectAtIndex:2] integerValue];
        NSInteger end = [contentArray.lastObject integerValue];

        NSInteger sub = 0;
        for (int i = 3; i< contentArray.count - 1; i++)
        {
            sub += [[contentArray objectAtIndex:i] integerValue];
        }
        
        if (start + sub == end + 1)
        {
            NSLog(@"数据正确");
        }
        else
        {
            NSLog(@"!!!!数据错误：%@",content);
        }
    }

    return;
    
//    select NUMBER_NUMBER , title from QUESTION_INFO_BEAN where NUMBER_NUMBER > 120 order by year,unit,NUMBER_NUMBER asc
    self.DBNameArray = @[
                         @"临床执业医师",
//                         @"临床执业助理医师考试",
//                         @"西药执业药师",
//                         @"中西医结合执业助理医师考试",
//                         @"中药执业药师",
                         ];
    

    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in _DBNameArray)
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db",name]];
        NSLog(@"db:%@ path:%@",name,documentsPath);
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            for (NSString *content in array)
            {
                NSArray *contentArray = [content componentsSeparatedByString:@","];
                NSString *sql = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year = '%@' and unit = '%@' and NUMBER_NUMBER between %d and %d order by NUMBER_NUMBER",contentArray[0],contentArray[1],[[contentArray objectAtIndex:2] integerValue],[contentArray.lastObject integerValue]];
                
                FMResultSet *rs =  [db executeQuery:sql];
                
                while (rs.next)
                {
                    NSLog(@"%d: %@",[rs intForColumn:@"NUMBER_NUMBER"],[rs stringForColumn:@"title"]);
                }
            }
            
//            // 二位数组记录结果
//            NSMutableArray *bigArray = [NSMutableArray array];
//            NSMutableArray *smallArray = [NSMutableArray array];
//
//
////            NSInteger number = 0;
////            for (NSArray *arr in bigArray)
////            {
////                if (arr.count > 5) {
////                    NSLog(@"%@",arr);
////                }
////                number += arr.count;
////            }
////            NSLog(@"%ld,%@",number,bigArray);
//
//            {
//                NSMutableString *firstStr = [NSMutableString string];
//                NSMutableString *lastStr = [NSMutableString string];
//                NSMutableString *updateListStr = [NSMutableString string];
//                
//                int bigIndex = 0;
//                for (NSArray *arr in bigArray)
//                {
//                    bigIndex ++;
//                    int index = 0;
//                    NSMutableString *temp = [NSMutableString string];
//
//                    for (NSNumber *number in arr)
//                    {
//                        [firstStr appendFormat:@"%@,",number];
//
//                        if (index > 0)
//                        {
//                            if ((index == arr.count - 1) && (bigIndex == bigArray.count)) {
//                                [lastStr appendFormat:@"%@",number];
//                            }
//                            else
//                            {
//                                [lastStr appendFormat:@"%@,",number];
//                            }
//                            
//                            if (index == arr.count - 1)
//                            {
//                                [temp appendFormat:@"%@",number];
//                            }
//                            else
//                            {
//                                [temp appendFormat:@"%@,",number];
//                            }
//                        }
//                        index ++;
//                    }
//                    
//                    [updateListStr appendFormat:@"update ANSWER SET  QUESTION_ID = %@ where QUESTION_ID in (%@);\n",arr.firstObject, temp];
//                }
//                
//                firstStr = [firstStr substringToIndex:firstStr.length-1];
//                NSLog(@"first:%@",firstStr);
//                
////                NSLog(@"last:%@",lastStr);
////                NSLog(@"updateListStr:%@",updateListStr);
//                
//                NSString *typeStr = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set TYPE = 1 where QUESTION_ID in (%@)",firstStr];
//                BOOL ssss = [db executeUpdate:typeStr];
//                if (ssss) {
//                    NSLog(@"set success");
//                }

//
//                NSString *deleteStr = [NSString stringWithFormat:@"delete from QUESTION where QUESTION_ID  in (%@)",lastStr];
//                NSString *resultStr = [NSString stringWithFormat:@"%@\n\n\n\n\n\n%@\n\n\n\n\n%@",typeStr, deleteStr, updateListStr];
//                NSFileManager *fm = [NSFileManager defaultManager];
//                NSString* _filename = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"type_1_%@.txt",name]];
//                //创建目录
//                [fm createFileAtPath:_filename contents:[resultStr dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
//            }
        }];
    }
}

// 公共题干
- (void)sameAnswerList
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in _DBNameArray)
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        NSLog(@"db:%@ path:%@",name,documentsPath);
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            // 二位数组记录结果
            NSMutableArray *bigArray = [NSMutableArray array];
            NSMutableArray *smallArray = [NSMutableArray array];
            
            FMResultSet *rs =  [db executeQuery:@"select COMBINE_ANSWER from QUESTION_INFO_BEAN group by COMBINE_ANSWER having count(*) >1"];
            
            while (rs.next)
            {
                NSString *answer = [rs stringForColumn:@"COMBINE_ANSWER"];
                NSString *query = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where type = 0 and COMBINE_ANSWER = '%@' order by QUESTION_ID asc",answer];
                FMResultSet *rs2 =  [db executeQuery:query];
                
                smallArray = [NSMutableArray array];
                int question_id = 0;
                
                while (rs2.next)
                {
                    if (question_id == 0) {
                        question_id = [rs2 intForColumn:@"QUESTION_ID"];
                    }
                    else
                    {
                        int question_id2 = [rs2 intForColumn:@"QUESTION_ID"];
                        // 记录上一个id
                        [smallArray addObject:[NSNumber numberWithInt:question_id]];
                        question_id = question_id2;
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
            
            NSInteger number = 0;
            for (NSArray *arr in bigArray)
            {
                if (arr.count > 5) {
                    NSLog(@"%@",arr);
                }
                number += arr.count;
            }
            NSLog(@"number:%ld",number);
            
            {
                NSMutableString *firstStr = [NSMutableString string];
                NSMutableString *lastStr = [NSMutableString string];
                NSMutableString *updateListStr = [NSMutableString string];
                
                int bigIndex = 0;
                for (NSArray *arr in bigArray)
                {
                    bigIndex ++;
                    int index = 0;
                    NSMutableString *temp = [NSMutableString string];
                    
                    for (NSNumber *number in arr)
                    {
                        if (index == 0)
                        {
                            [firstStr appendFormat:@"%@",number];
                            if (bigIndex != bigArray.count)
                            {
                                [firstStr appendString:@","];
                            }
                        }
                        else
                        {
                            if ((index == arr.count - 1) && (bigIndex == bigArray.count)) {
                                [lastStr appendFormat:@"%@",number];
                            }
                            else
                            {
                                [lastStr appendFormat:@"%@,",number];
                            }
                            
                            if (index == arr.count - 1)
                            {
                                [temp appendFormat:@"%@",number];
                            }
                            else
                            {
                                [temp appendFormat:@"%@,",number];
                            }
                        }
                        index ++;
                    }
                    
                    [updateListStr appendFormat:@"update ANSWER SET  QUESTION_ID = %@ where QUESTION_ID in (%@);\n",arr.firstObject, temp];
                }
                
                NSLog(@"first:%@",firstStr);
                NSLog(@"last:%@",lastStr);
                NSLog(@"updateListStr:%@",updateListStr);

                NSString *typeStr = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set TYPE = 3 where QUESTION_ID in (%@)",firstStr];
                BOOL ssss = [db executeUpdate:typeStr];
                if (ssss)
                {
                    NSString *deleteStr = [NSString stringWithFormat:@"delete from QUESTION where QUESTION_ID  in (%@)",lastStr];
                    NSString *result = [NSString stringWithFormat:@"%@\n\n\n\n\n\n%@\n\n\n\n\n%@",typeStr, deleteStr, updateListStr];
                    NSFileManager *fm = [NSFileManager defaultManager];
                    NSString* _filename = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"type_3_%@.txt",name]];
                    //创建目录
                    [fm createFileAtPath:_filename contents:[result dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
                }
            }
            
            [rs close];
        }];
    }
}


// 数据加密
-(void)encryptionDate
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSLog(documentsPath);

    NSString *filePath = [documentsPath stringByAppendingPathComponent:@"origin2.db"];
    
    _sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];

    NSMutableDictionary * dic = [NSMutableDictionary dictionary];
    
    [_sqlDb inDatabase:^(FMDatabase *db) {
        
        NSString * selectStr =@"select _id , CORRECT_ANSWER  from ANSWER";
        
        FMResultSet * rs = [db executeQuery:selectStr];
        
        while (rs.next) {
            
            NSString *  _id = [rs stringForColumn:@"_id"];
            NSString * CORRECT_ANSWER = [rs stringForColumn:@"CORRECT_ANSWER"];
            
            dic[_id] = CORRECT_ANSWER;
        }
    }];
    
    
    [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        
        NSString * CORRECT_ANSWER = (NSString *)obj;
        CORRECT_ANSWER = [NSData AES256EncryptWithPlainText:CORRECT_ANSWER];
        
        NSString * updateStr = [NSString stringWithFormat:@"update ANSWER set CORRECT_ANSWER = '%@' where _id = %@ " , CORRECT_ANSWER , key];
        
        [_sqlDb  inDatabase:^(FMDatabase *db) {
            
            bool ret = [db executeUpdate:updateStr   ];
            NSLog(@"%d" ,ret);
            
            
            
        }];
    }];
}

@end
