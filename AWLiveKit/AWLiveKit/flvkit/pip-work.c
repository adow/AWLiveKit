#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

int read_pipline() {
	while(1) {
		
		const size_t buf_size = 1024;
		char buf_read[buf_size] = {'\0'};
		fgets(buf_read,buf_size,stdin);
		
		char buf_write[buf_size] = {'\0'};
		sprintf(buf_write, "working read data from parent:%s",buf_read);	
		fputs(buf_write, stdout);
		
		fflush(stdout);
		sleep(3);
	}	
	return 0;
}
int main(int arg_c,char *arg_v[]){	
	read_pipline();
	return 0;
}
