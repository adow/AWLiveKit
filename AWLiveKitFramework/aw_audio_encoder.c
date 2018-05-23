//
//  aw_audio_encoder.c
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/2/19.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

#include "aw_audio_encoder.h"

#define output_audio_channels 2 /// stereo
#define output_audio_sample_rate 44100
AudioConverterRef _audioConverter;
AudioStreamBasicDescription _input_format;

int aw_audio_encoder_setup() {
    if (_audioConverter != NULL) {
        return 0;
    }
    /// output_format
    AudioStreamBasicDescription output_format;
    output_format.mSampleRate = output_audio_sample_rate;
    output_format.mFormatID = kAudioFormatMPEG4AAC;
    output_format.mFormatFlags = kMPEG4Object_AAC_LC;
    output_format.mChannelsPerFrame = output_audio_channels; /// 输出 stero
    output_format.mBytesPerPacket = 0;
    output_format.mBytesPerFrame = 0;
    output_format.mBitsPerChannel = 0;
    output_format.mFramesPerPacket = 1024;
    output_format.mReserved = 0;
    /// audio class
    AudioClassDescription class_1 = {
        kAudioEncoderComponentType,
        kAudioFormatMPEG4AAC,
        kAppleHardwareAudioCodecManufacturer,
    };
    AudioClassDescription class_2 = {
        kAudioEncoderComponentType,
        kAudioFormatMPEG4AAC,
        kAppleSoftwareAudioCodecManufacturer,
    };
    AudioClassDescription class_list[] = {
        class_2,
        class_1,
    };
    /// audio converter
    int ret = AudioConverterNewSpecific(
                &_input_format,
                &output_format,
                2,
                class_list,
                &_audioConverter);
    if (ret == noErr) {
        printf("setup audio encoder ok\n");
        /// BitRate
//        UInt32 outputBitrate = 96000;
        UInt32 outputBitrate = 128000;
        UInt32 propSize = sizeof(outputBitrate);
        ret = AudioConverterSetProperty(_audioConverter, kAudioConverterEncodeBitRate, propSize, &outputBitrate);
        if(ret != noErr) {
            printf("setup audio encode bitrate error\n");
        }
        return 0;
    }
    else {
        printf("setup audio encoder error:%d\n",ret);
        return 2;
    }
}

AudioBufferList _g_input_buffer_list;

OSStatus aw_audio_data_proc(
        AudioConverterRef audio_converter,
        UInt32 *io_number_data_packets,
        AudioBufferList *io_data,
        AudioStreamPacketDescription **ouput_data_packet_description,
        void *in_user_data) {
    AudioBufferList *in_buffer_list =
        (AudioBufferList*)in_user_data;
    uint32_t numBytes = in_buffer_list->mBuffers[0].mDataByteSize;
    io_data->mBuffers[0].mNumberChannels = in_buffer_list->mBuffers[0].mNumberChannels;
    io_data->mBuffers[0].mData = in_buffer_list->mBuffers[0].mData;
    io_data->mBuffers[0].mDataByteSize = numBytes;
    (*io_number_data_packets) = numBytes / _input_format.mBytesPerPacket;
    return noErr;
    
}


/// 编码, 输出的 AudioBufferList 一定要在某个地方被释放掉，如果他是在异步队列中被使用的话，一定要在异步完成之后释放他
AudioBufferList *aw_audio_encode(CMSampleBufferRef sample_buffer) {
    /// format
    CMFormatDescriptionRef format =
        CMSampleBufferGetFormatDescription(sample_buffer);
    _input_format =
     *(CMAudioFormatDescriptionGetStreamBasicDescription(format));
    aw_audio_encoder_setup();
    if (_audioConverter == NULL) {
        return NULL;
    }
//    CMTime presentation_time = CMSampleBufferGetOutputPresentationTimeStamp(sample_buffer);
//    CMTime duration = CMSampleBufferGetDuration(sample_buffer);
//    printf("audio encoding timestamp:%f,duration:%f\n",CMTimeGetSeconds(presentation_time),CMTimeGetSeconds(duration));
    /// input
    CMBlockBufferRef input_block_buffer;
    AudioBufferList input_buffer_list;
    int input_result =  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample_buffer,
            NULL,
            &input_buffer_list,
            sizeof(input_buffer_list),
            NULL,
            NULL,
            0,
            &input_block_buffer);
    CFRelease(input_block_buffer);
    if (input_result != noErr) {
        printf("get input buffer error:%d",input_result);
        return NULL;
    }
    ///
    const UInt32 frame_size = 1024*2*output_audio_channels;
    uint8_t *data_ptr = malloc(frame_size);
    memset(data_ptr, 0, frame_size);
    AudioBufferList *output_buffer_list = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    output_buffer_list->mNumberBuffers = 1;
    output_buffer_list->mBuffers[0].mNumberChannels = output_audio_channels;
    output_buffer_list->mBuffers[0].mDataByteSize = frame_size;
    output_buffer_list->mBuffers[0].mData = data_ptr;
    UInt32 output_data_packet_size = 1;
    
    AudioStreamPacketDescription output_packet_description;
    int fill_result = AudioConverterFillComplexBuffer(
        _audioConverter,
        aw_audio_data_proc,
        &input_buffer_list,
        &output_data_packet_size,
        output_buffer_list,
        &output_packet_description);
    if (fill_result == noErr) {
//        free(data_ptr);
//        printf("audio encoded input:%u, output:%u\n", input_buffer_list.mBuffers[0].mDataByteSize,
//               output_buffer_list->mBuffers[0].mDataByteSize);
        return output_buffer_list;
    }
    free(data_ptr);
    return NULL;
}

/// 释放编码后的内容
void aw_audio_release(AudioBufferList *buffer_list) {
    free(buffer_list->mBuffers[0].mData);
    free(buffer_list);
}
