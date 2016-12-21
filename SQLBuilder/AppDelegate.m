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
#import "QuestionData.h"

@interface AppDelegate ()
{
    int offCount;
}
@property(nonatomic , strong) FMDatabaseQueue * sqlDb;
@property(nonatomic , strong) NSArray *DBNameArray;

@end



@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    self.DBNameArray = @[
//                         @"口腔执业医师.db",
                          @"临床执业医师.db",
//                          @"临床执业助理医师考试.db",
//                          @"西药执业药师.db",
//                          @"中西医结合执业助理医师考试.db",
//                          @"中药执业药师.db",
//                          @"中医执业医师考试_有题型.db"
                          ];

//    [self getAndUpdateAnswerText];
    
//    [self deleteRepeatData];
    
//    [self multiChoice];
    
//    [self cutTitle];

//    [self sameCutTitleFirstStep];
    
    [self sameCutTitleSecondStep];
    
//    [self sameCutTitle2];
    
//    [self sameAnswerList];
    
//    [self encryptionDate];

    NSLog(@"================== END ==================");
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
    for (NSString * name in _DBNameArray) {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        NSInteger minLength = 10;
        
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
//                        else
//                        {
//                            NSLog(@"len1:%ld__%@————%@",first.length,first,title);
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
//                        else
//                        {
//                            NSLog(@"len2:%ld__%@————%@",first.length,first,title);
//                        }
                    }
                }
                
                [rs close];
            }
        }];
    }
}


-(NSString *)SymbolfilterWithStr:(NSString *) str
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

- (void)sameCutTitleSecondStep
{
    offCount = 6;
    
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in _DBNameArray)
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        NSLog(@"db:%@ path:%@",name,documentsPath);
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        

        [_sqlDb inDatabase:^(FMDatabase *db)
         {
             // 匹配相似的题目
             {
                 // 找到每年每单元的起始与截止位置
                 NSMutableArray *dataArray = [NSMutableArray array];
                 NSString *sql = @"select year,unit,min(NUMBER_NUMBER) as min ,max(NUMBER_NUMBER) as max from QUESTION_INFO_BEAN where type = 1 group by year,unit order by year,unit,NUMBER_NUMBER ";
                 
                 int count = 0;
                 FMResultSet *rs =  [db executeQuery:sql];
                 while (rs.next)
                 {
                     // 找出区域内断开的数据
                     NSString *sql2 = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year=%d and unit='%@' and NUMBER_NUMBER between %d and %d order by NUMBER_NUMBER asc",[rs intForColumn:@"year"],[rs stringForColumn:@"unit"],[rs intForColumn:@"min"]-offCount, [rs intForColumn:@"max"]+offCount];
                     
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
                 }
                 
                 [rs close];
                 
                 NSArray *updateStrArray = [self searchSimilarQuestion:dataArray];
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
             
             // 找出特异点
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
                 
                 NSMutableArray *tempArray = [NSMutableArray array];
                 for (int i = 1; i< dataArray.count-1; i++)
                 {
                     QuestionData *currData = dataArray[i];
                     QuestionData *pre = dataArray[i-1];
                     QuestionData *next = dataArray[i+1];
                     if (currData.type==0 && pre.type==1 && next.type==1)
                     {
                         [tempArray addObject:[NSString stringWithFormat:@"update QUESTION_INFO_BEAN set type_flag = 100000 where question_id = %@;\n",currData.question_Id]];
                     }
                 }
                 
                 for (NSString * sql in tempArray) {
                     if (sql) {
                         bool result = [db executeUpdate:sql];
                         if (!result) {
                             NSLog(@"update error");
                             break;
                         }
                     }
                 }
             }
             
         }];
    }
}

- (NSArray *)searchSimilarQuestion:(NSArray *)dataArray
{
    NSMutableArray *resultArray = [NSMutableArray array];
    int flag_start = 5000;
    int number = 0;
    // 开始找type = 0
    for (int i = 1; i< dataArray.count-1; i++)
    {
        QuestionData *bigData = dataArray[i];
        if (bigData.type == 0)
        {
            // 找到所有组织
            NSMutableArray *allSame = [NSMutableArray array];
            [self getSameArray:dataArray index:i direction:0 result:allSame];
            if (allSame.count > 1)
            {
                number ++;
                // 找到他们曾经的flag
                int getFlag = flag_start ++;
                
                for (QuestionData *flagData in allSame)
                {
                    if (flagData.type_flag > 1)
                    {
                        getFlag = flagData.type_flag;
                        break;
                    }
                }
                
                for (QuestionData *flagData in allSame)
                {
                    flagData.type = 1;
                    flagData.type_flag = getFlag;
                    
                    NSLog(@"%@",flagData.title);
                    [resultArray addObject:[NSString stringWithFormat:@"update QUESTION_INFO_BEAN set type = 1,type_flag = %d where question_id = %@;\n",getFlag,flagData.question_Id]];
                }

                NSLog(@"---------------------------------------------------------------------------------------------------------");
            }
        }
    }

    NSLog(@"number_%d",number);

    return [NSArray arrayWithArray:resultArray];
}

// 递归找组织算法：direction:0在中间 -1向前 1向后
- (void)getSameArray:(NSArray *)origin index:(NSInteger)index direction:(int)direction result:(NSMutableArray *)result
{
    QuestionData *indexData = origin[index];
    if ([indexData.question_Id isEqualToString:@"7046"])
    {
        NSLog(@"7046");
    }
    if (direction == 0)
    {
        [result addObject:indexData];
        [self getSameArray:origin index:index direction:1 result:result];
        [self getSameArray:origin index:index direction:-1 result:result];
    }
    else
    {
        if (index+direction<origin.count && index+direction>=0)
        {
            QuestionData *directionData = origin[index+direction];
            if ([self isSimilarStr:indexData.title Second:directionData.title])
            {
                [result addObject:directionData];
                [self getSameArray:origin index:index+direction direction:direction result:result];
            }
        }
    }
}

- (void)sameCutTitleFirstStep
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    for (NSString * name in _DBNameArray)
    {
        NSString *filePath = [documentsPath stringByAppendingPathComponent:name];
        NSLog(@"db:%@ path:%@",name,documentsPath);
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db)
         {
             // 二位数组记录结果
             NSMutableArray *bigArray = [NSMutableArray array];
             
             FMResultSet *rs =  [db executeQuery:@"select * from QUESTION_INFO_BEAN where type = 0 and CUT_TITLE <> ''"];
             
             while (rs.next)
             {
                 NSString *query = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year=%d and unit='%@' and type = 0 and CUT_TITLE like '%%%@%%' order by NUMBER_NUMBER asc",[rs intForColumn:@"year"],[rs stringForColumn:@"unit"],[rs stringForColumn:@"cut_title"]];
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
             
             
             {
                 int flag_index = 100;

                 for (NSArray *arr in bigArray)
                 {
                     flag_index ++;
                     
                     NSMutableString *firstStr = [NSMutableString string];
                     
                     for (NSNumber *number in arr)
                     {
                         [firstStr appendFormat:@"%@,",number];
                     }
                     
                     if (firstStr.length)
                     {
                         NSString *temp = [firstStr substringToIndex:firstStr.length-1];
                         NSString *typeStr = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set TYPE = 1,TYPE_FLAG = %d where QUESTION_ID in (%@)", flag_index, temp];
                         BOOL ssss = [db executeUpdate:typeStr];
                         if (!ssss) {
                             NSLog(@"update error");
                         }
                     }
                 }
                 

             }
             
             [rs close];
         }];
    }
}


// 公共题干
- (void)sameCutTitle2
{
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
        
        NSString  *path=[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@type=1",name] ofType:@"plist"];
        NSArray *array = [NSArray arrayWithContentsOfFile:path];

//        // 先校验数据正确性
//        for (NSString *content in array)
//        {
//            NSArray *contentArray = [content componentsSeparatedByString:@","];
//            NSInteger start = [[contentArray objectAtIndex:2] integerValue];
//            NSInteger end = [contentArray.lastObject integerValue];
//
//            NSInteger sub = 0;
//            for (int i = 3; i< contentArray.count - 1; i++)
//            {
//                sub += [[contentArray objectAtIndex:i] integerValue];
//            }
//
//            if (start + sub == end + 1)
//            {
//                NSLog(@"数据正确");
//            }
//            else
//            {
//                NSLog(@"!!!!数据错误：%@",content);
//            }
//        }
//
//        return;
        
        
        NSString *filePath = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db",name]];
        NSLog(@"db:%@ path:%@",name,documentsPath);
        self.sqlDb = nil;
        self.sqlDb = [FMDatabaseQueue databaseQueueWithPath:filePath];
        
        [_sqlDb inDatabase:^(FMDatabase *db) {
            
            // 打印title校验
//            for (NSString *content in array)
//            {
//                NSArray *contentArray = [content componentsSeparatedByString:@","];
//                
//                
//                int start = [[contentArray objectAtIndex:2] intValue];
//                
//                for (int i = 3; i< contentArray.count - 1; i++)
//                {
//                    int question_count = [[contentArray objectAtIndex:i] intValue];
//                    
//                    if (question_count > 1)
//                    {
//                        NSString *sql = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year = '%@' and unit = '%@' and NUMBER_NUMBER between %d and %d order by NUMBER_NUMBER",contentArray[0],contentArray[1],start,start+question_count-1];
//                        
//                        FMResultSet *rs =  [db executeQuery:sql];
//                        
//                        while (rs.next)
//                        {
//                            NSString *question_title = [rs stringForColumn:@"title"];
//                            if (question_title.length > 55) {
//                                question_title = [question_title substringToIndex:55];
//                            }
//                            NSLog(@"%@_%@_%d_%d: %@",contentArray[0],contentArray[1],[rs intForColumn:@"NUMBER_NUMBER"],[rs intForColumn:@"question_id"],question_title);
//                        }
//                        
//                        [rs close];
//
//                    }
//                    else
//                    {
//                        
//                    }
//                    
//                    start += question_count;
//                    
//                    NSLog(@"---------------------------------------------------------------------------------------------------------");
//                }
//                
//                NSLog(@"========================================================================================================");
//            }
            
            // 二位数组记录结果
            NSMutableArray *bigArray = [NSMutableArray array];

            for (NSString *content in array)
            {
                NSArray *contentArray = [content componentsSeparatedByString:@","];
                
                int start = [[contentArray objectAtIndex:2] intValue];
                
                for (int i = 3; i< contentArray.count - 1; i++)
                {
                    NSMutableArray *smallArray = [NSMutableArray array];

                    int question_count = [[contentArray objectAtIndex:i] intValue];
                    
                    if (question_count > 1)
                    {
                        NSString *sql = [NSString stringWithFormat:@"select * from QUESTION_INFO_BEAN where year = '%@' and unit = '%@' and NUMBER_NUMBER between %d and %d order by NUMBER_NUMBER",contentArray[0],contentArray[1],start,start+question_count-1];
                        
                        FMResultSet *rs =  [db executeQuery:sql];
                        while (rs.next)
                        {
                            [smallArray addObject:[rs stringForColumn:@"question_id"]];
                        }
                        
                        [rs close];
                        [bigArray addObject:smallArray];
                    }
                    else
                    {
                        // 只有一条数据的略过
                        NSLog(@"只有一条数据");
                    }
                    
                    start += question_count;
                }
            }

//            NSInteger number = 0;
//            for (NSArray *arr in bigArray)
//            {
//                if (arr.count > 5) {
//                    NSLog(@"%@",arr);
//                }
//                number += arr.count;
//            }
//            NSLog(@"%ld,%@",number,bigArray);

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
                        [firstStr appendFormat:@"%@,",number];

                        if (index > 0)
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
                
                if (firstStr.length)
                {
                    firstStr = [firstStr substringToIndex:firstStr.length-1];
                    NSString *typeStr = [NSString stringWithFormat:@"update QUESTION_INFO_BEAN set TYPE = 1 where QUESTION_ID in (%@)",firstStr];
                    BOOL ssss = [db executeUpdate:typeStr];
                    if (ssss) {
                        NSLog(@"set success");
                    }
                    
                    
                    NSString *deleteStr = [NSString stringWithFormat:@"delete from QUESTION where QUESTION_ID  in (%@)",lastStr];
                    NSString *resultStr = [NSString stringWithFormat:@"%@\n\n\n\n\n\n%@\n\n\n\n\n%@",typeStr, deleteStr, updateListStr];
                    NSFileManager *fm = [NSFileManager defaultManager];
                    NSString* _filename = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"type_1_%@.txt",name]];
                    //创建目录
                    [fm createFileAtPath:_filename contents:[resultStr dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
                }
            }
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
            
            FMResultSet *rs =  [db executeQuery:@"select COMBINE_ANSWER from QUESTION_INFO_BEAN where type=0 group by COMBINE_ANSWER having count(*) >1"];
            
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


- (BOOL)isSimilarStr:(NSString *)first  Second:(NSString *)second
{
    if (first.length < 36 || second.length < 36)
    {
        return NO;
    }
    
    if (first.length > 150)
    {
        first = [first substringToIndex:150];
    }
    
    if (second.length > 150)
    {
        second = [second substringToIndex:150];
    }

    // 允许5个不同字
    static NSInteger segmentationCount = 16;
    
    if ([first isEqualToString:second] ||
        [first containsString:second] ||
        [second containsString:first])
    {
        return YES;
    }
    
    if (first.length > second.length)
    {
        first = [first substringToIndex:second.length];
    }
    else if (second.length > first.length)
    {
        second = [second substringToIndex:first.length];
    }
    
    NSInteger differentCount  = 0;
    NSInteger firstCount = [first length];
    NSInteger secondCount = [second length ];
    NSInteger  count = labs(firstCount - secondCount);
    
    
    if (count < segmentationCount) {
        for (NSInteger i = 0 ; i < first.length; i++) {
            NSString *temp  = [first substringWithRange:NSMakeRange( i, 1)] ;
            if (![second containsString:temp]) {
                differentCount++;
            }
        }
        if (differentCount <= segmentationCount) {
            
            return true;
        }
        
    }
    
    return false;
    
}

@end
