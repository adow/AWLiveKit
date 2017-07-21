//
//  aw_video_encoder.c
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/12.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

#include "aw_video_encoder.h"

VTCompressionSessionRef _compressionSession = NULL;
void aw_video_encoded_callback(void *data,
                               void *source,
                               OSStatus status,
                               VTEncodeInfoFlags infoFlats,
                               CMSampleBufferRef sampleBuffer);

int aw_video_encoder_init(int width, int height,
                          int bitrate,
                          int fps,
                          CFStringRef profile) {
    printf("Video Encoder OutputSize:%dx%d\n", width,height);
    printf("Video Encoder Bitrate:%d\n", bitrate);
    printf("Video Encoder FPS:%d\n",fps);
    const char *profile_str = CFStringGetCStringPtr(profile, kCFStringEncodingUTF8);
    printf("Video Encoder Profile:%s\n", profile_str);
  
    int format = kCVPixelFormatType_32BGRA;
    CFNumberRef format_value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &format);
    CFBooleanRef opengles = kCFBooleanTrue;
    CFNumberRef width_value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width);
    CFNumberRef height_value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height);
    CFNumberRef fps_number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &fps);
    CFNumberRef bitrate_number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitrate);
    
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    CFDictionarySetValue(attributes, kCVPixelBufferPixelFormatTypeKey, format_value);
    CFDictionarySetValue(attributes, kCVPixelBufferOpenGLESCompatibilityKey, opengles);
    CFDictionarySetValue(attributes, kCVPixelBufferWidthKey, width_value);
    CFDictionarySetValue(attributes, kCVPixelBufferHeightKey, height_value);
    int status = VTCompressionSessionCreate(kCFAllocatorDefault,
                               width, height,
                               kCMVideoCodecType_H264,
                               NULL,
                               attributes,
                               NULL,
                               aw_video_encoded_callback,
                               NULL,
                               &_compressionSession);
    if (status != noErr) {
        CFRelease(format_value);
        CFRelease(width_value);
        CFRelease(height_value);
        CFRelease(fps_number);
        CFRelease(bitrate_number);
        CFRelease(attributes);
        printf("Create Compression Session Error:%d\n",status);
        return -1;
    }
    
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, profile);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AllowTemporalCompression, kCFBooleanTrue);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, bitrate_number);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, fps_number);
    status = VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    CFRelease(format_value);
    CFRelease(width_value);
    CFRelease(height_value);
    CFRelease(fps_number);
    CFRelease(bitrate_number);
    CFRelease(attributes);
    if (status != noErr) {
        printf("Prepare to Encode Frames Error:%d\n",status);
        return -2;
    }
    return 0;
}
void aw_video_encoder_close() {
    if (_compressionSession == NULL) {
        return;
    }
    VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_compressionSession);
    _compressionSession = NULL;
    printf("close aw_video_encoder\n");
}
AWVideoEncoderCallback _g_callback = NULL;
void *_g_callback_context = NULL;

int aw_video_encode_samplebuffer(CMSampleBufferRef sample_buffer,
                AWVideoEncoderCallback callback,
                void *callback_context) {
    CVPixelBufferRef pixel_buffer = CMSampleBufferGetImageBuffer(sample_buffer);
    if (pixel_buffer == NULL) {
        printf("No Pixel Buffer\n");
        return -1;
    }
    CMTime presentation_time = CMSampleBufferGetOutputPresentationTimeStamp(sample_buffer);
    CMTime duration = CMSampleBufferGetDuration(sample_buffer);
    return aw_video_encode_pixelbuffer(pixel_buffer, presentation_time,
        duration,
        callback,
        callback_context);
}

int aw_video_encode_pixelbuffer(CVPixelBufferRef pixel_buffer,
                    CMTime presentation_time,
                    CMTime duration,
                    AWVideoEncoderCallback callback,
                    void *callback_context) {
    if (_compressionSession == NULL) {
        return -1;
    }
    if (CVPixelBufferLockBaseAddress(pixel_buffer, 0) != kCVReturnSuccess) {
        printf("PixelBuffer Lock Base Address Failed\n");
        return -2;
    }
    _g_callback = callback;
    _g_callback_context = callback_context;
    int status = VTCompressionSessionEncodeFrame(_compressionSession, pixel_buffer, presentation_time, duration, NULL, NULL, NULL);
    if (status) {
        printf("Encode Frame Error:%d\n",status);
        CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
        return status;
    }
    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
    return 0;
    
}

void aw_video_encoded_callback(void *data,
                               void *source,
                               OSStatus status,
                               VTEncodeInfoFlags infoFlats,
                               CMSampleBufferRef sampleBuffer) {
    if (_g_callback  && sampleBuffer) {
        (*_g_callback)(sampleBuffer, _g_callback_context);
    }
}
