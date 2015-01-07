//
//  EimNotificationCenter+Asyn.h
//  EimNotificationCenter
//
//  Created by Jason Qian on 12/30/14.
//  Copyright (c) 2014 Jason Qian. All rights reserved.
//

#import "EimNotificationCenter.h"

#define DISPATCH_QUEUE_PRIORITY_HIGH 2
#define DISPATCH_QUEUE_PRIORITY_DEFAULT 0
#define DISPATCH_QUEUE_PRIORITY_LOW (-2)

typedef enum EimNotificationAsynPriorityEnum: NSInteger {
    kEimNotificationAsynPriorityNone    = -9,
    kEimNotificationAsynPriorityLow     = -2,
    kEimNotificationAsynPriorityDefault = 0,
    kEimNotificationAsynPriorityHigh    = 2,
}EimNotificationAsynPriority;

@interface EimNotificationAsyn : EimNotification
@property (nonatomic, assign, readonly) EimNotificationAsynPriority priority;
@end

@interface EimNotificationCenter(EIMNotificationCenterAsynPost)

//PostAsyn
- (void)postAsynNotification:(EimNotification *)notificationName;

- (void)postAsynNotificationName:(NSString *)notificationName
                          object:(id)notificationSender;

- (void)postAsynNotificationName:(NSString *)notificationName
                          object:(id)notificationSender
                        userInfo:(NSDictionary *)userInfo;

- (void)postAsynNotificationName:(NSString *)notificationName
                          object:(id)notificationSender
                        userInfo:(NSDictionary *)userInfo
                        priority:(EimNotificationAsynPriority)priority;

//AsynQueue PostImmediately
- (void)rushAsynNotificationQueue;
@end
