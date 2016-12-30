//
//  aw_live_push.c
//  AWLiveKit
//
//  Created by 秦 道平 on 2016/12/29.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

#include "aw_live_push.h"
#include <time.h>
#include "aw_rtmp.h"
#include <CoreFoundation/CoreFoundation.h>
#include <VideoToolBox/VideoToolBox.h>


CFDictionaryRef aw_samplebuffer_attachment(CMSampleBufferRef sample_buffer) {
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample_buffer, true);
    if (attachments == NULL) {
        return NULL;
    }
    const CFDictionaryRef p = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        return p;
}
int aw_sample_depends_on_others(CMSampleBufferRef sample_buffer) {
    const CFDictionaryRef p = aw_samplebuffer_attachment(sample_buffer);
    if (p == NULL) {
        return -1;
    }

    CFBooleanRef depends_on_other_optinal_ref = (CFBooleanRef)CFDictionaryGetValue(p, kCMSampleAttachmentKey_DependsOnOthers);
    return depends_on_other_optinal_ref == kCFBooleanTrue ? 1 : 0;

}
int aw_samplebuffer_is_key_frame(CMSampleBufferRef sample_buffer) {
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample_buffer, true);
    if (attachments == NULL) {
        return -1;
    }
    const CFDictionaryRef p = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFBooleanRef depends_on_other_optinal_ref = (CFBooleanRef)CFDictionaryGetValue(p, kCMSampleAttachmentKey_DependsOnOthers);
    if (depends_on_other_optinal_ref == NULL) {
        return -2;
    }
//   return depends_on_other_optinal_ref == kCFBooleanTrue ? 0 : 1;
    if (CFBooleanGetValue(depends_on_other_optinal_ref)) {
        return 0;
    }
    else {
        return 1;
    }
}
CMTime
aw_samplebuffer_decode_timestamp(CMSampleBufferRef sample_buffer) {
    CMTime decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sample_buffer);
    if CMTIME_IS_INVALID(decodeTimeStamp) {
        return CMSampleBufferGetPresentationTimeStamp(sample_buffer);
    }
    else {
        return decodeTimeStamp;
    }
    
}
CMTime
aw_samplebuffer_presentation_timestamp(CMSampleBufferRef sample_buffer) {
    return CMSampleBufferGetPresentationTimeStamp(sample_buffer);
}
const uint8_t *aw_samplebuffer_get_sps_pps_data(int choice, CMSampleBufferRef sample_buffer, size_t *buffer_length) {
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sample_buffer);
    if (format == NULL) {
        return NULL;
    }
//    size_t para_set_size = 0;
    size_t para_set_count = 0;
    int para_set_index = choice;
    const uint8_t *para_set_pointer;
    int nalu_head_len = 0;
    int status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, para_set_index, &para_set_pointer,
        buffer_length, &para_set_count, &nalu_head_len);
    if (status == noErr) {
        return para_set_pointer;
    }
    else {
        return NULL;
    }
}
const uint8_t *aw_samplebuffer_get_sps(CMSampleBufferRef sample_buffer, size_t *set_count) {
    return aw_samplebuffer_get_sps_pps_data(0, sample_buffer, set_count);
}
const uint8_t *aw_samplebuffer_get_pps(CMSampleBufferRef sample_buffer, size_t *set_count) {
    return aw_samplebuffer_get_sps_pps_data(1, sample_buffer, set_count);
}
const char *aw_get_frametypename(uint8_t first_bit) {
   int frame_type = first_bit & 0x1f;
    switch (frame_type) {
        case 1:
            return "SLICE";
        case 2:
            return "SLICE_DPA";
        case 3:
            return "SLICE_DPB";
        case 4:
            return "SLICE_DPC";
        case 5:
            return "SLICE_IDR";
        case 6:
            return "SLICE_SEI";
        case 7:
            return "SLICE_SPS";
        case 8:
            return "SLICE_PPS";
        case 9:
            return "AUD";
        case 12:
            return "FILLER";
        default:
            return "UNKNOWN";
    }
    return NULL;
}

/// 发送视频内容
/// is_spspps_sent: 是否已经发送过sps/pps;
/// time_t: 开始时间;
int aw_push_video_samplebuffer(CMSampleBufferRef sample_buffer,
                               double time_offset,
                               int *is_spspps_sent) {
    if (!CMSampleBufferDataIsReady(sample_buffer)) {
        return -1;
    }
    int key_frame = aw_samplebuffer_is_key_frame(sample_buffer);
    if (key_frame < 0) {
        return -2;
    }
    CMBlockBufferRef data_buffer = CMSampleBufferGetDataBuffer(sample_buffer);
    if (data_buffer == NULL) {
        return -3;
    }
    /// send sps pps, 只需要发送一次
    if (key_frame == 1 && !(*is_spspps_sent)) {
        size_t sps_size;
        const uint8_t *p_sps = aw_samplebuffer_get_sps(sample_buffer, &sps_size);
        size_t pps_size;
        const uint8_t *p_pps = aw_samplebuffer_get_pps(sample_buffer, &pps_size);
        aw_rtmp_send_sps_pps((unsigned char *)p_sps,
                             (int)sps_size,
                             (unsigned char *)p_pps,
                             (int)pps_size);
        *is_spspps_sent = 1; /// 发送结束后修改外部状态
    }
    /// send data
    size_t data_length;
    char *data_pointer;
    int status = CMBlockBufferGetDataPointer(data_buffer, 0, NULL, &data_length,&data_pointer);
    if (status != noErr ){
        return -4;
    }
    unsigned char *data_pointer_u = (unsigned char*)data_pointer;
    size_t buffer_offset = 0;
    const size_t avvc_header_length = 4;
    while (buffer_offset < data_length - avvc_header_length) {
        uint32_t nal_unit_length = 0;
        memcpy(&nal_unit_length,
               data_pointer_u + buffer_offset,
               avvc_header_length);
        nal_unit_length = CFSwapInt32BigToHost(nal_unit_length);
        /// is idr frame
        uint8_t first_bit = *(data_pointer_u + buffer_offset + avvc_header_length);
        int frame_type = first_bit & 0x1f;
//        printf("frame_type:%d,%s\n",frame_type,aw_get_frametypename(frame_type));
        int idr_frame = (frame_type == 5 ? 1 : 0);
        /// send data
        aw_rtmp_send_h264_video(data_pointer_u + buffer_offset + avvc_header_length,
                                nal_unit_length,
                                idr_frame,
                                time_offset);
        /// buffer_offset to the next frame
        buffer_offset = buffer_offset + avvc_header_length + nal_unit_length;
    }
    return 0;
}
