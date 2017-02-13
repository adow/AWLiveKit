//
//  NetworkHelper.m
//  wxlive
//
//  Created by 秦 道平 on 16/9/30.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NetworkHelper.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <UIKit/UIKit.h>

@implementation NetworkHelper

+( NSString* _Nullable ) currentSSID {
    // Does not work on the simulator.
    NSString *ssid = nil;
    NSArray *ifs = (id)CFBridgingRelease(CNCopySupportedInterfaces());
    NSLog(@"ifs:%@",ifs);
    for (NSString *ifnam in ifs) {
        NSDictionary *info = (id)CFBridgingRelease(CNCopyCurrentNetworkInfo((CFStringRef)ifnam));
        NSLog(@"dict：%@",[info  allKeys]);
        if (info[@"SSID"]) {
            ssid = info[@"SSID"];
            
        }
    }
    return ssid;
}
+(NSString*)signalStrength {
    UIApplication *app = [UIApplication sharedApplication];
    NSArray *subviews = [[[app valueForKey:@"statusBar"]     valueForKey:@"foregroundView"] subviews];
    int signalStrength = 0,wifiStrengthBars = 0;
    for (id subview in subviews) {
        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]])
        {
            wifiStrengthBars = [[subview valueForKey:@"wifiStrengthBars"] intValue];
        }
        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarSignalStrengthItemView") class]])
        {
            signalStrength = [[subview valueForKey:@"signalStrengthRaw"] intValue];
        }
    }
//    NSLog(@"signal %d,%d", signalStrength,wifiStrengthBars);
    return [NSString stringWithFormat:@"%d/%d",signalStrength, wifiStrengthBars];
}
@end
