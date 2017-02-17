#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#include "util.h"
#include "flvrtmp.h"

/// rtmp
//定义包头长度，RTMP_MAX_HEADER_SIZE=18
#define FLV_RTMP_HEAD_SIZE   (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)
//存储Nal单元数据的buffer大小
#define FLV_BUFFER_SIZE 32768
//搜寻Nal单元时的一些标志
#define FLV_GOT_A_NAL_CROSS_BUFFER BUFFER_SIZE+1
#define FLV_GOT_A_NAL_INCLUDE_A_BUFFER BUFFER_SIZE+2
#define FLV_NO_MORE_BUFFER_TO_READ BUFFER_SIZE+3

unsigned int  flv_m_nFileBufSize;
unsigned int  flv_nalhead_pos;
unsigned char *flv_m_pFileBuf;
unsigned char *flv_m_pFileBuf_tmp;
unsigned char *flv_m_pFileBuf_tmp_old;	//used for realloc

/// rtmp
/// 连接 rtmp
int flv_rtmp_connect(const char *rtmp_url, int write) {
    flv_nalhead_pos=0;
    flv_m_nFileBufSize=FLV_BUFFER_SIZE;
    flv_m_pFileBuf = (unsigned char*)malloc(FLV_BUFFER_SIZE);
    flv_m_pFileBuf_tmp = (unsigned char*)malloc(FLV_BUFFER_SIZE);
    
    flv_m_pRtmp = RTMP_Alloc();
    RTMP_Init(flv_m_pRtmp);
    /*设置URL*/
    if (RTMP_SetupURL(flv_m_pRtmp,(char*)rtmp_url) == FALSE)
    {
        aw_log("Set URL Failed\n");
        RTMP_Free(flv_m_pRtmp);
        return -1;
    }
    /*设置可写,即发布流,这个函数必须在连接前使用,否则无效*/
    if (write) {
    	RTMP_EnableWrite(flv_m_pRtmp);
    }
    /*连接服务器*/
    if (RTMP_Connect(flv_m_pRtmp, NULL) == false)
    {
        aw_log("Connect RTMP Failed\n");
        RTMP_Free(flv_m_pRtmp);
        return -2;
    }
    
    /*连接流*/
    if (RTMP_ConnectStream(flv_m_pRtmp,0) == false)
    {
        aw_log("Connect Stream Failed\n");
        RTMP_Close(flv_m_pRtmp);
        RTMP_Free(flv_m_pRtmp);
        return -3;
    }
    return 0;
}

/// 关闭 rtmp 连接
void flv_rtmp_close() {
    if(flv_m_pRtmp)
    {
        RTMP_Close(flv_m_pRtmp);
        RTMP_Free(flv_m_pRtmp);
        flv_m_pRtmp = NULL;
    }
    if (flv_m_pFileBuf != NULL)
    {
        free(flv_m_pFileBuf);
    }
    if (flv_m_pFileBuf_tmp != NULL)
    {  
        free(flv_m_pFileBuf_tmp);
    }
}
/// 发送 rtmp 数据
int flv_rtmp_send_data(unsigned char *data, uint32_t size, 
        uint32_t timestamp,uint8_t type) {
    if (data == NULL && size < 11) {
        return -1;
    }
    uint32_t packet_size= FLV_RTMP_HEAD_SIZE + size;
    RTMPPacket *packet;
    packet = (RTMPPacket *)malloc(packet_size);
    memset(packet, 0, FLV_RTMP_HEAD_SIZE);
    //flv_rtmp_printf("data_size:%d,packet_size:%d\n",size,packet_size);

    packet->m_body = (char *)packet + FLV_RTMP_HEAD_SIZE;
    unsigned char *body = (unsigned char *)packet->m_body;
    //flv_rtmp_printf("copy body\n");
    if (body == NULL) {
        aw_log("body is null\n");
    }
    memcpy(body, data, size);

    packet->m_hasAbsTimestamp = 0;
    packet->m_packetType = type;
    packet->m_nInfoField2 = flv_m_pRtmp->m_stream_id;
    packet->m_nChannel = 0x04;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet->m_nTimeStamp = timestamp;
    packet->m_nBodySize = size;
    //flv_rtmp_printf("sending...\n");
    int result = RTMP_SendPacket(flv_m_pRtmp, packet, true);
    free(packet);
    if (!result) {
        aw_log("rtmp send failed\n");
    }
    return result; 
}

/// flv_rtmp
int flv_rtmp_read_buf(void *buf, size_t size) {
	/// 从 rtmp 流中读取足够多的内容
	if (size <= 0) {
		return 0;
	}
	size_t read_next = size;
	while (1) {
		void *input = calloc(read_next,1);
		size_t len = RTMP_Read(flv_m_pRtmp, input, read_next);
		if (len == read_next) {
			memcpy(buf, input, len);
			free(input);
			break;
		}
		else if (len < read_next) {
			memcpy(buf, input,len);
			free(input);
			buf += len;
			read_next = read_next - len;
			aw_log("read not enough:%ld/%ld", len, read_next);
			sleep(1);
		}
	}
	return 0;
}

int flv_rtmp_read_u8(uint32_t *u8) {
	if (flv_rtmp_read_buf(u8,1)) return -1;
	return 0;
}
int flv_rtmp_read_u16(uint32_t *u16) {
	if (flv_rtmp_read_buf(u16,2)) return -1;
	*u16 = HTON16(*u16);
	return 0;
}
int flv_rtmp_read_u24(uint32_t *u24) {
	if (flv_rtmp_read_buf(u24,3)) return -1;
	*u24 = HTON24(*u24);
	return 0;
}
int flv_rtmp_read_u32(uint32_t *u32) {
	if (flv_rtmp_read_buf(u32,4)) return -1;
	*u32 = HTON32(*u32);
	return 0;
}
