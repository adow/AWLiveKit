#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <sys/stat.h>

#include "util.h"

FILE *file_log = NULL; /// 输出日志文件，可以更换这个文件

/// 设置日志文件
void set_log_file(const char *filename) {
	if (filename) {
		file_log = fopen(filename,"a");
	}
	else {
		file_log = stdout;
	}
}

/// printf 到指定文件
void aw_log(const char *fmt,...){
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
        aw_log("%02x%s",c,split);
	
    }
    aw_log("%s",end);
    return 0;
}



int int_min(int a,int b){
	return a < b ? a : b;
}
int int_max(int a, int b) {
	return a > b ? a : b;
}

/// 等待多少毫秒
int sleep_ms(uint32_t ms) {
	uint32_t seconds = ms / 1000;
	uint32_t ns = (ms % 1000) * 1000000L;
	/*
	struct timespec wait_time = {0,0.0 * 1000000000L}; ///0.03s
	wait_time.tv_sec = 0;
	wait_time.tv_nsec = ms *1000000L;
	*/
	struct timespec wait_time = {seconds, ns};
	return nanosleep(&wait_time,NULL);
}
