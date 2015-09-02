//
//  EimNotificationCenterUtil.h
//  EIMNotificationCenterDemo
//
//  Created by Jason Qian on 1/5/15.
//  Copyright (c) 2015 Jason Qian. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum EimDeviceTypeEnum: NSUInteger {
    EimDeviceNone               = 0,
    EimDeviceSimulator,
    EimDeviceSimulator32,
    EimDeviceSimulator64,
    
    EimDeviceiPhone1G           = 100,
    EimDeviceiPhone3G,
    EimDeviceiPhone3GS,
    EimDeviceiPhone4,
    EimDeviceiPhone4S,
    EimDeviceiPhone5,
    EimDeviceiPhone5c,
    EimDeviceiPhone5s,
    EimDeviceiPhone6p,
    EimDeviceiPhone6,
    
    EimDeviceiPodTouch1G        = 200,
    EimDeviceiPodTouch2G,
    EimDeviceiPodTouch3G,
    EimDeviceiPodTouch4G,
    EimDeviceiPodTouch5G,
    
    EimDeviceiPad1              = 300,
    EimDeviceiPad2,
    EimDeviceiPad3,
    EimDeviceiPad4,
    EimDeviceiPadAir,
    EimDeviceiPadAir2,
    EimDeviceiPadMini,
    EimDeviceiPadMini2,
    EimDeviceiPadMini3
}EimDeviceType;

@interface EimNotificationCenterUtil : NSObject

//device
+ (EimDeviceType)deviceModelID;
+ (BOOL)isHighPerformanceDevice;

//mainThread exec
+ (void)performOnMainThread:(id)aTarget
               withSelector:(SEL)aSelector
                 withObject:(id)arg
              waitUntilDone:(BOOL)wait;

+ (void)dispatchOnMainThread:(dispatch_block_t)aBlock;

//thread
+ (__uint64_t)currentThreadID;
@end
