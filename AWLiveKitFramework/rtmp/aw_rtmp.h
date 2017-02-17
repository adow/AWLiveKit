//
//  aw_rtmp.h
//  TestLivePush2
//
//  Created by 秦 道平 on 16/7/1.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

#ifndef aw_rtmp_h
#define aw_rtmp_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rtmp.h"

int aw_rtmp_connection(const char *url);
void aw_rtmp_close();
int aw_rtmp_send_sps_pps(unsigned char *sps, int sps_length,
                         unsigned char *pps, int pps_length);
int aw_rtmp_send_h264_video(unsigned char *data,
                            unsigned int size,
                            int bIsKeyFrame, unsigned int nTimeStamp);
int aw_rtmp_send_audio_header();
int aw_rtmp_send_audio(unsigned char *data, 
		unsigned int size,
		unsigned int nTimeStamp);
#endif /* aw_rtmp_h */
