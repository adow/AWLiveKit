//
//  aw_audio_encoder.h
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/2/19.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

#ifndef aw_audio_encoder_h
#define aw_audio_encoder_h

#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolBox/AudioToolBox.h>
#include <CoreMedia/CoreMedia.h>

int aw_audio_encode_samplebuffer(CMSampleBufferRef sampleBuffer);
AudioBufferList *aw_audio_encode(CMSampleBufferRef sample_buffer);
void aw_audio_release(AudioBufferList *buffer_list);
#endif /* aw_audio_encoder_h */
