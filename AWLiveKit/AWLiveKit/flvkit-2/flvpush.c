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
#include <sys/socket.h>

#include "util.h"
#include "flvrtmp.h"

/// 打开推流文件的位置
#define FLV_RTMP_FILE_OPEN_POSITION_START 'S'
#define FLV_RTMP_FILE_OPEN_POSITION_CUR 'C'
#define FLV_RTMP_FILE_OPEN_POSITION_TAG 'T'

/// do_cmd 的返回结果
#define CMD_RESULT_SUCCEED_CONTINUE 0 
#define CMD_RESULT_SUCCEED_COMPLETE 1
#define CMD_RESULT_SUCCEED_ERROR -1

char flv_filename[PATH_MAX] = {'\0'};
char rtmp_url[PATH_MAX] = {'\0'};
char flv_fd = -1;

int FLV_RTMP_PUSH_FLV_HEADER_SENT = 0; /// flv header 是否已经发送
int FLV_RTMP_PUSH_CONNECTED = 0; /// rtmp 是否已经连接

#define UNIX_DOMAIN "/tmp/flv-rtmp-push"
int socket_listen_fd = -1; ///服务器
int socket_com_fd = -1; ///连接
fd_set cmd_read_set; /// 读入
fd_set cmd_write_set; ///写入
struct timeval cmd_timeout = {0,0}; /// select 超时时间
const size_t cmd_buf_size = 1024; /// 命令最大长度
char waiting_cmd_name[cmd_buf_size] = {'\0'}; /// 下一个要运行的命令名字
char waiting_cmd_value[cmd_buf_size] = {'\0'}; /// 下一个要运行的命令参数

uint32_t last_timestamp_video = 0; /// 上一个音频帧的时间戳
uint32_t last_timestamp_audio = 0; /// 上一个视频帧的时间戳
uint32_t last_time_video = 0; /// 上一个视频处理的时间
uint32_t last_time_audio = 0; /// 上一个音频处理的时间
uint32_t last_keyframe_timestamp = 0; /// 上一个视频关键帧的时间戳
uint32_t last_keyframe_time = 0; /// 上一个视频关键帧的处理时间

const uint32_t max_keyframe_timestamp_duration = 2000; /// 两个关键帧之间的时间距离

/// 在用 rtmp 发送的时候，不使用 flv tag 中的时间戳，而是用这个累计的时间戳
uint32_t push_timestamp_audio = 0;
uint32_t push_timestamp_video = 0;


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

struct flv_tag {
	uint32_t previous_tag_size;
	uint32_t tag_header_type;
	uint32_t tag_header_data_size;
	uint32_t tag_header_timestamp;
	uint32_t tag_header_timestamp_ex;
	uint32_t tag_header_stream_id;
	unsigned char *tag_data;
	int is_video_tag;
	int is_audio_tag;
	int is_script_tag;
	int is_video_key_frame;
};

/// 读取文件中一个 tag 段
int flv_file_read_tag(struct flv_tag *tag){
	/// previous tag size
	uint32_t previous_tag_size = 0;
	if (flv_file_read_u32(&previous_tag_size)) return -4;
	aw_log("previous_tag_size:%d\n",previous_tag_size);
	tag->previous_tag_size = previous_tag_size;
	/// tag header
	uint32_t tag_header_type = 0;
	if (flv_file_read_u8(&tag_header_type)) return -5;
	aw_log("tag_header_type:%02x\n",tag_header_type); 
	tag->tag_header_type = tag_header_type;
	/// tag header data size
	uint32_t tag_header_data_size = 0;
	if (flv_file_read_u24(&tag_header_data_size)) return -6;
	aw_log("tag_header_data_size:%d\n",tag_header_data_size);
	tag->tag_header_data_size = tag_header_data_size;
	/// tag header timestamp
	uint32_t tag_header_timestamp = 0;
	if (flv_file_read_u24(&tag_header_timestamp)) return -7;
	aw_log("tag_header_timestamp:%d\n",tag_header_timestamp);
	tag->tag_header_timestamp = tag_header_timestamp;
	/// tag header timestamp_ex
	uint32_t tag_header_timestamp_ex = 0;
	if (flv_file_read_u8(&tag_header_timestamp_ex)) return -8;
	aw_log("tag_header_timestamp_ex:%d\n",tag_header_timestamp_ex);
	tag->tag_header_timestamp_ex = tag_header_timestamp_ex;
	/// tag stream id
	uint32_t tag_header_stream_id = 0;
	if (flv_file_read_u24(&tag_header_stream_id)) return -9;
	aw_log("tag_header_stream_id:%d\n",tag_header_stream_id);
	tag->tag_header_stream_id = tag_header_stream_id;
	/// tag body
	unsigned char *tag_data = calloc(tag_header_data_size, sizeof(char));
	if (flv_file_read_buf(tag_data,tag_header_data_size)) return -1;
	tag->tag_data = tag_data;
	/// tag type
	tag->is_script_tag = tag_header_type == 0x12;
	tag->is_audio_tag = tag_header_type == 0x08;
	tag->is_video_tag = tag_header_type == 0x09;
	/// is_video_key_frame
	if (tag->is_video_tag) {
		unsigned int video_type = *tag_data;
		tag->is_video_key_frame = video_type == 0x17;
	}

	return tag_header_data_size;
}
void flv_file_release_tag(struct flv_tag *tag) {
	free(tag->tag_data);
}

/// cmd
/// 是否有命令正在运行
int cmd_is_waiting() {
	if (strlen(waiting_cmd_name) > 0 || strlen(waiting_cmd_value) > 0 ) {
		return 1;
	}
	else {
		return 0;
	}
}
//// 清空正在运行的命令和参数
int cmd_clear() {
	memset(waiting_cmd_name,'\0',cmd_buf_size);
	memset(waiting_cmd_value,'\0',cmd_buf_size);
	return 0;
}
/// 读取新的命令，如果还有命令在执行就不要读取
int read_cmd(int fd) {
	char buf[cmd_buf_size] = {'\0'};
	int len = read(fd, buf, cmd_buf_size);
	aw_log("read (%d):%s",len,buf);
	if (len == -1) {
		aw_log("read cmd error\n");
		return -1;
	}
	else if (len == 0) {
		return 0;
	}
	else {
		/// 还有命令在运行的时候，不要再次读取新的命令
		if (cmd_is_waiting()) {
			aw_log("command is waiting for running, skip this read\n");
			aw_log("\t%s:%s\n",waiting_cmd_name,waiting_cmd_value);
			return -2;		
		}
		aw_log("cmd:%s",buf);
		char *p_buf = buf;
		for(p_buf = buf;p_buf < buf + len; p_buf++) {
			//aw_log("%s\n",p_buf);
			//continue;
			/// find :
			if (*p_buf == ':') {
				/// cmd_name
				size_t cmd_name_len = p_buf - buf; /// 命令部分长度
				strncpy(waiting_cmd_name, 
						buf, 
						cmd_name_len);	
				/// cmd_value
				size_t cmd_value_len = len - cmd_name_len - 2; /// 命令参数部分长度
				strncpy(waiting_cmd_value, 
						p_buf + 1,  /// 要 : 后面一个开始
						cmd_value_len);
				break;
			}

		}	
		return len;
	}
}

/// 执行正在等待的命令, 返回
/// 0: 运行成功，继续后面操作;
/// 1: 运行成功，但是不要继续操作;
/// -1: 运行错误;
int do_cmd() {
	if (!cmd_is_waiting()) {
		return 0;
	}
	aw_log("will run command:%s:%s\n", waiting_cmd_name, waiting_cmd_value);
	/// 执行修改文件命令
	if (!strcmp(waiting_cmd_name,"push-set-filename")) {
		/// 修改现在的文件名
		memset(flv_filename,'\0',PATH_MAX);		
		strcpy(flv_filename, waiting_cmd_value);
		aw_log("filename has been changed:%s\n",flv_filename);
		flv_file_open_position('T');/// 使用 tag 文件打开文件位置
		/// 重置以下数字
		last_time_audio = 0;
		last_timestamp_audio = 0;
		last_time_video = 0;
		last_timestamp_video = 0;
		last_keyframe_time = 0;
		last_keyframe_timestamp = 0;
		cmd_clear(); /// 清空命令
		//push_timestamp_audio += 23;
		//push_timestamp_video += 67;
		return 1; /// 返回后他将跳过后续操作，继续后面的循环
	}
	else {
		aw_log("unknown command\n");
		return 0;
	}
}

/// socket 
int start_socket() {
    socklen_t clt_addr_len;  
    int ret;  
    int i;  
    static char recv_buf[cmd_buf_size];   
    socklen_t len;  
    struct sockaddr_un clt_addr;  
    struct sockaddr_un srv_addr;  
    socket_listen_fd = socket(PF_UNIX,SOCK_STREAM,0);  
    if(socket_listen_fd < 0)  
    {  
        aw_log("cannot create communication socket\n");  
        return -1;  
    }    
    //set server addr_param  
    srv_addr.sun_family=AF_UNIX;  
    strncpy(srv_addr.sun_path,UNIX_DOMAIN,sizeof(srv_addr.sun_path)-1);  
    unlink(UNIX_DOMAIN);  
    //bind sockfd & addr  
    ret=bind(socket_listen_fd,(struct sockaddr*)&srv_addr,sizeof(srv_addr));  
    if(ret==-1)  
    {  
        aw_log("cannot bind server socket\n");  
        close(socket_listen_fd);  
        unlink(UNIX_DOMAIN);  
        return -2;  
    }  
    aw_log("binded\n");
    //listen sockfd   
    ret=listen(socket_listen_fd,1);  
    if(ret==-1)  
    {  
        aw_log("cannot listen the client connect request\n");  
        close(socket_listen_fd);  
        unlink(UNIX_DOMAIN);  
        return -3;  
    }  
    aw_log("listening at:%s\n",UNIX_DOMAIN);
    return 0;
}

/// 处理每个轮询中的命令输入
int _select_cmd() {
	///  cmd
	int max_fd = 0;
	FD_ZERO(&cmd_read_set);
	FD_ZERO(&cmd_write_set);
	FD_SET(STDIN_FILENO,&cmd_read_set); /// 接收管道输入
	FD_SET(socket_listen_fd, &cmd_read_set); /// 接收 socket 输入
	max_fd = int_max(STDIN_FILENO,socket_listen_fd);
	/// 如果有连接将等待他发来消息
	if (socket_com_fd != -1) {
		FD_SET(socket_com_fd, &cmd_read_set);
		max_fd = int_max(max_fd, socket_com_fd);
	}
	FD_SET(STDOUT_FILENO, &cmd_write_set);
	max_fd = int_max(max_fd, STDOUT_FILENO);
	max_fd += 1;
	int ret = select(max_fd, &cmd_read_set, &cmd_write_set,NULL,&cmd_timeout);
	if (ret == -1) {
		aw_log("select error\n");
		return -1;
	}
	else if (ret == 0) {
		aw_log("not available\n");
		return 0;
	}
	else {
		aw_log("%d available\n",ret);
		if (FD_ISSET(STDIN_FILENO,&cmd_read_set)) { /// 管道输入
			aw_log("pipline command arrived\n");	
			if (read_cmd(STDIN_FILENO) > 0) {
				aw_log("waiting_cmd_name:%s\n",waiting_cmd_name);
				aw_log("waiting_cmd_value:%s\n",waiting_cmd_value);
			}
		}
		if (FD_ISSET(socket_listen_fd,&cmd_read_set)) { /// 新的客户端连接, 将在后面接收数据
			aw_log("new connection available\n");
			struct sockaddr_un clt_addr;
			socklen_t len=sizeof(clt_addr);  
			socket_com_fd = accept(socket_listen_fd,
					(struct sockaddr*)&clt_addr,
					&len);  
			if(socket_com_fd < 0){  
				perror("cannot accept client connect request\n");  
			}
		}
		if (socket_com_fd != -1 && 
				FD_ISSET(socket_com_fd, &cmd_read_set)) {
			/// 有客户端发来消息,拆分消息
			aw_log("socket command arrived\n");
			if (read_cmd(socket_com_fd) > 0) {
				aw_log("waiting_cmd_name:%s\n",waiting_cmd_name);
				aw_log("waiting_cmd_value:%s\n",waiting_cmd_value);
			}	
		}
		if (FD_ISSET(STDOUT_FILENO,&cmd_write_set)) {
			aw_log("write stdout available\n");
		}
		return 0;
	}
}

/// push
int _do_push_flv_file(int counter,
		uint32_t *wait_ms, /// 下面需要等待的时间
		int *keyframe) {
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
	uint32_t now_time = RTMP_GetTime();
	struct flv_tag tag;
	if (flv_file_read_tag(&tag) > 0) {
		if (tag.is_script_tag) {
			aw_log("script tag\n");	
		}
		else if (tag.is_audio_tag) {
			aw_log("audio tag\n");
			/// 计算上一个音频帧之间的间隔时间，他们之间要间隔 21 ms
			uint32_t audio_duration = now_time - last_time_audio; /// 距离上一个帧的处理时间
			/// 当切换文件后，last_timestamp_audio = 0,下一个文件的时间距离就按照 22 ms 计算；否则就按两个时间戳继续计算
			uint32_t audio_timestamp_duration = tag.tag_header_timestamp - last_timestamp_audio; /// 距离上一个音频帧的距离
			if (last_time_audio > 0) {
				push_timestamp_audio += audio_timestamp_duration;	
			}
			if (audio_duration < audio_timestamp_duration) {
				*wait_ms = audio_timestamp_duration - audio_duration;
			}
			else {
				*wait_ms = 0;
			}
			aw_log("now_timestamp:%ld,last_timestamp:%ld,timestamp_duration:%ld\n",
					tag.tag_header_timestamp,
					last_timestamp_audio,
					audio_timestamp_duration);
			aw_log("now_time:%ld,last_time:%ld,audio_duration:%ld\n",
					now_time,
					last_time_audio,
					audio_duration);
			aw_log("wait_ms:%ld\n",*wait_ms);
			last_timestamp_audio = tag.tag_header_timestamp;
			last_time_audio = now_time;
			sleep_ms(*wait_ms);
			/*
			if (tag.tag_header_timestamp == 0) {
				push_timestamp_audio = 0;
			}
			else if (tag.tag_header_timestamp == 10) {
				push_timestamp_audio = 10;
			}
			else {
				push_timestamp_audio += 23;
			}
			*/
			aw_log("push_timestamp_audio:%ld,tag_timestamp:%ld\n",push_timestamp_audio,tag.tag_header_timestamp);
			/// send
			flv_rtmp_send_data(tag.tag_data, 
				tag.tag_header_data_size,
				tag.tag_header_timestamp,
				//push_timestamp_audio,
				RTMP_PACKET_TYPE_AUDIO);
		}
		else if (tag.is_video_tag) {
			aw_log("video_tag:%d\n",tag.is_video_key_frame);
			*keyframe = tag.is_video_key_frame;
			if (tag.is_video_key_frame) {
				/// 开始执行命令
				int cmd_result = do_cmd();	
				/// 只有返回 0 的时候才继续下面的操作
				if (!cmd_result) {	
					/// 两个关键帧之间的时间间隔要保持在一个距离
					/// 切换之后就使用一个默认的下一帧时间戳
					/// 切换之后用一个默认的时间戳累加,否则就用两帧之间的时间累加
					if (last_timestamp_video > 0) {
						uint32_t video_timestamp_duration = tag.tag_header_timestamp - last_timestamp_video;
						push_timestamp_video += video_timestamp_duration;
					}
					uint32_t keyframe_duration = now_time - last_keyframe_time;
					uint32_t keyframe_timestamp_duration = 
						tag.tag_header_timestamp - last_keyframe_timestamp;
					/// 实际用时比关键帧的时间戳距离小
					/*	
					if (keyframe_duration < keyframe_timestamp_duration) {
						*wait_ms = keyframe_timestamp_duration - keyframe_duration;
					}
					*/
					/// 两个关键帧之间的间隔应该通过他们的时间戳来确定，以此来确定这一个关键帧需要等待的时间，但是实际上有些关键这之间没有 2000 ms， 只有几百，这还是会导致播放 rtmp 时的卡顿（原因是 srs 上面服务器的 shrink the cache queue, size=0, removed=2157, max=30.00），只有固定两帧之间 2000 ms 的值才能让 rtmp 播放正常。
					/// 以下代码虽然尝试用两个关键帧实际戳来作为判断等待的依据，但是实际还是用 2000 ms 来作为参照。
					if (keyframe_duration < max_keyframe_timestamp_duration) {
						*wait_ms = max_keyframe_timestamp_duration - keyframe_duration;
					}
					else {
						*wait_ms = 0;
					}
					aw_log("keyframe_timestamp:%ld,last_keyframe_timestamp:%ld,keyframe_timestamp_duration:%ld\n",
							tag.tag_header_timestamp,
							last_keyframe_timestamp,
							keyframe_timestamp_duration);
					aw_log("keyframe_time:%ld,last_keyframe_time:%ld, keyframe_duration:%ld\n",
							now_time,
							last_keyframe_time,
							keyframe_duration);
					last_keyframe_time = now_time;	/// 记录上一次关键帧时间
					last_keyframe_timestamp = tag.tag_header_timestamp; /// 记录上一个关键帧的时间戳
				}
				else {
					*wait_ms = 2000;
				}
			}
			else {
				/// 计算上一个视频的间隔时间，他们之间要间隔 40ms
				uint32_t video_duration = now_time - last_time_video;
				uint32_t video_timestamp_duration = tag.tag_header_timestamp - last_timestamp_video;
				/// 切换之后用一个默认的时间戳累加,否则就用两帧之间的时间累加
				if (last_timestamp_video > 0) {
					push_timestamp_video += video_timestamp_duration;
				}
				if (video_duration < video_timestamp_duration ) {
					*wait_ms = video_timestamp_duration - video_duration;
				}
				else {
					*wait_ms = 0;
				}
				aw_log("now_timestamp:%ld,last_timestamp:%ld,timestamp_duration:%ld\n",
						tag.tag_header_timestamp,
						last_timestamp_video,
						video_timestamp_duration);
				aw_log("now_time:%ld,last_time:%ld,video_duration:%ld\n",
						now_time,
						last_time_video,
						video_duration);
			}
			aw_log("wait_ms:%ld\n",*wait_ms);
			last_timestamp_video = tag.tag_header_timestamp; /// 记录上一次时间戳
			last_time_video = now_time; /// 记录上一次视频帧处理时间
			sleep_ms(*wait_ms);
			aw_log("push_timestamp_video:%ld,tag_timestamp:%ld\n",push_timestamp_video,tag.tag_header_timestamp);
			/// send
			flv_rtmp_send_data(tag.tag_data, 
				tag.tag_header_data_size,
				tag.tag_header_timestamp,
				//push_timestamp_video,
				RTMP_PACKET_TYPE_VIDEO);
		}
	}
	else {
		aw_log("read flv tag failed\n");
	}
	flv_file_release_tag(&tag);
	return 0;
}

int flv_push_loop() {
	// 文件推送循环，在每个循环中会尝试读取外部的命令 
	aw_log("push_flv_file_loop will start\n");
	start_socket();
	//flv_file_open_position('S'); /// 开始的时候就打开文件一次
	int counter = 0;
	int limits = 0;	 /// just test
	fd_set read_set;
	fd_set write_set;
	struct timeval timeout={0,0};
	const size_t cmd_buf_size = 1024;
	while(1) {
		aw_log("-----------LOOP:%d----------\n",counter);	
		uint32_t start_time = RTMP_GetTime();
		_select_cmd(); /// 从 socket, pipline 中获取命令参数
		int keyframe = 0; /// 这一次推送的是否是关键帧
		/// push flv file
		uint32_t wait_ms = 10;
		int push_result = _do_push_flv_file(counter,
				 &wait_ms,
				 &keyframe);
		if (push_result) {
			aw_log("push failed:%d\n",push_result);
			//break;
		}
		///
		//sleep_ms(3000); /// wait 1s
		++counter;
		if (limits && counter >= limits) {
		    break;
		}
		///
		uint32_t end_time = RTMP_GetTime();
		aw_log("LOOP start_time:%ld,end_time:%ld, duration:%ld,keyframe:%d\n",
				start_time,
				end_time,
				end_time - start_time,
				keyframe);
		
	}
	return 0;
}


/// execute
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
    return flv_push_loop();
}
int main(int arg_c,char *arg_v[]){
	_execute_cmd(arg_c, arg_v);
	return 0;
}
