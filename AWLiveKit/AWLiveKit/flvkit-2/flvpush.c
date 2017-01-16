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

int main(int arg_c,char *arg_v[]){
	set_log_file(NULL);
	aw_log("flv-rtmp-push starts");
	return 0;
}
