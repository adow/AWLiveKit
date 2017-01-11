#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "../rtmp/rtmp.h"

#define LOG_MAX_LINE 2048 ///每行日志的最大长度
#define LOG_BUFFER_MAX 2048000 ///printf时的最大长度

#define HTON16(x)  ((x>>8&0xff)|(x<<8&0xff00))  
#define HTON24(x)  ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00))  
#define HTON32(x)  ((x>>24&0xff)|(x>>8&0xff00)|(x<<8&0xff0000)|(x<<24&0xff000000))  
#define HTONTIME(x) ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00)|(x&0xff000000))  

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
RTMP* flv_m_pRtmp;
unsigned char *flv_m_pFileBuf;
unsigned char *flv_m_pFileBuf_tmp;
unsigned char *flv_m_pFileBuf_tmp_old;	//used for realloc

int flv_rtmp_connect(const char *url);
void flv_rtmp_close();
int flv_rtmp_send_data(unsigned char *data, uint32_t size, 
        uint32_t timestamp,uint8_t type);

int fd = -1; /// flv 文件
char filename[PATH_MAX] = {'\0'};
//const char *filename = "./test.txt";
//const char *filename = "/Users/reynoldqin/Downloads/1.flv";
char url[PATH_MAX] = {'\0'};
//const char *url = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84";

int print_hex_str(const unsigned char *s, size_t n, 
        const char *split,
        const char *end) {
    for (int a = 0; a < n; a++) {
        int c = *(s + a);
        printf("%02x%s",c,split);
    }
    printf("%s",end);
    return 0;
}

int flv_open_read() {
	// 打开读取文件，如果文件已经打开就关闭
	off_t pos = 0;
	if (fd != -1) {
		pos = lseek(fd,0,SEEK_CUR);
		close(fd);
		sleep(1);/// wait 1s for reopening
	}	
	fd = open(filename, O_RDONLY);
	if (fd == -1) {
		return -1; /// 无法打开就返回 -1
	}
	lseek(fd, pos,SEEK_SET);
	return 0;
}

int flv_read_buf(void *buf, size_t size) {
	/// 以安全的方式读取文件内容，读取足够多内容, 如果没有读满指定长度的内容，会重复打开文件后再次读取
	if (fd == -1) {
		if (flv_open_read()) {
			return -1;
		}
	}
	size_t read_next = size;
	while (1) {
		void *input = malloc(read_next);
		memset(input, '\0', read_next);
		ssize_t len = read(fd, input, read_next);
		//printf("read:%ld/%ld\n",len, read_next);
		if (len == read_next) {
			//print_hex_str(input,read_next," ","\n");
			//printf("%s\n",input);
			memcpy(buf ,input, len);
			free(input);
			break;
		}
		else if (len < read_next && len > 0) {
			//print_hex_str(input,read_next," ","\n");
			//printf("%s\n",input);
			memcpy(buf,input, len);
			free(input);
			buf += len; /// 往后面移动位置
			printf("read not enough:%ld,%ld\n",read_next, len);
			read_next = read_next - len;
			if (flv_open_read()) {
				return -1;
			}
		}
		else {
			free(input);
			printf("read to the end of file\n");
			if (flv_open_read()) {
				return -1;
			}
		}
		//fflush(stdout);
	}
	return 0;
}

int flv_read_u8(uint32_t *u8) {
	if (flv_read_buf(u8, 1)) {
		return -1;
	}
	return 0;
}
int flv_read_u16(uint32_t *u16) {
	if (flv_read_buf(u16, 2)) {
		return -1;
	}
	*u16 = HTON16(*u16);
	return 0;
}
int flv_read_u24(uint32_t *u24) {
	if (flv_read_buf(u24, 3)) {
		return -1;
	}
	*u24 = HTON24(*u24);
	return 0;
}
int flv_read_u32(uint32_t *u32) {
	if (flv_read_buf(u32, 4)) {
		return -1;
	}
	*u32 = HTON32(*u32);
	return 0;
}

int push_flv_file_rtmp(int verbose) {
	if (flv_rtmp_connect(url)) {
		return -2;
	}
	int c;
    	int counter = 0;
    	int limits = 0;
	/// flv header
	/// signautre
	unsigned char signature[4] = {'\0'};
	if (flv_read_buf(signature, 3)) {
		return -1;
	}
	printf("signature:%s\n",signature);
	print_hex_str(signature, 4, " ","\n");
	/// version
	unsigned char version[2] = {'\0'};
	if (flv_read_buf(version,1)) {
		return -1;
	}
	printf("version:\n");
	print_hex_str(version,2," ", "\n");
	/// flags
	unsigned char flags[2] = {'\0'};
	if (flv_read_buf(flags,1)) {
		return -1;
	}
	printf("flags:\n");
	print_hex_str(flags,2," ", "\n");
	/// header_size
	uint32_t header_size = 0;
	if (flv_read_u32(&header_size)) {
		return -1;
	}
	printf("header_size:%d\n",header_size);

	/// flv body
	while (1) {
        	printf("--------------TAG:%d---------------\n",counter);
		/// previous tag size
		uint32_t previous_tag_size = 0;
		if (flv_read_u32(&previous_tag_size)) return -1;
        	printf("previous_tag_size:%d\n",previous_tag_size);
		/// tag header
		uint32_t tag_header_type = 0;
		if (flv_read_u8(&tag_header_type)) return -1;
		printf("tag_header_type:%02x\n",tag_header_type); 
		/// tag header data size
		uint32_t tag_header_data_size = 0;
		if (flv_read_u24(&tag_header_data_size)) return -1;
		printf("tag_header_data_size:%d\n",tag_header_data_size);
		/// tag header timestamp
		uint32_t tag_header_timestamp = 0;
		if (flv_read_u24(&tag_header_timestamp)) return -1;
		printf("tag_header_timestamp:%d\n",tag_header_timestamp);
		/// tag header timestamp_ex
		uint32_t tag_header_timestamp_ex = 0;
		if (flv_read_u8(&tag_header_timestamp_ex)) return -1;
		printf("tag_header_timestamp_ex:%d\n",tag_header_timestamp_ex);
		/// tag stream id
		uint32_t tag_header_stream_id = 0;
		if (flv_read_u24(&tag_header_stream_id)) return -1;
		printf("tag_header_stream_id:%d\n",tag_header_stream_id);
		/// tag body
		unsigned char *tag_data = calloc(tag_header_data_size, sizeof(char));
		if (flv_read_buf(tag_data,tag_header_data_size)) return -1;
		if (verbose) {
			print_hex_str(tag_data, tag_header_data_size, " ", "\n");
		}
		/// audio
		if (tag_header_type == 0x08) {
			printf("audio tag\n");
			flv_rtmp_send_data(tag_data, tag_header_data_size,
                    		tag_header_timestamp,RTMP_PACKET_TYPE_AUDIO);
		}
		/// video
		else if (tag_header_type == 0x09) {
			printf("video tag\n");
			flv_rtmp_send_data(tag_data, tag_header_data_size,
                    		tag_header_timestamp,RTMP_PACKET_TYPE_VIDEO);
		}
		/// script
		else if (tag_header_type == 0x12) {
			printf("script tag, skipped\n");
		}

		free(tag_data);
		fflush(stdout);
		fflush(stderr);
		///
		++counter;
		if (limits && counter >= limits) {
		    break;
		}
	}
	flv_rtmp_close();
    	printf("RTMP Closed\n");	
	return 0;
}

/// rtmp
/// 连接 rtmp
int flv_rtmp_connect(const char *url) {
    flv_nalhead_pos=0;
    flv_m_nFileBufSize=FLV_BUFFER_SIZE;
    flv_m_pFileBuf = (unsigned char*)malloc(FLV_BUFFER_SIZE);
    flv_m_pFileBuf_tmp = (unsigned char*)malloc(FLV_BUFFER_SIZE);
    
    flv_m_pRtmp = RTMP_Alloc();
    RTMP_Init(flv_m_pRtmp);
    /*设置URL*/
    if (RTMP_SetupURL(flv_m_pRtmp,(char*)url) == FALSE)
    {
        printf("Set URL Failed");
        RTMP_Free(flv_m_pRtmp);
        return -1;
    }
    /*设置可写,即发布流,这个函数必须在连接前使用,否则无效*/
    RTMP_EnableWrite(flv_m_pRtmp);
    /*连接服务器*/
    if (RTMP_Connect(flv_m_pRtmp, NULL) == false)
    {
        printf("Connect RTMP Failed");
        RTMP_Free(flv_m_pRtmp);
        return -2;
    }
    
    /*连接流*/
    if (RTMP_ConnectStream(flv_m_pRtmp,0) == false)
    {
        printf("Connect Stream Failed");
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
    //printf("data_size:%d,packet_size:%d\n",size,packet_size);

    packet->m_body = (char *)packet + FLV_RTMP_HEAD_SIZE;
    unsigned char *body = (unsigned char *)packet->m_body;
    //printf("copy body\n");
    if (body == NULL) {
        printf("body is null\n");
    }
    memcpy(body, data, size);

    packet->m_hasAbsTimestamp = 0;
    packet->m_packetType = type;
    packet->m_nInfoField2 = flv_m_pRtmp->m_stream_id;
    packet->m_nChannel = 0x04;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet->m_nTimeStamp = timestamp;
    packet->m_nBodySize = size;
    //printf("sending...\n");
    int result = RTMP_SendPacket(flv_m_pRtmp, packet, true);
    free(packet);
    if (!result) {
        printf("rtmp send failed");
    }
    return result; 
}

/// 获取外部参数, 执行推流
int _execute_cmd(int arg_c, char *arg_v[]) {
    char format[] = "f:u:vw";
    int verbose = 0; /// 显示输出过程
    int wait_read = 1; /// 到文件结尾不要停止
    int ch;
    while ((ch = getopt(arg_c, arg_v, format))!= -1) {
        switch (ch) {
            case 'f':
                strcpy(filename,optarg);
                break;
            case 'u':
                strcpy(url,optarg);
                break;
            case 'v':
                verbose = 1;
                break;
            case 'e':
                wait_read = 1;
                break;

            
        }
    }
    printf("flv_filename:%s\n",filename);
    printf("url:%s\n",url);
    if (!strlen(filename)) {
        printf("need -f: filename to flv\n");
        return -1;
    }
    if (!strlen(url)) {
        printf("need -u: url to push rtmp\n");
        return -2;
    }
    push_flv_file_rtmp(verbose);
    return 0;
}


/// test
void _test_flv_read_buf() {
	while(1) {
		//printf("--------------\n");
		const size_t size = 4;
		unsigned char input[size] = {'\0'};
		if (flv_read_buf(input, size - 1)) {
			printf("flv_read_buf failed\n");
			break;
		}
		else {
			//print_hex_str(input, size," ","\n");
			//printf("%s\n",input);
			printf("%s",input);
		}
		fflush(stdout);
		sleep(1);
	}
	
}


int main(int arg_c,char *arg_v[]){	
	//_test_flv_read_buf();	
	//push_flv_file_rtmp(1);
	//./flv-rtmp -v -f "/Users/reynoldqin/Downloads/1.flv" -u "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
	_execute_cmd(arg_c, arg_v);
}
