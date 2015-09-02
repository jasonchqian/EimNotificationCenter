//
//  EimNotificationCenter.h
//  EimNotificationCenter
//
//  Created by Jason Qian on 12/1/14.
//
//

#import "EimNotificationCenterDefine.h"

double EimMachTimeToSecond(uint64_t time);

#pragma mark -
#pragma mark EimNotification
@interface EimNotification : NSObject
@property (nonatomic, readonly, copy)   NSString *name;
@property (nonatomic, readonly, retain) id object;
@property (nonatomic, readonly, copy)   NSDictionary *userInfo;

- (instancetype)initWithName:(NSString *)name
                      object:(id)object
                    userInfo:(NSDictionary *)userInfo NS_DESIGNATED_INITIALIZER;
@end

#pragma mark ▇▇ Category: EimNotificationCreation
@interface EimNotification (EimNotificationCreation)
+ (instancetype)notificationWithName:(NSString *)aName
                              object:(id)anObject
                            userInfo:(NSDictionary *)aUserInfo;
@end

#pragma mark -
#pragma mark EimNotificationCenter
@interface EimNotificationCenter : NSObject
{
    @package
    id _asynNotificationQueue;
}

//singleton generator
+ (EimNotificationCenter *)defaultCenter;
- (void)reset;

//
//add
- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector
               name:(NSString *)notificationName
             object:(id)notificationSender;
- (id<NSObject>)addObserverForName:(NSString *)notificationName
                            object:(id)notificationSender
                        usingBlock:(void (^)(EimNotification *note))block;

- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector
               name:(NSString *)notificationName
             object:(id)notificationSender
  forceOnMainthread:(BOOL)bOnMainThread;

- (id<NSObject>)addObserverForName:(NSString *)notificationName
                            object:(id)notificationSender
                        usingBlock:(void (^)(EimNotification *note))block
                 forceOnMainthread:(BOOL)bOnMainThread;

//
//remove
- (void)removeObserver:(id)notificationObserver;

- (void)removeObserver:(id)notificationObserver
                  name:(NSString *)notificationName
                object:(id)notificationSender;

//
//post sync
- (void)postNotification:(EimNotification *)notificationName;

- (void)postNotificationName:(NSString *)notificationName
                      object:(id)notificationSender;

- (void)postNotificationName:(NSString *)notificationName
                      object:(id)notificationSender
                    userInfo:(NSDictionary *)userInfo;
@end
