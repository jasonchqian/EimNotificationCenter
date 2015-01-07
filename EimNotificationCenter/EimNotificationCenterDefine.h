//
//  EimNotificationCenterDefine.h
//  EIMNotificationCenterDemo
//
//  Created by Jason Qian on 12/30/14.
//  Copyright (c) 2014 Jason Qian. All rights reserved.
//

#ifndef EIMNotificationCenterDemo_EimNotificationCenterDefine_h
#define EIMNotificationCenterDemo_EimNotificationCenterDefine_h

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#define EIMNOTIFICATIONCENTER_METHOD_TRACE 0

#ifndef _RELEASE
#define _RELEASE( x ) if( nil != (x)){ [(x) release] ; (x) = nil ; }
#endif

#if DEBUG
#define eimLog(fmt, ...) \
NSLog((@"<method:%s><line %d> " fmt), __FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define eimLog(...);
#endif

#if EIMNOTIFICATIONCENTER_METHOD_TRACE
#define eimMethod          \
NSLog(@"[%@]:%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd))
#else
#define eimMethod
#endif

#endif
