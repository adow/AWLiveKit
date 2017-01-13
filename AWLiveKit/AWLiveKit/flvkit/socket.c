#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#include <sys/socket.h>  
#include <sys/un.h>   
#include <sys/select.h>
#include <poll.h>
#define UNIX_DOMAIN "/tmp/flv-rtmp" 

int min(int a,int b){
	return a < b ? a : b;
}
int int_max(int a, int b) {
	return a > b ? a : b;
}

int run_server() {
    socklen_t clt_addr_len;  
    int ret;  
    int i;  
    static char recv_buf[1024];   
    socklen_t len;  
    struct sockaddr_un clt_addr;  
    struct sockaddr_un srv_addr;  
    int listen_fd=socket(PF_UNIX,SOCK_STREAM,0);  
    if(listen_fd<0)  
    {  
        perror("cannot create communication socket");  
        return -1;  
    }    
    //set server addr_param  
    srv_addr.sun_family=AF_UNIX;  
    strncpy(srv_addr.sun_path,UNIX_DOMAIN,sizeof(srv_addr.sun_path)-1);  
    unlink(UNIX_DOMAIN);  
    //bind sockfd & addr  
    ret=bind(listen_fd,(struct sockaddr*)&srv_addr,sizeof(srv_addr));  
    if(ret==-1)  
    {  
        perror("cannot bind server socket");  
        close(listen_fd);  
        unlink(UNIX_DOMAIN);  
        return -2;  
    }  
    printf("binded\n");
    //listen sockfd   
    ret=listen(listen_fd,1);  
    if(ret==-1)  
    {  
        perror("cannot listen the client connect request");  
        close(listen_fd);  
        unlink(UNIX_DOMAIN);  
        return -3;  
    }  
    printf("listening\n");
    /// select
    fd_set read_set;
    fd_set write_set;
    printf("selecting\n");
    struct timeval timeout={0,0}; 
    while(1) {
	    FD_ZERO(&read_set);
	    FD_ZERO(&write_set);
	    FD_SET(listen_fd,&read_set);
	    int max_fd = listen_fd + 1;
	    int ret = select(max_fd, &read_set, &write_set, NULL,&timeout);
	    if (ret == -1){
		    printf("select error\n");
		    return -1;
	    }
	    else if (ret == 0) {
		    printf("not available\n");
	    }
	    else {
		    printf("%d available\n",ret);
	    }
	    fflush(stdout);
	    sleep(1);
    } 
    /*
    //have connect request use accept  
    len=sizeof(clt_addr);  
    int com_fd=accept(listen_fd,(struct sockaddr*)&clt_addr,&len);  
    if(com_fd<0)  
    {  
        perror("cannot accept client connect request");  
        close(listen_fd);  
        unlink(UNIX_DOMAIN);  
        return 1;  
    }  
    //read and printf sent client info  
    printf("/n=====info=====/n");  
    fflush(stdout);
    for(i=0;i<4;i++)  
    {  
        memset(recv_buf,0,1024);  
        int num=read(com_fd,recv_buf,sizeof(recv_buf));  
        printf("Message from client (%d)) :%s\n",num,recv_buf);    
    }  
    close(com_fd);  
    close(listen_fd);  
    unlink(UNIX_DOMAIN); 
    */
    return 0;
}

int run_client() {
    int connect_fd;  
    int ret;  
    char snd_buf[1024];  
    int i;  
    static struct sockaddr_un srv_addr;  
    //creat unix socket  
    connect_fd=socket(PF_UNIX,SOCK_STREAM,0);  
    if(connect_fd<0)  
    {  
        perror("cannot create communication socket");  
        return -1;  
    }     
    srv_addr.sun_family=AF_UNIX;  
    strcpy(srv_addr.sun_path,UNIX_DOMAIN);  
    //connect server  
    ret=connect(connect_fd,(struct sockaddr*)&srv_addr,sizeof(srv_addr));  
    if(ret==-1)  
    {  
        perror("cannot connect to the server");  
        close(connect_fd);  
        return -2;  
    }  
    printf("connected\n");
    fflush(stdout);
    ///
    memset(snd_buf,0,1024);  
    strcpy(snd_buf,"message from client");  
    //send info server  
    for(i=0;i<4;i++)  
        write(connect_fd,snd_buf,sizeof(snd_buf));  
    close(connect_fd);  
    return 0;
}

int _execute_cmd(int arg_c, char *arg_v[]) {
	char *cmd = arg_v[1];
    if (!strcmp(cmd,"server")) {
        return run_server();
    }
    else if (!strcmp(cmd,"client")) {
        return run_client();
    }
    else {
        printf("unknown cmd:%s\n",cmd);
        return -9;
    }
}

int main(int arg_c,char *arg_v[]){
    //run_server();
    _execute_cmd(arg_c, arg_v);
    return 0;    
}
