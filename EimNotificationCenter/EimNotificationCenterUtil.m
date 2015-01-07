//
//  EimNotificationCenterUtil.m
//  EIMNotificationCenterDemo
//
//  Created by Jason Qian on 1/5/15.
//  Copyright (c) 2015 Jason Qian. All rights reserved.
//

#import "EimNotificationCenterUtil.h"
#include <sys/sysctl.h>

@interface EimNotificationBlockTask : NSObject
@property (nonatomic, copy) dispatch_block_t block;
@end

@implementation EimNotificationBlockTask
- (instancetype)init
{
    self = [super init];
    if (self) {
        _block = NULL;
    }
    return self;
}

- (void)dealloc {
    
    if (_block) {
        Block_release(_block);
        _block= nil;
    }
    
    [super dealloc];
}

- (void)execute
{
    if (self.block != NULL) {
        self.block();
        self.block = nil;
    }
}
@end

EimDeviceType g_deviceType = EimDeviceNone;
@implementation EimNotificationCenterUtil

#pragma mark -
#pragma mark Device
+ (BOOL)isHighPerformanceDevice
{
    switch ([[self class] deviceModelID]) {
        case EimDeviceiPhone1G:
        case EimDeviceiPhone3G:
        case EimDeviceiPhone3GS:
        case EimDeviceiPhone4:
        case EimDeviceiPhone4S:
        case EimDeviceiPodTouch1G:
        case EimDeviceiPodTouch2G:
        case EimDeviceiPodTouch3G:
        case EimDeviceiPodTouch4G:
        case EimDeviceiPad1:
        case EimDeviceiPad2:
            return NO;
        default:
            return YES;
    }
}

+ (NSString *)platform
{
    //machine
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    
    //platform
    NSString *strPlatform    = nil;
    if (machine == NULL) {
        strPlatform = @"i386";
    } else {
        strPlatform = [NSString stringWithUTF8String:machine];
    }
    free(machine);
    
    return strPlatform;
}

//
//device info from
//http://www.everyi.com/by-identifier/ipod-iphone-ipad-specs-by-model-identifier.html
//
+ (EimDeviceType)deviceModelID
{
    if (g_deviceType > EimDeviceNone) {
        return g_deviceType;
    }
    
    NSString *platform = [[self class] platform];
    
    //iPhones
    if ([platform isEqualToString:@"iPhone1,1"])            g_deviceType = EimDeviceiPhone1G;
    if ([platform rangeOfString:@"iPhone1,2"].length > 0)   g_deviceType = EimDeviceiPhone3G;
    if ([platform rangeOfString:@"iPhone2,1"].length > 0)   g_deviceType = EimDeviceiPhone3GS;
    if ([platform isEqualToString:@"iPhone3,1"])            g_deviceType = EimDeviceiPhone4;
    if ([platform isEqualToString:@"iPhone3,3"])            g_deviceType = EimDeviceiPhone4;
    if ([platform rangeOfString:@"iPhone4,1"].length > 0)   g_deviceType = EimDeviceiPhone4S;
    if ([platform isEqualToString:@"iPhone5,1"])            g_deviceType = EimDeviceiPhone5;
    if ([platform isEqualToString:@"iPhone5,2"])            g_deviceType = EimDeviceiPhone5;
    if ([platform isEqualToString:@"iPhone5,3"])            g_deviceType = EimDeviceiPhone5c;
    if ([platform isEqualToString:@"iPhone5,4"])            g_deviceType = EimDeviceiPhone5c;
    if ([platform isEqualToString:@"iPhone6,1"])            g_deviceType = EimDeviceiPhone5s;
    if ([platform isEqualToString:@"iPhone6,2"])            g_deviceType = EimDeviceiPhone5s;
    if ([platform rangeOfString:@"iPhone7,1"].length > 0)   g_deviceType = EimDeviceiPhone6p;
    if ([platform rangeOfString:@"iPhone7,2"].length > 0)   g_deviceType = EimDeviceiPhone6;
   
    //iPods
    if ([platform isEqualToString:@"iPod1,1"])              g_deviceType = EimDeviceiPodTouch1G;
    if ([platform isEqualToString:@"iPod2,1"])              g_deviceType = EimDeviceiPodTouch2G;
    if ([platform isEqualToString:@"iPod3,1"])              g_deviceType = EimDeviceiPodTouch3G;
    if ([platform isEqualToString:@"iPod4,1"])              g_deviceType = EimDeviceiPodTouch4G;
    if ([platform isEqualToString:@"iPod5,1"])              g_deviceType = EimDeviceiPodTouch5G;
    
    //iPads
    if ([platform isEqualToString:@"iPad1,1"])              g_deviceType = EimDeviceiPad1;
    if ([platform isEqualToString:@"iPad2,1"])              g_deviceType = EimDeviceiPad2;
    if ([platform isEqualToString:@"iPad2,2"])              g_deviceType = EimDeviceiPad2;
    if ([platform isEqualToString:@"iPad2,3"])              g_deviceType = EimDeviceiPad2;
    if ([platform isEqualToString:@"iPad2,4"])              g_deviceType = EimDeviceiPad2;
    if ([platform isEqualToString:@"iPad2,5"])              g_deviceType = EimDeviceiPadMini;
    if ([platform isEqualToString:@"iPad2,6"])              g_deviceType = EimDeviceiPadMini;
    if ([platform isEqualToString:@"iPad2,7"])              g_deviceType = EimDeviceiPadMini;
    if ([platform isEqualToString:@"iPad3,1"])              g_deviceType = EimDeviceiPad3;
    if ([platform isEqualToString:@"iPad3,2"])              g_deviceType = EimDeviceiPad3;
    if ([platform isEqualToString:@"iPad3,3"])              g_deviceType = EimDeviceiPad3;
    if ([platform isEqualToString:@"iPad3,4"])              g_deviceType = EimDeviceiPad4;
    if ([platform isEqualToString:@"iPad3,5"])              g_deviceType = EimDeviceiPad4;
    if ([platform isEqualToString:@"iPad3,6"])              g_deviceType = EimDeviceiPad4;
    if ([platform isEqualToString:@"iPad4,1"])              g_deviceType = EimDeviceiPadAir;
    if ([platform isEqualToString:@"iPad4,2"])              g_deviceType = EimDeviceiPadAir;
    if ([platform isEqualToString:@"iPad4,3"])              g_deviceType = EimDeviceiPadAir;
    if ([platform isEqualToString:@"iPad4,4"])              g_deviceType = EimDeviceiPadMini2;
    if ([platform isEqualToString:@"iPad4,5"])              g_deviceType = EimDeviceiPadMini2;
    if ([platform isEqualToString:@"iPad4,6"])              g_deviceType = EimDeviceiPadMini2;
    if ([platform isEqualToString:@"iPad4,7"])              g_deviceType = EimDeviceiPadMini3;
    if ([platform isEqualToString:@"iPad4,8"])              g_deviceType = EimDeviceiPadMini3;
    if ([platform isEqualToString:@"iPad4,9"])              g_deviceType = EimDeviceiPadMini3;
    if ([platform isEqualToString:@"iPad5,3"])              g_deviceType = EimDeviceiPadAir2;
    if ([platform isEqualToString:@"iPad5,4"])              g_deviceType = EimDeviceiPadAir2;
    
    //Simulators
    if ([platform isEqualToString:@"i386"])                 g_deviceType = EimDeviceSimulator32;
    if ([platform isEqualToString:@"x86_64"])               g_deviceType = EimDeviceSimulator64;
    
    return g_deviceType;
}

#pragma mark -
#pragma mark MainThread
+ (void)performOnMainThread:(id)aTarget
               withSelector:(SEL)aSelector
                 withObject:(id)arg
              waitUntilDone:(BOOL)wait
{
    if (!aTarget) {
        return;
    }
    
    //we use 'NSDefaultRunLoopMode' instead of 'kCFRunLoopCommonModes' to lower the priority of runLoop,
    //which can enhancement the performance for UI tracking.
    [aTarget performSelectorOnMainThread:aSelector
                              withObject:arg
                           waitUntilDone:wait
                                   modes:@[NSDefaultRunLoopMode]];
}

+ (void)dispatchOnMainThread:(dispatch_block_t)aBlock
{
    EimNotificationBlockTask *blockTask = [[[EimNotificationBlockTask alloc] init] autorelease];
    blockTask.block = aBlock;
    
    [[self class] performOnMainThread:blockTask withSelector:@selector(execute)
                           withObject:nil waitUntilDone:NO];

}

@end
