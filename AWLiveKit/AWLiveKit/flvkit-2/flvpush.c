#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/un.h>   
#include <time.h>

#include "util.h"
#include "flvrtmp.h"

/// 通信的模式
#define FLV_RTMP_PUSH_RUN_MODE_PIPLINE 'P'
#define FLV_RTMP_PUSH_RUN_MODE_SOCKET 'S'
#define FLV_RTMP_PUSH_RUN_MODE_FILE 'F'

/// 打开推流文件的位置
#define FLV_RTMP_FILE_OPEN_POSITION_START 'S'
#define FLV_RTMP_FILE_OPEN_POSITION_CUR 'C'
#define FLV_RTMP_FILE_OPEN_POSITION_TAG 'T'

char flv_filename[PATH_MAX] = {'\0'};
char rtmp_url[PATH_MAX] = {'\0'};
char flv_fd = -1;

int FLV_RTMP_PUSH_FLV_HEADER_SENT = 0; /// flv header 是否已经发送
int FLV_RTMP_PUSH_CONNECTED = 0; /// rtmp 是否已经连接

/// read flv file
int flv_file_open_position(char position) {
	/// 从开始位置打开文件,'S' 开始位置，'C' 当前位置，'T' Tag 文件位置
	if (position == FLV_RTMP_FILE_OPEN_POSITION_START) {
		if (flv_fd != -1 ) {
			close(flv_fd);
			flv_fd = -1;
		}
		flv_fd = open(flv_filename, O_RDONLY);
		if (flv_fd == -1) {
			return -1;
		}
		lseek(flv_fd, 0, SEEK_SET);
		return 0;
	}
	else if (position == FLV_RTMP_FILE_OPEN_POSITION_CUR) {
		sleep(1);/// 打开当前位置前先等 1s
		off_t pos = lseek(flv_fd, 0, SEEK_CUR);
		if (flv_fd != -1) {
			close(flv_fd);
			flv_fd = -1;
		}
		flv_fd = open(flv_filename, O_RDONLY);
		if (flv_fd == -1) {
			return -1;
		}
		lseek(flv_fd, pos,SEEK_SET);
		return 0;

	}	
	else if (position == FLV_RTMP_FILE_OPEN_POSITION_TAG) {
		if (flv_fd != -1) {
			close(flv_fd);
			flv_fd = -1;
		}
		char filename_tag[PATH_MAX] = {'\0'};
		strcpy(filename_tag,flv_filename);
		///  获取到 tag 文件中的定位数据
		strcat(filename_tag,".tag");
		long pos = 0;
		FILE *file_tag = fopen(filename_tag,"r");
		if (file_tag) {
			fread(&pos,sizeof(long),1,file_tag);
		}
		fclose(file_tag);
		//aw_log("tag pos:%ld\n",pos);
		aw_log("tag pos:%ld\n",pos);
		flv_fd = open(flv_filename, O_RDONLY);
		if (flv_fd == -1) {
			return -1;
		}
		lseek(flv_fd, pos,SEEK_SET);
		return 0;
	}	
	return -2;
}

int flv_file_read_buf(void *buf, size_t size) {
	/// 以安全的方式读取文件内容，读取足够多内容, 如果没有读满指定长度的内容，会重复打开文件后再次读取
	if (flv_fd == -1) {
		if (flv_file_open_position('S')) {
			return -1;
		}
	}
	size_t read_next = size;
	while (1) {
		void *input = malloc(read_next);
		memset(input, '\0', read_next);
		ssize_t len = read(flv_fd, input, read_next);
		//printf("read:%ld/%ld\n",len, read_next);
		//aw_log("read:%ld/%ld\n",len, read_next);
		if (len == read_next) {
			//print_hex_str(input,read_next," ","\n");
			//printf("%s\n",input);
			//aw_log("%s\n",input);
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
			aw_log("read not enough:%ld,%ld\n",read_next, len);
			read_next = read_next - len;
			if (flv_file_open_position('C')) {
				return -1;
			}
		}
		else {
			free(input);
			aw_log("read to the end of file\n");
			if (flv_file_open_position('C')) {
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

/// push
int read_cmd(int fd, 
		char *cmd_name, int *cmd_name_len, 
		char *cmd_value, int *cmd_value_len) {
	const int cmd_buf_size = 1024;
	char buf[cmd_buf_size] = {'\0'};
	int len = read(fd, buf, cmd_buf_size);
	aw_log("read:%s,%d\n",buf,len);
	if (len == -1) {
		aw_log("read cmd error\n");
		return -1;
	}
	else if (len == 0) {
		return 0;
	}
	else {
		aw_log("cmd:%s\n",buf);
		char *p_buf = buf;
		for(p_buf = buf;p_buf < buf + len; p_buf++) {
			//aw_log("%s\n",p_buf);
			//continue;
			/// find :
			if (*p_buf == ':') {
				/// cmd_name
				*cmd_name_len = p_buf - buf;
				strncpy(cmd_name, buf, *cmd_name_len);	
				/// cmd_value
				*cmd_value_len = len - *cmd_name_len - 2;
				strncpy(cmd_value, p_buf + 1, *cmd_value_len);
				break;
			}

		}	
		return len;
	}
}

int _do_push_flv_file(int counter) {
	/// connect rtmp
	if (!FLV_RTMP_PUSH_CONNECTED) {
		aw_log("connecting url:%s\n",rtmp_url);
		if (flv_rtmp_connect(rtmp_url,1)) {
			return -2;
		}
		FLV_RTMP_PUSH_CONNECTED = 1;
	}
	/// 没有指定文件
	if (!strcmp(flv_filename,"")) {
		aw_log("no filename, skipped\n");
		return -3;
	}
	/// flv 文件头
	if (!FLV_RTMP_PUSH_FLV_HEADER_SENT) {
		aw_log("flv header has not been sent\n");
		//这时会重新定位到文件开头
		flv_file_open_position(FLV_RTMP_FILE_OPEN_POSITION_START);
		/// flv header
		/// signautre
		unsigned char signature[4] = {'\0'};
		if (flv_file_read_buf(signature, 3)) {
			return -1;
		}
		aw_log("signature:%s\n",signature);
		print_hex_str(signature, 4, " ","\n");
		/// version
		unsigned char version[2] = {'\0'};
		if (flv_file_read_buf(version,1)) {
			return -1;
		}
		aw_log("version:\n");
		print_hex_str(version,2," ", "\n");
		/// flags
		unsigned char flags[2] = {'\0'};
		if (flv_file_read_buf(flags,1)) {
			return -1;
		}
		aw_log("flags:\n");
		print_hex_str(flags,2," ", "\n");
		/// header_size
		uint32_t header_size = 0;
		if (flv_file_read_u32(&header_size)) {
			return -1;
		}
		aw_log("header_size:%d\n",header_size);

		FLV_RTMP_PUSH_FLV_HEADER_SENT = 1;
	}
	/// flv body
	/// previous tag size
	uint32_t previous_tag_size = 0;
	if (flv_file_read_u32(&previous_tag_size)) return -4;
	aw_log("previous_tag_size:%d\n",previous_tag_size);
	/// tag header
	uint32_t tag_header_type = 0;
	if (flv_file_read_u8(&tag_header_type)) return -5;
	aw_log("tag_header_type:%02x\n",tag_header_type); 
	/// tag header data size
	uint32_t tag_header_data_size = 0;
	if (flv_file_read_u24(&tag_header_data_size)) return -6;
	aw_log("tag_header_data_size:%d\n",tag_header_data_size);
	/// tag header timestamp
	uint32_t tag_header_timestamp = 0;
	if (flv_file_read_u24(&tag_header_timestamp)) return -7;
	aw_log("tag_header_timestamp:%d\n",tag_header_timestamp);
	/// tag header timestamp_ex
	uint32_t tag_header_timestamp_ex = 0;
	if (flv_file_read_u8(&tag_header_timestamp_ex)) return -8;
	aw_log("tag_header_timestamp_ex:%d\n",tag_header_timestamp_ex);
	/// tag stream id
	uint32_t tag_header_stream_id = 0;
	if (flv_file_read_u24(&tag_header_stream_id)) return -9;
	aw_log("tag_header_stream_id:%d\n",tag_header_stream_id);
	/// tag body
	unsigned char *tag_data = calloc(tag_header_data_size, sizeof(char));
	if (flv_file_read_buf(tag_data,tag_header_data_size)) return -1;
	print_hex_str(tag_data, tag_header_data_size, " ", "\n");
	/// audio
	if (tag_header_type == 0x08) {
		aw_log("audio tag\n");
		flv_rtmp_send_data(tag_data, tag_header_data_size,
			tag_header_timestamp,RTMP_PACKET_TYPE_AUDIO);
	}
	/// video
	else if (tag_header_type == 0x09) {
		aw_log("video tag\n");
		flv_rtmp_send_data(tag_data, tag_header_data_size,
			tag_header_timestamp,RTMP_PACKET_TYPE_VIDEO);
	}
	/// script
	else if (tag_header_type == 0x12) {
		aw_log("script tag, skipped\n");
	}

	free(tag_data);
	return 0;
}

int flv_push_loop(char mode) {
	// 文件推送循环，在每个循环中会尝试读取外部的命令 
	aw_log("push_flv_file_loop will start,mode:%c\n",mode);
	/// 通信方式
	if (mode == FLV_RTMP_PUSH_RUN_MODE_SOCKET) { /// socket
	}
	else if (mode == FLV_RTMP_PUSH_RUN_MODE_PIPLINE) { /// pipline
	}
	else if (mode == FLV_RTMP_PUSH_RUN_MODE_FILE) { /// file
	}
	//flv_file_open_position('S'); /// 开始的时候就打开文件一次
	int counter = 0;
	int limits = 0;	
	fd_set read_set;
	fd_set write_set;
	struct timeval timeout={0,0};
	struct timespec wait_time = {0,1.0 * 1000000000L}; ///0.03s
	wait_time.tv_sec = 0;
	wait_time.tv_nsec = 10 *1000000L;
	//wait_time.tv_nsec = 3000 *1000000L;
	const size_t cmd_buf_size = 1024;
	while(1) {
		aw_log("-----------LOOP:%d----------\n",counter);	
		///  cmd
		int max_fd = 0;
		if (mode == FLV_RTMP_PUSH_RUN_MODE_PIPLINE) {
			FD_ZERO(&read_set);
			FD_ZERO(&write_set);
			FD_SET(STDIN_FILENO,&read_set);
			FD_SET(STDOUT_FILENO, &write_set);
			max_fd = int_max(STDIN_FILENO,STDOUT_FILENO) + 1;
		}
		int ret = select(max_fd, &read_set, &write_set,NULL,&timeout);
		if (ret == -1) {
			aw_log("select error\n");
			return -1;
		}
		else if (ret == 0) {
			aw_log("not available\n");
		}
		else {
			aw_log("%d available\n",ret);
			if (FD_ISSET(STDIN_FILENO,&read_set)) {
				aw_log("read stdin available\n");	
				/// analysis cmd
				char cmd_name[cmd_buf_size] = {'\0'};
				char cmd_value[cmd_buf_size] = {'\0'};
				int cmd_name_len = 0;
				int cmd_value_len = 0;
				if (read_cmd(STDIN_FILENO, 
						cmd_name, &cmd_name_len,
						cmd_value,&cmd_value_len) > 0) {
					/// cmd 
					aw_log("cmd_name:%s,%d\n",cmd_name,cmd_name_len);
					aw_log("cmd_value:%s,%d\n",cmd_value,cmd_value_len);
					/// change filename
					if (!strcmp(cmd_name,"push-set-filename")) {
						/// 修改现在的文件名
						memset(flv_filename,'\0',PATH_MAX);		
						strncpy(flv_filename,cmd_value,
								cmd_value_len);
						aw_log("filename has been changed:%s\n",flv_filename);
						flv_file_open_position('T');/// 使用 tag 文件打开文件位置


					}
				}
			}
			if (FD_ISSET(STDOUT_FILENO,&write_set)) {
				aw_log("write stdout available\n");
			}
		}
		/// push flv file
		int push_result = _do_push_flv_file(counter);
		/*
		if (push_result) {
			aw_log("push failed:%d\n",push_result);
			break;
		}
		*/
		///
		++counter;
		if (limits && counter >= limits) {
		    break;
		}
		//sleep(3);
		nanosleep(&wait_time,NULL);
	}
	return 0;
}



/// 获取外部参数, 执行拉流
int _execute_cmd(int arg_c, char *arg_v[]) {
	char *cmd = arg_v[1];

    char format[] = "f::u:vl::";
    int verbose = 0; /// 显示输出过程
    int ch;
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
    
    if (!strlen(rtmp_url)) {
        aw_log("need -u: url to push rtmp\n");
        return -2;
    }
    
    aw_log("flv-rtmp-push starts\n");
    return flv_push_loop('P');
}
int main(int arg_c,char *arg_v[]){
	_execute_cmd(arg_c, arg_v);
	return 0;
}
