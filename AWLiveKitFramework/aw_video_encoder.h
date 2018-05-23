//
//  aw_video_encoder.h
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/12.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

#ifndef aw_video_encoder_h
#define aw_video_encoder_h

#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolBox/AudioToolBox.h>
#include <VideoToolBox/VideoToolBox.h>
#include <CoreMedia/CoreMedia.h>

typedef void (*AWVideoEncoderCallback)( CM_NULLABLE CMSampleBufferRef sampleBuffer, void * _Nullable callback_context );

int aw_video_encoder_init(int width, int height, int bitrate, int fps, CFStringRef _Nullable profile);
void aw_video_encoder_close(void);

int aw_video_encode_samplebuffer(CMSampleBufferRef _Nullable sample_buffer,
    AWVideoEncoderCallback _Nullable callback,
    void * _Nullable callback_context);
int aw_video_encode_pixelbuffer(CVPixelBufferRef _Nullable pixel_buffer,
    CMTime presentation_time,
    CMTime duration,
    AWVideoEncoderCallback _Nullable callback,
    void * _Nullable callback_context);
#endif /* aw_video_encoder_h */
