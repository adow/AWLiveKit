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

/// pull 
int pull_flv_file(const char* flv_filename,
		const char* rtmp_url) {
	///aw_log("connect url:%s\n",url);
	if (flv_rtmp_connect(rtmp_url,0)) {
		return -2;
	}
	flv_m_pRtmp -> Link.lFlags  |= RTMP_LF_LIVE;
	flv_m_pRtmp -> Link.timeout = 10;
	RTMP_SetBufferMS(flv_m_pRtmp, 3600 * 1000);
	///aw_log("connected\n");
	FILE *file = fopen(flv_filename, "wb");
	if (!file) {
		aw_log("could not open file:%s",flv_filename);
		return -3;
	}
	/// 用于记录 tag 位置 
	char filename_tag[PATH_MAX] = {'\0'};
	strcpy(filename_tag, flv_filename);
	strcat(filename_tag,".tag");
	FILE *file_tag = fopen(filename_tag,"wb");
	if (!file) {
		aw_log("could not open tag file:%s",filename_tag);
		return -4;
	}
	
	int counter = 0;
    	int limits = 0; /// for test
	/// flv header
	/// signature
	unsigned char signature[3] = {'\0'};
	if (flv_rtmp_read_buf(signature, 3)) return -1;
	aw_log("signature:");
	print_hex_str(signature,3," ", "\n");
	fwrite(signature,1,3,file);
	/// version
	unsigned char version[1] = {'\0'};
	if (flv_rtmp_read_buf(version,1)) return -1;
	aw_log("version:");
	print_hex_str(version,1," ","\n");
	fwrite(version, 1,1,file);
	/// flags
	unsigned char flags[1] = {'\0'};
	if (flv_rtmp_read_buf(flags,1)) return -1;
	aw_log("flags:");
	print_hex_str(flags,1," ","\n");
	fwrite(flags, 1,1,file);
	/// header_size
	uint32_t header_size = 0;
	if (flv_rtmp_read_buf(&header_size,4)) return -1;
	fwrite(&header_size,1,4,file);
	header_size = HTON32(header_size);
	aw_log("header_size:%d\n",header_size);
	while (1) {
        	aw_log("--------------TAG:%d---------------\n",counter);
		/// write tag pos
		long pos = ftell(file);
		//aw_log("this tag will start from:%ld\n",pos);
		//fseek(file_tag, 0, SEEK_SET);
		//fwrite(&pos,sizeof(long),1,file_tag); /// 将当前位置写入到 tag 文件中
		/// previous tag size
		uint32_t previous_tag_size = 0;
		//if (flv_rtmp_read_u32(&previous_tag_size)) return -1;
		if (flv_rtmp_read_buf(&previous_tag_size,4)) return -1;
		fwrite(&previous_tag_size,1,4,file);
		previous_tag_size = HTON32(previous_tag_size);
        	aw_log("previous_tag_size:%d\n",previous_tag_size);
		/// tag header
		uint32_t tag_header_type = 0;
		//if (flv_rtmp_read_u8(&tag_header_type)) return -1;
		if (flv_rtmp_read_buf(&tag_header_type,1)) return -1;
		fwrite(&tag_header_type,1,1,file); 
		aw_log("tag_header_type:%02x\n",tag_header_type); 
		/// tag header data size
		uint32_t tag_header_data_size = 0;
		//if (flv_rtmp_read_u24(&tag_header_data_size)) return -1;
		if (flv_rtmp_read_buf(&tag_header_data_size,3)) return -1;
		fwrite(&tag_header_data_size,1,3,file);
		tag_header_data_size = HTON24(tag_header_data_size);
		aw_log("tag_header_data_size:%d\n",tag_header_data_size);
		/// tag header timestamp
		uint32_t tag_header_timestamp = 0;
		//if (flv_rtmp_read_u24(&tag_header_timestamp)) return -1;
		if (flv_rtmp_read_buf(&tag_header_timestamp,3)) return -1;
		fwrite(&tag_header_timestamp,1,3,file);
		tag_header_timestamp = HTON24(tag_header_timestamp);
		aw_log("tag_header_timestamp:%d\n",tag_header_timestamp);
		/// tag header timestamp_ex
		uint32_t tag_header_timestamp_ex = 0;
		//if (flv_rtmp_read_u8(&tag_header_timestamp_ex)) return -1;
		if (flv_rtmp_read_buf(&tag_header_timestamp_ex,1)) return -1;
		fwrite(&tag_header_timestamp_ex,1,1,file);
		aw_log("tag_header_timestamp_ex:%d\n",tag_header_timestamp_ex);
		/// tag stream id
		uint32_t tag_header_stream_id = 0;
		//if (flv_rtmp_read_u24(&tag_header_stream_id)) return -1;
		if (flv_rtmp_read_buf(&tag_header_stream_id,3)) return -1;
		fwrite(&tag_header_stream_id, 1,3,file);
		tag_header_stream_id = HTON24(tag_header_stream_id);
		aw_log("tag_header_stream_id:%d\n",tag_header_stream_id);
		/// tag body
		unsigned char *tag_data = calloc(tag_header_data_size, sizeof(char));
		if (flv_rtmp_read_buf(tag_data,tag_header_data_size)) return -1;
		print_hex_str(tag_data, tag_header_data_size, " ", "\n");
		fwrite(tag_data,1,tag_header_data_size,file);
        /// 只有视频关键帧的才记录位置
        if (tag_header_type == 0x09) {
            unsigned int video_type = *tag_data;
            if (video_type == 0x17) {
                aw_log("iframe will start from:%ld\n",pos);
                fseek(file_tag, 0, SEEK_SET);
                fwrite(&pos,sizeof(long),1,file_tag); /// 将当前位置写入到 tag 文件中
            }
        }
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

/// 获取外部参数, 执行拉流
int _execute_cmd(int arg_c, char *arg_v[]) {
	char *cmd = arg_v[1];

    char format[] = "f:u:vl::";
    int verbose = 0; /// 显示输出过程
    int ch;
    char flv_filename[PATH_MAX] = {'\0'};
    char rtmp_url[PATH_MAX] = {'\0'};
    char log_filename[PATH_MAX] = {'\0'};
    while ((ch = getopt(arg_c, arg_v, format))!= -1) {
        switch (ch) {
            case 'f':
                strcpy(flv_filename,optarg);
                break;
            case 'u':
                strcpy(rtmp_url,optarg);
                break;
            case 'v':
                verbose = 1;
                break;
	    case 'l':
		strcpy(log_filename,optarg);
		break;
        }
    }
    if (strlen(log_filename) > 0) {
	    set_log_file(log_filename);
    }
    else {
	    set_log_file(NULL);
    }
    aw_log("flv_filename:%s\n",flv_filename);
    aw_log("url:%s\n",rtmp_url);
    aw_log("log_filename:%s\n",log_filename);
    if (!strlen(flv_filename)) {
        aw_log("need -f: filename to receive flv\n");
        return -1;
    }
    if (!strlen(rtmp_url)) {
        aw_log("need -u: url to push rtmp\n");
        return -2;
    }
    
    aw_log("flv-rtmp-pull starts\n");
    return pull_flv_file(flv_filename,rtmp_url); 
}

int main(int arg_c,char *arg_v[]){
	_execute_cmd(arg_c,arg_v);
	return 0;
}
