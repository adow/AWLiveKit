#ifndef flvrtmp_h
#define flvrtmp_h
#include "../rtmp/rtmp.h"
RTMP* flv_m_pRtmp;
int flv_rtmp_connect(const char *url,int write);
void flv_rtmp_close();
int flv_rtmp_send_data(unsigned char *data, uint32_t size, 
        uint32_t timestamp,uint8_t type);
int flv_rtmp_read_buf(void *buf, size_t size);
int flv_rtmp_read_u8(uint32_t *u8);
int flv_rtmp_read_u16(uint32_t *u16);
int flv_rtmp_read_u24(uint32_t *u24);
int flv_rtmp_read_u32(uint32_t *u32);
#endif
