//
//  EimNotificationCenter+Asyn.m
//  EIMNotificationCenterDemo
//
//  Created by Jason Qian on 12/30/14.
//  Copyright (c) 2014 Jason Qian. All rights reserved.
//

#import "EimNotificationCenter+Asyn.h"
#import "EimNotificationCenterUtil.h"

@implementation EimNotificationAsyn

+ (instancetype)notificationWithName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
                            priority:(EimNotificationAsynPriority)aPriority
{
    return [[[EimNotificationAsyn alloc] initWithName:aName object:anObject
                                         userInfo:aUserInfo priority:aPriority] autorelease];
}

- (instancetype)initWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo
                    priority:(EimNotificationAsynPriority)aPriority
{
    self = [super initWithName:name object:object userInfo:userInfo];
    if (self) {
        _priority = aPriority;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    //not neccessary to consider priority as the item for comparision.
    return [super isEqual:object];
}

- (NSString *)description
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return [NSString stringWithFormat:
            @"EimNotification: [%"PRIuPTR"]\n<Name: %@>\n<Sender: %"PRIuPTR">\n<UserInfo: %@>\n<Priority: %@>",
            (uintptr_t)self,
            (self.name ?: @"null"),
            ((self.object != nil) ? (uintptr_t)self.object: 0),
            (self.userInfo ?: @"null"),
            [[self class] priorityString:self.priority]
            ];
#pragma clang diagnostic pop
}

+ (NSString *)priorityString:(EimNotificationAsynPriority)aPriority
{
    switch (aPriority) {
        case kEimNotificationAsynPriorityNone:
            return @"PriorityNone";
        case kEimNotificationAsynPriorityLow:
            return @"PriorityLow";
        case kEimNotificationAsynPriorityDefault:
            return @"PriorityDefault";
        case kEimNotificationAsynPriorityHigh:
            return @"PriorityHigh";
        default:
            return @"PriorityUnknow";
    }
}

@end

void PostEimNotificationAsyn(EimNotificationCenter *eimNotificationCenter);
void EimNotificationLoopObserverCallBack(CFRunLoopObserverRef observer,
                                         CFRunLoopActivity activity,
                                         void *info);

@implementation EimNotificationCenter (EIMNotificationCenterAsynPost)
- (void)postAsynNotification:(EimNotification *)notificationName
{
    eimMethod;
    [self postAsynNotificationName:notificationName.name
                            object:notificationName.object
                          userInfo:notificationName.userInfo];
}

- (void)postAsynNotificationName:(NSString *)notificationName
                          object:(id)notificationSender
{
    eimMethod;
    [self postAsynNotificationName:notificationName
                            object:notificationSender
                          userInfo:nil];
}

- (void)postAsynNotificationName:(NSString *)notificationName
                          object:(id)notificationSender
                        userInfo:(NSDictionary *)userInfo
{
    eimMethod;
    [self postAsynNotificationName:notificationName
                            object:notificationSender
                          userInfo:nil
                          priority:kEimNotificationAsynPriorityNone];
}

- (void)postAsynNotificationName:(NSString *)notificationName
                          object:(id)notificationSender
                        userInfo:(NSDictionary *)userInfo
                        priority:(EimNotificationAsynPriority)priority
{
    eimMethod;
    
    if (!notificationName) {
        return;
    }
    
    EimNotificationAsyn *asynNotification = [EimNotificationAsyn notificationWithName:notificationName
                                                                               object:notificationSender
                                                                             userInfo:userInfo
                                                                             priority:priority];
    if (!asynNotification) {
        return;
    }
    
    //
//    dispatch_async(dispatch_get_main_queue(),
//                   ^{
//                       [self ensureObserverInMainLoop];
//                       [self addNotification:asynNotification];
//                   });
    [EimNotificationCenterUtil dispatchOnMainThread:^{
        [self ensureObserverInMainLoop];
        [self addNotification:asynNotification];
    }];
}

//rush all notification in queue
- (void)rushAsynNotificationQueue
{
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self rushAsynNotificationQueue];
        });
        
        return;
    }
    
    //rush all notification in queue
    while ([self asnyNotificationRemain]) {
        PostEimNotificationAsyn(self);
    }
}

#pragma mark -
#pragma mark Util
- (void)ensureObserverInMainLoop
{
    if (![NSThread isMainThread]) {
        [EimNotificationCenterUtil dispatchOnMainThread:^{
            [self ensureObserverInMainLoop];
        }];
        
        return;
    }
    
    static  dispatch_once_t           onceObserverCreate  = 0;
    dispatch_once(&onceObserverCreate,
    ^{
        CFRunLoopObserverContext    context =
        {
            0,    // Version of this structure. Must be zero.
            self, // Info pointer: a reference to this UpdateTimer.
            NULL, // Retain callback for info pointer.
            NULL, // Release callback for info pointer.
            NULL  // Copy description.
        };
        
        CFRunLoopObserverRef    observer            = NULL;
        CFOptionFlags           runLoopActivities   = kCFRunLoopAllActivities;
        if ([EimNotificationCenterUtil isHighPerformanceDevice]) {
            runLoopActivities = kCFRunLoopAllActivities;
        } else {
            //observer invoked only in "kCFRunLoopBeforeWaiting" on those older devices.
            //[Good]
            //Enhancement on the performance.
            //[Bad]
            //Lower Efficiency for asyn-post queue.
            runLoopActivities = kCFRunLoopBeforeWaiting;
        }
        
        observer = CFRunLoopObserverCreate(kCFAllocatorDefault, runLoopActivities,
                                           YES, 0, &EimNotificationLoopObserverCallBack, &context);
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    });
}

- (BOOL)addNotification:(id)aAsynNotification
{
    //thread check
    if (![NSThread isMainThread]) {
        [EimNotificationCenterUtil dispatchOnMainThread:^{
            [self addNotification:aAsynNotification];
        }];
        
        return NO;
    }
    
    //param check
    if (!aAsynNotification || ![aAsynNotification isKindOfClass:[EimNotificationAsyn class]]
        || !_asynNotificationQueue || ![_asynNotificationQueue isKindOfClass:[NSMutableArray class]]) {
        eimLog(@"param error");
        return NO;
    }
    
    BOOL      bNeedInsert   = NO;
    NSInteger nLoopIndex    = 0;
    for (id currentNotification in _asynNotificationQueue)
    {
        if (![currentNotification isKindOfClass:[EimNotificationAsyn class]]) {
            nLoopIndex++;
            continue;
        }
        
        if ([currentNotification isEqual:aAsynNotification]) {
            eimLog(@"duplication element");
            return YES;
        }
        
        EimNotificationAsynPriority priorCurrent = ((EimNotificationAsyn *)currentNotification).priority;
        EimNotificationAsynPriority priorNew     = ((EimNotificationAsyn *)aAsynNotification).priority;
        if (priorNew == kEimNotificationAsynPriorityNone) {
            //can't stop and execute add operation.
            //need continue to loop for checking duplication.
            nLoopIndex++;
            continue;
        }
        
        //need to insert
        if (priorCurrent == kEimNotificationAsynPriorityNone) {
            bNeedInsert = YES;
            break;
        }
        
        //need to insert
        if (priorNew > priorCurrent) {
            bNeedInsert = YES;
            break;
        }
        
        nLoopIndex++;
    }
    
    //
    //Insert
    if (bNeedInsert)
    {
        if (nLoopIndex > ((NSMutableArray *)_asynNotificationQueue).count) {
            nLoopIndex = ((NSMutableArray *)_asynNotificationQueue).count;
        }
        
        @try {
            [_asynNotificationQueue insertObject:aAsynNotification
                                         atIndex:nLoopIndex];
        }
        @catch (NSException *exception) {
            if (_asynNotificationQueue && [_asynNotificationQueue isKindOfClass:[NSArray class]]) {
                eimLog(@"insert priority item invalid, queueCnt:[%lu], insertIndex:[%ld]",
                       (unsigned long)((NSArray *)_asynNotificationQueue).count, (long)nLoopIndex);
            }
            else {
                eimLog(@"insert priority item invalid, queue empty");
            }
            return NO;
        }
        
        return YES;
    }
    
    //
    //Add
    [_asynNotificationQueue addObject:aAsynNotification];
    return YES;
}


- (id)takeAnAsynNotificationObj
{
    if (!_asynNotificationQueue || ![_asynNotificationQueue isKindOfClass:[NSMutableArray class]]) {
        return nil;
    }
    
    
    @synchronized(self)
    {
        NSMutableArray *notifications = (NSMutableArray *)_asynNotificationQueue;
        if (notifications.count == 0) {
            return nil;
        }
        
        id EimNotificationObj = [notifications[0] retain];
        [notifications removeObjectAtIndex:0];
    
        return [EimNotificationObj autorelease];
    }
}

- (BOOL)asnyNotificationRemain
{
    if (!_asynNotificationQueue || ![_asynNotificationQueue isKindOfClass:[NSArray class]]) {
        return NO;
    }
    
    @synchronized(self) {
        return (((NSArray *)_asynNotificationQueue).count > 0 );
    }
}

@end
    
    
void PostEimNotificationAsyn(EimNotificationCenter *eimNotificationCenter)
{
    if (!eimNotificationCenter || ![eimNotificationCenter isKindOfClass:[EimNotificationCenter class]]) {
        return;
    }
    
    EimNotificationAsyn *aNotification = [eimNotificationCenter takeAnAsynNotificationObj];
    if (aNotification) {
        [[EimNotificationCenter defaultCenter] postNotification:aNotification];
    }
}

void EimNotificationLoopObserverCallBack(CFRunLoopObserverRef observer,
                                         CFRunLoopActivity activity,
                                         void *info)
{
    if (!info) {
        return;
    }
    
    @autoreleasepool {
        EimNotificationCenter *notificationCenter = (EimNotificationCenter *)info;
        PostEimNotificationAsyn(notificationCenter);
    }
}
