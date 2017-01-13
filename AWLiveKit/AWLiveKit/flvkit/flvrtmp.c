#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "../rtmp/rtmp.h"

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

int flv_rtmp_connect(const char *url,int write);
void flv_rtmp_close();
int flv_rtmp_send_data(unsigned char *data, uint32_t size, 
        uint32_t timestamp,uint8_t type);

int fd = -1; /// flv 文件
char filename[PATH_MAX] = {'\0'};
//const char *filename = "./test.txt";
//const char *filename = "/Users/reynoldqin/Downloads/1.flv";
//const char *filename = "/Users/reynoldqin/Downloads/1.flv";
char url[PATH_MAX] = {'\0'};
//const char *url = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84";
//const char *url = "rtmp://m.push.wifiwx.com:1935/live/wifiwx-239";

FILE *file_log = NULL; /// 输出日志文件，可以更换这个文件

/// printf 到指定文件
void flv_rtmp_printf(const char *fmt,...){
	va_list ap;
	va_start(ap,fmt);
	vfprintf(file_log,fmt,ap);
	va_end(ap);
}

/// util
int print_hex_str(const unsigned char *s, size_t n, 
        const char *split,
        const char *end) {
    for (int a = 0; a < n; a++) {
        int c = *(s + a);
        //printf("%02x%s",c,split);
        flv_rtmp_printf("%02x%s",c,split);
	
    }
    //printf("%s",end);
    flv_rtmp_printf("%s",end);
    return 0;
}

#define HTON16(x)  ((x>>8&0xff)|(x<<8&0xff00))  
#define HTON24(x)  ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00))  
#define HTON32(x)  ((x>>24&0xff)|(x>>8&0xff00)|(x<<8&0xff0000)|(x<<24&0xff000000))  
#define HTONTIME(x) ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00)|(x&0xff000000))

/// flv_file
int flv_file_open() {
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

int flv_file_read_buf(void *buf, size_t size) {
	/// 以安全的方式读取文件内容，读取足够多内容, 如果没有读满指定长度的内容，会重复打开文件后再次读取
	if (fd == -1) {
		if (flv_file_open()) {
			return -1;
		}
	}
	size_t read_next = size;
	while (1) {
		void *input = malloc(read_next);
		memset(input, '\0', read_next);
		ssize_t len = read(fd, input, read_next);
		//printf("read:%ld/%ld\n",len, read_next);
		//flv_rtmp_printf("read:%ld/%ld\n",len, read_next);
		if (len == read_next) {
			//print_hex_str(input,read_next," ","\n");
			//printf("%s\n",input);
			//flv_rtmp_printf("%s\n",input);
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
			flv_rtmp_printf("read not enough:%ld,%ld\n",read_next, len);
			read_next = read_next - len;
			if (flv_file_open()) {
				return -1;
			}
		}
		else {
			free(input);
			flv_rtmp_printf("read to the end of file\n");
			if (flv_file_open()) {
				return -1;
			}
		}
		//fflush(stdout);
	}
	return 0;
}

int flv_file_read_u8(uint32_t *u8) {
	if (flv_file_read_buf(u8, 1)) {
		return -1;
	}
	return 0;
}
int flv_file_read_u16(uint32_t *u16) {
	if (flv_file_read_buf(u16, 2)) {
		return -1;
	}
	*u16 = HTON16(*u16);
	return 0;
}
int flv_file_read_u24(uint32_t *u24) {
	if (flv_file_read_buf(u24, 3)) {
		return -1;
	}
	*u24 = HTON24(*u24);
	return 0;
}
int flv_file_read_u32(uint32_t *u32) {
	if (flv_file_read_buf(u32, 4)) {
		return -1;
	}
	*u32 = HTON32(*u32);
	return 0;
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
			flv_rtmp_printf("read not enough:%ld/%ld", len, read_next);
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

/// push
int push_flv_file(int verbose) {
	if (flv_rtmp_connect(url,1)) {
		return -2;
	}
	int c;
    	int counter = 0;
    	int limits = 0;
	/// flv header
	/// signautre
	unsigned char signature[4] = {'\0'};
	if (flv_file_read_buf(signature, 3)) {
		return -1;
	}
	flv_rtmp_printf("signature:%s\n",signature);
	print_hex_str(signature, 4, " ","\n");
	/// version
	unsigned char version[2] = {'\0'};
	if (flv_file_read_buf(version,1)) {
		return -1;
	}
	flv_rtmp_printf("version:\n");
	print_hex_str(version,2," ", "\n");
	/// flags
	unsigned char flags[2] = {'\0'};
	if (flv_file_read_buf(flags,1)) {
		return -1;
	}
	flv_rtmp_printf("flags:\n");
	print_hex_str(flags,2," ", "\n");
	/// header_size
	uint32_t header_size = 0;
	if (flv_file_read_u32(&header_size)) {
		return -1;
	}
	flv_rtmp_printf("header_size:%d\n",header_size);

	/// flv body
	while (1) {
        	flv_rtmp_printf("--------------TAG:%d---------------\n",counter);
		/// previous tag size
		uint32_t previous_tag_size = 0;
		if (flv_file_read_u32(&previous_tag_size)) return -1;
        	flv_rtmp_printf("previous_tag_size:%d\n",previous_tag_size);
		/// tag header
		uint32_t tag_header_type = 0;
		if (flv_file_read_u8(&tag_header_type)) return -1;
		flv_rtmp_printf("tag_header_type:%02x\n",tag_header_type); 
		/// tag header data size
		uint32_t tag_header_data_size = 0;
		if (flv_file_read_u24(&tag_header_data_size)) return -1;
		flv_rtmp_printf("tag_header_data_size:%d\n",tag_header_data_size);
		/// tag header timestamp
		uint32_t tag_header_timestamp = 0;
		if (flv_file_read_u24(&tag_header_timestamp)) return -1;
		flv_rtmp_printf("tag_header_timestamp:%d\n",tag_header_timestamp);
		/// tag header timestamp_ex
		uint32_t tag_header_timestamp_ex = 0;
		if (flv_file_read_u8(&tag_header_timestamp_ex)) return -1;
		flv_rtmp_printf("tag_header_timestamp_ex:%d\n",tag_header_timestamp_ex);
		/// tag stream id
		uint32_t tag_header_stream_id = 0;
		if (flv_file_read_u24(&tag_header_stream_id)) return -1;
		flv_rtmp_printf("tag_header_stream_id:%d\n",tag_header_stream_id);
		/// tag body
		unsigned char *tag_data = calloc(tag_header_data_size, sizeof(char));
		if (flv_file_read_buf(tag_data,tag_header_data_size)) return -1;
		if (verbose) {
			print_hex_str(tag_data, tag_header_data_size, " ", "\n");
		}
		/// audio
		if (tag_header_type == 0x08) {
			flv_rtmp_printf("audio tag\n");
			flv_rtmp_send_data(tag_data, tag_header_data_size,
                    		tag_header_timestamp,RTMP_PACKET_TYPE_AUDIO);
		}
		/// video
		else if (tag_header_type == 0x09) {
			flv_rtmp_printf("video tag\n");
			flv_rtmp_send_data(tag_data, tag_header_data_size,
                    		tag_header_timestamp,RTMP_PACKET_TYPE_VIDEO);
		}
		/// script
		else if (tag_header_type == 0x12) {
			flv_rtmp_printf("script tag, skipped\n");
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
    	flv_rtmp_printf("RTMP Closed\n");	
	return 0;
}

/// receive
int receive_flv_file() {
	///flv_rtmp_printf("connect url:%s\n",url);
	if (flv_rtmp_connect(url,0)) {
		return -2;
	}
	flv_m_pRtmp -> Link.lFlags  |= RTMP_LF_LIVE;
	flv_m_pRtmp -> Link.timeout = 10;
	RTMP_SetBufferMS(flv_m_pRtmp, 3600 * 1000);
	///flv_rtmp_printf("connected\n");
	FILE *file = fopen(filename, "wb");
	if (!file) {
		flv_rtmp_printf("could not open file:%s",filename);
		return -3;
	}
	/// 用于记录 tag 位置 
	const char* filename_tag = strcat(filename,".tag");
	FILE *file_tag = fopen(filename_tag,"wb");
	if (!file) {
		flv_rtmp_printf("could not open tag file:%s",filename_tag);
		return -4;
	}
	
	int counter = 0;
    	int limits = 0; /// for test
	/// flv header
	/// signature
	unsigned char signature[3] = {'\0'};
	if (flv_rtmp_read_buf(signature, 3)) return -1;
	flv_rtmp_printf("signature:");
	print_hex_str(signature,3," ", "\n");
	fwrite(signature,1,3,file);
	/// version
	unsigned char version[1] = {'\0'};
	if (flv_rtmp_read_buf(version,1)) return -1;
	flv_rtmp_printf("version:");
	print_hex_str(version,1," ","\n");
	fwrite(version, 1,1,file);
	/// flags
	unsigned char flags[1] = {'\0'};
	if (flv_rtmp_read_buf(flags,1)) return -1;
	flv_rtmp_printf("flags:");
	print_hex_str(flags,1," ","\n");
	fwrite(flags, 1,1,file);
	/// header_size
	uint32_t header_size = 0;
	if (flv_rtmp_read_buf(&header_size,4)) return -1;
	fwrite(&header_size,1,4,file);
	header_size = HTON32(header_size);
	flv_rtmp_printf("header_size:%d\n",header_size);
	while (1) {
        	flv_rtmp_printf("--------------TAG:%d---------------\n",counter);
		long pos = ftell(file);
		flv_rtmp_printf("this tag will start from:%ld\n",pos);
		fwrite(&pos,sizeof(long),1,file_tag); /// 将当前位置写入到 tag 文件中
		/// previous tag size
		uint32_t previous_tag_size = 0;
		//if (flv_rtmp_read_u32(&previous_tag_size)) return -1;
		if (flv_rtmp_read_buf(&previous_tag_size,4)) return -1;
		fwrite(&previous_tag_size,1,4,file);
		previous_tag_size = HTON32(previous_tag_size);
        	flv_rtmp_printf("previous_tag_size:%d\n",previous_tag_size);
		/// tag header
		uint32_t tag_header_type = 0;
		//if (flv_rtmp_read_u8(&tag_header_type)) return -1;
		if (flv_rtmp_read_buf(&tag_header_type,1)) return -1;
		fwrite(&tag_header_type,1,1,file); 
		flv_rtmp_printf("tag_header_type:%02x\n",tag_header_type); 
		/// tag header data size
		uint32_t tag_header_data_size = 0;
		//if (flv_rtmp_read_u24(&tag_header_data_size)) return -1;
		if (flv_rtmp_read_buf(&tag_header_data_size,3)) return -1;
		fwrite(&tag_header_data_size,1,3,file);
		tag_header_data_size = HTON24(tag_header_data_size);
		flv_rtmp_printf("tag_header_data_size:%d\n",tag_header_data_size);
		/// tag header timestamp
		uint32_t tag_header_timestamp = 0;
		//if (flv_rtmp_read_u24(&tag_header_timestamp)) return -1;
		if (flv_rtmp_read_buf(&tag_header_timestamp,3)) return -1;
		fwrite(&tag_header_timestamp,1,3,file);
		tag_header_timestamp = HTON24(tag_header_timestamp);
		flv_rtmp_printf("tag_header_timestamp:%d\n",tag_header_timestamp);
		/// tag header timestamp_ex
		uint32_t tag_header_timestamp_ex = 0;
		//if (flv_rtmp_read_u8(&tag_header_timestamp_ex)) return -1;
		if (flv_rtmp_read_buf(&tag_header_timestamp_ex,1)) return -1;
		fwrite(&tag_header_timestamp_ex,1,1,file);
		flv_rtmp_printf("tag_header_timestamp_ex:%d\n",tag_header_timestamp_ex);
		/// tag stream id
		uint32_t tag_header_stream_id = 0;
		//if (flv_rtmp_read_u24(&tag_header_stream_id)) return -1;
		if (flv_rtmp_read_buf(&tag_header_stream_id,3)) return -1;
		fwrite(&tag_header_stream_id, 1,3,file);
		tag_header_stream_id = HTON24(tag_header_stream_id);
		flv_rtmp_printf("tag_header_stream_id:%d\n",tag_header_stream_id);
		/// tag body
		unsigned char *tag_data = calloc(tag_header_data_size, sizeof(char));
		if (flv_rtmp_read_buf(tag_data,tag_header_data_size)) return -1;
		print_hex_str(tag_data, tag_header_data_size, " ", "\n");
		fwrite(tag_data,1,tag_header_data_size,file);
		free(tag_data);
		///
		fflush(stdout);
		fflush(stderr);
		///
		++counter;
		if (limits && counter >= limits) {
		    break;
		}
	}
	///
	fclose(file);
	fclose(file_tag);
	flv_rtmp_close();
	return 0;
}

int receive_flv_file_simple() {
	if (flv_rtmp_connect(url,0)) {
		return -2;
	}
	flv_m_pRtmp -> Link.lFlags  |= RTMP_LF_LIVE;
	flv_m_pRtmp -> Link.timeout = 10;
	RTMP_SetBufferMS(flv_m_pRtmp, 3600 * 1000);
	///flv_rtmp_printf("connected\n");
	FILE *file = fopen(filename, "wb");
	if (!file) {
		flv_rtmp_printf("could not open file:%s",filename);
		return -1;
	}
	const size_t buf_size = 1024 * 10;
	char buf[buf_size] = {'\0'};
	size_t read = 0;
	size_t total = 0;
	while ((read = RTMP_Read(flv_m_pRtmp,buf,buf_size))) {
		fwrite(buf,1,read, file);
		total += read;
		flv_rtmp_printf("Receive:%lu, total:%lu\n",read, total);
		fflush(stdout);
	}
	fclose(file);
	flv_rtmp_close();
	return 0;

}

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
        flv_rtmp_printf("Set URL Failed");
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
        flv_rtmp_printf("Connect RTMP Failed");
        RTMP_Free(flv_m_pRtmp);
        return -2;
    }
    
    /*连接流*/
    if (RTMP_ConnectStream(flv_m_pRtmp,0) == false)
    {
        flv_rtmp_printf("Connect Stream Failed");
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
        flv_rtmp_printf("body is null\n");
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
        flv_rtmp_printf("rtmp send failed");
    }
    return result; 
}


/// 获取外部参数, 执行推流
int _execute_cmd(int arg_c, char *arg_v[]) {
	char *cmd = arg_v[1];

    char format[] = "f:u:v";
    int verbose = 0; /// 显示输出过程
    int ch;
    arg_c -=1;
    arg_v += 1;
    flv_rtmp_printf("cmd:%s\n",cmd);
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
        }
    }
    flv_rtmp_printf("flv_filename:%s\n",filename);
    flv_rtmp_printf("url:%s\n",url);
    if (!strlen(filename)) {
        flv_rtmp_printf("need -f: filename to flv\n");
        return -1;
    }
    if (!strlen(url)) {
        flv_rtmp_printf("need -u: url to push rtmp\n");
        return -2;
    }
    if (!strcmp(cmd,"push")) {
	return push_flv_file(verbose);
    }
    else if (!strcmp(cmd,"receive")) {		
	return receive_flv_file();
	//return receive_flv_file_simple();
    }
    else {
	flv_rtmp_printf("unknown cmd:%s",cmd);
	return -3;
    }
    return 0;
}


/// test

/// main
int main(int arg_c,char *arg_v[]){	
	file_log = stdout;
	//file_log = fopen("./flvrtmp.log","a");
	//push_flv_file(1);
	// ./flv-rtmp -v -f "/Users/reynoldqin/Downloads/1.flv" -u "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
	// ./flv-rtmp -v -f "/Users/reynoldqin/Downloads/3.flv" -u "rtmp://m.push.wifiwx.com:1935/live/wifiwx-239"

	_execute_cmd(arg_c, arg_v);
	return 0;
}
