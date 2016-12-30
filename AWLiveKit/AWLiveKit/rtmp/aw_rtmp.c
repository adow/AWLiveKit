//
//  aw_rtmp.c
//  TestLivePush2
//
//  Created by 秦 道平 on 16/7/1.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

#include "aw_rtmp.h"
//定义包头长度，RTMP_MAX_HEADER_SIZE=18
#define AW_RTMP_HEAD_SIZE   (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)
//存储Nal单元数据的buffer大小
#define AW_BUFFER_SIZE 32768
//搜寻Nal单元时的一些标志
#define AW_GOT_A_NAL_CROSS_BUFFER BUFFER_SIZE+1
#define AW_GOT_A_NAL_INCLUDE_A_BUFFER BUFFER_SIZE+2
#define AW_NO_MORE_BUFFER_TO_READ BUFFER_SIZE+3

unsigned int  aw_m_nFileBufSize;
unsigned int  aw_nalhead_pos;
RTMP* aw_m_pRtmp;
unsigned char *aw_m_pFileBuf;
unsigned char *aw_m_pFileBuf_tmp;
unsigned char *aw_m_pFileBuf_tmp_old;	//used for realloc

void aw_debug_print(const unsigned char *str, int length) {
	const unsigned char *str_start = str;
	while (str - str_start < length) {
		unsigned char c = *(str++);
		printf("%02x ", c);
	}
	printf("\n");
}

/// 链接
int aw_rtmp_connection(const char *url) {
    aw_nalhead_pos=0;
    aw_m_nFileBufSize=AW_BUFFER_SIZE;
    aw_m_pFileBuf = (unsigned char*)malloc(AW_BUFFER_SIZE);
    aw_m_pFileBuf_tmp = (unsigned char*)malloc(AW_BUFFER_SIZE);
    
    aw_m_pRtmp = RTMP_Alloc();
    RTMP_Init(aw_m_pRtmp);
    /*设置URL*/
    if (RTMP_SetupURL(aw_m_pRtmp,(char*)url) == FALSE)
    {
        printf("Set URL Failed");
        RTMP_Free(aw_m_pRtmp);
        return false;
    }
    /*设置可写,即发布流,这个函数必须在连接前使用,否则无效*/
    RTMP_EnableWrite(aw_m_pRtmp);
    /*连接服务器*/
    if (RTMP_Connect(aw_m_pRtmp, NULL) == FALSE)
    {
        printf("Connect RTMP Failed");
        RTMP_Free(aw_m_pRtmp);
        return false;
    }
    
    /*连接流*/
    if (RTMP_ConnectStream(aw_m_pRtmp,0) == FALSE)
    {
        printf("Connect Stream Failed");
        RTMP_Close(aw_m_pRtmp);
        RTMP_Free(aw_m_pRtmp);
        return false;
    }
    return true;
}

void aw_rtmp_close() {
    if(aw_m_pRtmp)
    {
        RTMP_Close(aw_m_pRtmp);
        RTMP_Free(aw_m_pRtmp);
        aw_m_pRtmp = NULL;
    }
    if (aw_m_pFileBuf != NULL)
    {
        free(aw_m_pFileBuf);
    }
    if (aw_m_pFileBuf_tmp != NULL)
    {  
        free(aw_m_pFileBuf_tmp);
    }
}

/// 发送 sps, pps
int aw_rtmp_send_sps_pps(unsigned char *sps, int sps_length,
                         unsigned char *pps, int pps_length) {
    RTMPPacket * packet=NULL;//rtmp包结构
    unsigned char * body=NULL;
    int i;
    packet = (RTMPPacket *)malloc(AW_RTMP_HEAD_SIZE+1024);
    //RTMPPacket_Reset(packet);//重置packet状态
    memset(packet,0,AW_RTMP_HEAD_SIZE+1024);
    packet->m_body = (char *)packet + AW_RTMP_HEAD_SIZE;
    body = (unsigned char *)packet->m_body;
    i = 0;
    body[i++] = 0x17;
    body[i++] = 0x00;
    
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00; /// 0x00
    
    /*AVCDecoderConfigurationRecord*/
    body[i++] = 0x01; /// configurationVersion
    body[i++] = sps[1]; /// AVCProfileIndication
    body[i++] = sps[2]; /// profile_compatibility
    body[i++] = sps[3]; /// AVCLevelIndication
    body[i++] = 0xff;
    
    /*sps*/
    body[i++]   = 0xe1;
    body[i++] = (sps_length >> 8) & 0xff;
    body[i++] = sps_length & 0xff;
    memcpy(&body[i],sps,sps_length);
    i +=  sps_length;
    
    /*pps*/
    body[i++]   = 0x01;
    body[i++] = (pps_length >> 8) & 0xff;
    body[i++] = (pps_length) & 0xff;
    memcpy(&body[i],pps,pps_length);
    i +=  pps_length;
    
    packet->m_packetType = RTMP_PACKET_TYPE_VIDEO;
    packet->m_nBodySize = i;
    packet->m_nChannel = 0x04;
    packet->m_nTimeStamp = 0;
    packet->m_hasAbsTimestamp = 0;
    packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet->m_nInfoField2 = aw_m_pRtmp->m_stream_id;
    
    /*调用发送接口*/
    printf("sps,pps: ");
    int nRet = RTMP_SendPacket(aw_m_pRtmp,packet,TRUE);
    aw_debug_print(body, i);
    free(packet);    //释放内存
    if (!nRet) {
        printf("Send sps, pps failed");
    }
    return nRet;
}

int aw_rtmp_send_h264_video(unsigned char *data,
                unsigned int size,
                int bIsKeyFrame, unsigned int nTimeStamp) {
    if(data == NULL && size<11){
        return false;
    }
    RTMPPacket * packet;
    packet = (RTMPPacket *)malloc(AW_RTMP_HEAD_SIZE+size+9);
    memset(packet, 0, AW_RTMP_HEAD_SIZE);
    
    packet->m_body = (char *)packet + AW_RTMP_HEAD_SIZE;
    packet->m_nBodySize = size + 9;
    
    unsigned char *body = (unsigned char *)packet->m_body;
    
    int i = 0;
    if(bIsKeyFrame){
        body[i++] = 0x17;// 1:Iframe  7:AVC
    }else{
        body[i++] = 0x27;// 2:Pframe  7:AVC
    }
    body[i++] = 0x01;// AVC NALU
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00; /// 0x00
    
    // NALU size
    body[i++] = (size >> 24) & 0xff;
    body[i++] = (size >> 16) & 0xff;
    body[i++] = (size >> 8)  & 0xff;
    body[i++] = size & 0xff;
    // NALU data   
    memcpy(&body[i],data,size);
    
    packet->m_hasAbsTimestamp = 0;
    packet->m_packetType = RTMP_PACKET_TYPE_VIDEO;
    packet->m_nInfoField2 = aw_m_pRtmp ->m_stream_id;
    packet->m_nChannel = 0x04;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet->m_nTimeStamp = nTimeStamp;
    
    /*调用发送接口*/
    printf("video timeStamp:%d, keyFrame:%d,size:%d:\n",nTimeStamp, bIsKeyFrame, size);
    int result = RTMP_SendPacket(aw_m_pRtmp,packet,TRUE);
//    aw_debug_print(body,i + size);
    free(packet);
    if (!result) {
        printf("Send video failed");
    }
    return result;
}

int aw_rtmp_send_audio_header() {
    RTMPPacket * packet;
    packet = (RTMPPacket *)malloc(AW_RTMP_HEAD_SIZE + 4);
    memset(packet, 0, AW_RTMP_HEAD_SIZE);
    
    packet->m_body = (char *)packet + AW_RTMP_HEAD_SIZE;
    
    unsigned char *body = (unsigned char *)packet->m_body;
    body[0] = 0xAF;
    body[1] = 0x01;
    body[2] = 0x12;
    body[3] = 0x10;
    packet->m_hasAbsTimestamp = 0;
    packet->m_packetType = RTMP_PACKET_TYPE_AUDIO;
    packet->m_nInfoField2 = aw_m_pRtmp ->m_stream_id;
    packet->m_nChannel = 0x04;
    packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet->m_nTimeStamp = 0;
    packet->m_nBodySize = 4;
    
    /*调用发送接口*/
    printf("audio header: ");
    int result = RTMP_SendPacket(aw_m_pRtmp,packet,TRUE);
    aw_debug_print(body,4);
    free(packet);
    if (!result) {
        printf("Send audio head failed");
    }
    return result;
}

int aw_rtmp_send_audio(unsigned char *data, 
		unsigned int size,
		unsigned int nTimeStamp) {
    RTMPPacket * packet;
    packet = (RTMPPacket *)malloc(AW_RTMP_HEAD_SIZE+size+2);
    memset(packet, 0, AW_RTMP_HEAD_SIZE);
    
    packet->m_body = (char *)packet + AW_RTMP_HEAD_SIZE;
    
    unsigned char *body = (unsigned char *)packet->m_body;
    body[0] = 0xAF;
    body[1] = 0x01;
    memcpy(body + 2, data, size);
    packet->m_hasAbsTimestamp = 0;
    packet->m_packetType = RTMP_PACKET_TYPE_AUDIO;
    packet->m_nInfoField2 = aw_m_pRtmp ->m_stream_id;
    packet->m_nChannel = 0x04;
    packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet->m_nTimeStamp = nTimeStamp;
    packet->m_nBodySize = size + 2;
    
    /*调用发送接口*/
//    printf("audio %d: ",nTimeStamp);
    int result = RTMP_SendPacket(aw_m_pRtmp,packet,TRUE);
//    aw_debug_print(body,2 + size);
    free(packet);
    if (!result) {
        printf("Send audio failed");
    }
    return result;
}


