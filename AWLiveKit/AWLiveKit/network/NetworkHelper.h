//
//  NetworkHelper.h
//  wxlive
//
//  Created by 秦 道平 on 16/9/30.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

#ifndef NetworkHelper_h
#define NetworkHelper_h

#import <Foundation/Foundation.h>

@interface NetworkHelper : NSObject
+(NSString* _Nullable) currentSSID;
+(NSString* _Nullable)signalStrength;
@end
#endif /* NetworkHelper_h */
