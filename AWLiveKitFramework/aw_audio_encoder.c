//
//  aw_audio_encoder.c
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/2/19.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

#include "aw_audio_encoder.h"


AudioConverterRef _audioConverter;
AudioStreamBasicDescription _input_format;

int aw_audio_encoder_setup() {
    if (_audioConverter != NULL) {
        return 0;
    }
    
    /// output_format
    AudioStreamBasicDescription output_format;
    output_format.mSampleRate =
        _input_format.mSampleRate;
    output_format.mFormatID = kAudioFormatMPEG4AAC;
    output_format.mFormatFlags = kMPEG4Object_AAC_Main;
    output_format.mChannelsPerFrame = _input_format.mChannelsPerFrame;
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
        class_1,
        class_2,
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
//        UInt32 outputBitrate = 128000;
//        UInt32 propSize = sizeof(outputBitrate);
//        ret = AudioConverterSetProperty(_audioConverter, kAudioConverterEncodeBitRate, propSize, &outputBitrate);
//        if(ret != noErr) {
//            printf("setup audio encode bitrate error\n");
//        }
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
//    AudioBufferList *in_buffer_list = &_g_input_buffer_list;
    uint32_t numBytes =
        (*io_number_data_packets) * _input_format.mBytesPerPacket;
    io_data->mBuffers->mData = in_buffer_list->mBuffers->mData;
    io_data->mBuffers->mDataByteSize = numBytes;
    (*io_number_data_packets) = numBytes / _input_format.mBytesPerPacket;
    return noErr;
    
}
int aw_audio_encode_samplebuffer(CMSampleBufferRef sampleBuffer) {
    /// format
    CMFormatDescriptionRef format =
        CMSampleBufferGetFormatDescription(sampleBuffer);
    _input_format =
     *(CMAudioFormatDescriptionGetStreamBasicDescription(format));
    aw_audio_encoder_setup();
    if (_audioConverter == NULL) {
        return 1;
    }
    /// input
    CMBlockBufferRef input_block_buffer;
    AudioBufferList input_buffer_list;
    int input_result =  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
            NULL,
            &input_buffer_list,
            sizeof(AudioBufferList),
            NULL,
            NULL,
            0,
            &input_block_buffer);
    if (input_result != noErr) {
        return 2;
    }
//    _g_input_buffer_list = input_buffer_list;
    ///
    const UInt32 frame_size = 1024;
    uint8_t *data_ptr = malloc(frame_size);
    memset(data_ptr, 0, frame_size);
    int channels = _input_format.mChannelsPerFrame;
    AudioBufferList output_buffer_list;
    output_buffer_list.mNumberBuffers = 1;
    output_buffer_list.mBuffers[0].mNumberChannels = channels;
    output_buffer_list.mBuffers[0].mDataByteSize = frame_size;
//    output_buffer_list.mBuffers[0].mDataByteSize = input_buffer_list.mBuffers[0].mDataByteSize;
    output_buffer_list.mBuffers[0].mData = data_ptr;
    UInt32 output_data_packet_size = 1;
    
    AudioStreamPacketDescription output_packet_description;
    int fill_result = AudioConverterFillComplexBuffer(
        _audioConverter,
        aw_audio_data_proc,
        &input_buffer_list,
        &output_data_packet_size,
        &output_buffer_list,
        &output_packet_description);
//    free(data_ptr);
    if (fill_result == noErr) {
        printf("audio encode ok\n");
        return 0;
    }
    int error_codes[] = {
        kAudioConverterErr_FormatNotSupported,
        kAudioConverterErr_OperationNotSupported,
        kAudioConverterErr_PropertyNotSupported,
        kAudioConverterErr_InvalidInputSize,
        kAudioConverterErr_InvalidOutputSize,
        kAudioConverterErr_UnspecifiedError,
        kAudioConverterErr_BadPropertySizeError,
        kAudioConverterErr_RequiresPacketDescriptionsError,
        kAudioConverterErr_InputSampleRateOutOfRange,
        kAudioConverterErr_OutputSampleRateOutOfRange,
        kAudioConverterErr_HardwareInUse,
        kAudioConverterErr_NoHardwarePermission,
    };
    int _a = 0;
    for (_a = 0;_a < 12; _a++) {
        int _v = error_codes[_a];
        int _r = fill_result == _v;
        printf("%d:%d,%d\n",_a, _v, _r);
    }
    return 3;
}

/// 编码
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
    const UInt32 frame_size = 1024;
    uint8_t *data_ptr = malloc(frame_size);
    memset(data_ptr, 0, frame_size);
    int channels = _input_format.mChannelsPerFrame;
    AudioBufferList *output_buffer_list = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    output_buffer_list->mNumberBuffers = 1;
    output_buffer_list->mBuffers[0].mNumberChannels = channels;
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
        free(data_ptr);
//        printf("audio encode ok:%u\n", (unsigned int)output_data_packet_size);
        return output_buffer_list;
    }
    free(data_ptr);
    return NULL;
}

/// 释放编码后的内容
void aw_audio_release(AudioBufferList *buffer_list) {
    free(buffer_list);
}
