//
//  AppDelegate.m
//  SQLBuilder
//
//  Created by  on 2016/12/14.
//  Copyright © 2016年 xywyxywy. All rights reserved.
//

#import "AppDelegate.h"

#import "publicTitle.h"
#import "PublicAnswers.h"
#import "otherMethod.h"

@interface AppDelegate ()
{
    int offCount;
}
@property(nonatomic , strong) FMDatabaseQueue * sqlDb;

@end



@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    
    
//    self.DBNameArray = @[
////                         @"护士执业考试.db",
//                         @"口腔执业医师.db",
//                         @"临床执业医师.db",
//                         @"临床执业助理医师考试.db",
//                         @"西药执业药师.db",
//                         @"中西医结合执业助理医师考试.db",
//                         @"中药执业药师.db",
//                         @"中医执业医师考试.db"
//                         ];

    self.DBNameArray = @[
                         @"HSZYKAOSHI.db",
                         @"KQZYYISHI.db",
                         @"LCZYYISHI.db",
                         @"LCZYZLYISHI.db",
                         @"XYZYYAOSHI.db",
                         @"ZXYJHZYZLYISHI.db",
                         @"ZYZYYAOSHI.db",
                         @"ZYZYYISHI.db"
                         ];
    

    //    [otherMethod getAndUpdateAnswerText];
//
//    [otherMethod deleteRepeatData];
//    
//    [otherMethod multiChoice];
//    
//    [otherMethod updateNumber_number];
//
//    [otherMethod encryptionDate];
//
//    [publicTitle publicTitleSearch];
    
//    [PublicAnswers publicAnswerSearch];
    
//    [otherMethod printText];
    
    [otherMethod diffCategory];

    NSLog(@"================== END ==================");
    return YES;
}

@end
