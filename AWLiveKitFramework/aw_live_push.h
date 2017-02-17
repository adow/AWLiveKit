//
//  aw_live_push.h
//  AWLiveKit
//
//  Created by 秦 道平 on 2016/12/29.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

#ifndef aw_live_push_h
#define aw_live_push_h

#include <stdio.h>
#include <VideoToolBox/VideoToolBox.h>

int aw_push_video_samplebuffer(CMSampleBufferRef sample_buffer,
                               double start_time,
                               int *is_spspps_sent);
int aw_push_audio_bufferlist(AudioBufferList buffer_list,
                             double time_offset);
#endif /* aw_live_push_h */
