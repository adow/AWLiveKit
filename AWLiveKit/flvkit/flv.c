#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#define LOG_MAX_LINE 2048 ///每行日志的最大长度
#define LOG_BUFFER_MAX 2048000 ///printf时的最大长度

#define HTON16(x)  ((x>>8&0xff)|(x<<8&0xff00))  
#define HTON24(x)  ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00))  
#define HTON32(x)  ((x>>24&0xff)|(x>>8&0xff00)|(x<<8&0xff0000)|(x<<24&0xff000000))  
#define HTONTIME(x) ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00)|(x&0xff000000))  

/*read 1 byte*/  
int ReadU8(uint32_t *u8,FILE*fp){  
         if(fread(u8,1,1,fp)!=1)  
                   return 0;  
         return 1;  
}  
/*read 2 byte*/  
int ReadU16(uint32_t *u16,FILE*fp){  
         if(fread(u16,2,1,fp)!=1)  
                   return 0;  
         *u16=HTON16(*u16);  
         return 1;  
}  
/*read 3 byte*/  
int ReadU24(uint32_t *u24,FILE*fp){  
         if(fread(u24,3,1,fp)!=1)  
                   return 0;  
         *u24=HTON24(*u24);  
         return 1;  
}  
/*read 4 byte*/  
int ReadU32(uint32_t *u32,FILE*fp){  
         if(fread(u32,4,1,fp)!=1)  
                   return 0;  
         *u32=HTON32(*u32);  
         return 1;  
}  
/*read 1 byte,and loopback 1 byte at once*/  
int PeekU8(uint32_t *u8,FILE*fp){  
         if(fread(u8,1,1,fp)!=1)  
                   return 0;  
         fseek(fp,-1,SEEK_CUR);  
         return 1;  
}  

/*read 4 byte and convert to time format*/  
int ReadTime(uint32_t *utime,FILE*fp){  
         if(fread(utime,4,1,fp)!=1)  
                   return 0;  
         *utime=HTONTIME(*utime);  
         return 1;  
}  

void print_bin(int n)
{
    int l = sizeof(n)*8;//总位数。
    int i;
    if(i == 0)
    {
         printf("0");
         return;
     }
    for(i = l-1; i >= 0; i --)//略去高位0.
    {
        if(n&(1<<i)) break;
    }
 
    for(;i>=0; i --)
        printf("%d", (n&(1<<i)) != 0);
}

void printfln(const char *fmt,...){
	va_list ap;
	va_start(ap,fmt);
	static char buf[LOG_BUFFER_MAX]={'\0'};
	memset(buf,0,LOG_BUFFER_MAX);
	vsnprintf(buf,LOG_BUFFER_MAX-1,fmt,ap);
	va_end(ap);
	printf("%s\n",buf);
	fflush(NULL);
}

unsigned git_bits(unsigned x, int p, int n) {
    return (x >> (p + 1 - n)) & ~ (~0 << n);
}

int print_flv_file_hex(const char *filename) {
    FILE *f = fopen(filename, "rb");
    int c;
    int counter = 0;
    int limits = 100;
    while ((c = fgetc(f)) != EOF) {
        //printfln("%02x",c);
        printf("%02x",c);
        if ((++counter) % 2 == 0) {
            printf(" ");
        }
        if ((counter) % 16 == 0) {
            printf("\n");
        }
        if (limits && counter >= limits) {
            break;
        }
    }
    fclose(f);
    printf("\n");
    return 0;
}
int print_hex_str(const unsigned char *s, size_t n, 
        const char *split,
        const char *end) {
    for (int a = 0;a<n;a++) {
        int c = *(s + a);
        printf("%02x%s",c,split);
    }
    printf("%s",end);
    return 0;
}

int print_flv_file_tag(const char *filename) {
    FILE *f = fopen(filename, "rb");
    int c;
    int counter = 0;
    int limits = 10;
    // flv header
    unsigned char signature[4] = {'\0'};
    fgets((char *)signature,4,f);
    printf("signature:%s\n",signature);
    printf("signature:");
    print_hex_str(signature,3,"","\n");

    unsigned char version[2] = {'\0'};
    fgets((char *)version,2,f);
    printf("version:");
    print_hex_str(version,1,"","\n");

    unsigned char flags[2] = {'\0'};
    fgets((char *)flags,2,f);
    printf("flags:");
    print_hex_str(flags,1,"","\n");

    uint32_t header_size = 0;
    fread(&header_size,1,4,f);
    header_size = HTON32(header_size); 
    printf("header_size:%d\n",header_size);
    /// flv body
    while (1) {
        printf("--------------TAG:%d---------------\n",counter);
        /// previous tag size
        uint32_t previous_tag_size = 0;
        ReadU32(&previous_tag_size,f);
        printf("previous_tag_size:%d\n",previous_tag_size);
        /// tag header
        uint32_t tag_header_type = 0;
        ReadU8(&tag_header_type,f);
        printf("tag_header_type:%02x\n",tag_header_type); 
        /// tag header data size
        uint32_t tag_header_data_size = 0;
        ReadU24(&tag_header_data_size,f);
        printf("tag_header_data_size:%d\n",tag_header_data_size);
        /// tag header timestamp
        uint32_t tag_header_timestamp = 0;
        ReadU24(&tag_header_timestamp,f);
        printf("tag_header_timestamp:%d\n",tag_header_timestamp);
        /// tag header timestamp_ex
        uint32_t tag_header_timestamp_ex = 0;
        ReadU8(&tag_header_timestamp_ex,f);
        printf("tag_header_timestamp_ex:%d\n",tag_header_timestamp_ex);
        /// tag stream id
        uint32_t tag_header_stream_id = 0;
        ReadU24(&tag_header_stream_id,f);
        printf("tag_header_stream_id:%d\n",tag_header_stream_id);
        /// tag body
        unsigned char *tag_data = calloc(tag_header_data_size,sizeof(char));
        fread(tag_data, 1,tag_header_data_size,f);
        ///
        if (tag_header_type == 0x08) {
            unsigned int audio_tag_data_meta = *tag_data;
            printf("audio tag_data_meta:%02x\n",audio_tag_data_meta);
            print_hex_str(tag_data ,tag_header_data_size ,"","\n");
        }
        else if (tag_header_type == 0x09) {
            unsigned int video_tag_data_meta = *tag_data;
            printf("video tag_tag_data_meta:%02x\n",video_tag_data_meta);
            print_hex_str(tag_data ,tag_header_data_size ,"","\n");
        }
        else if (tag_header_type == 0x12) {
            print_hex_str(tag_data,tag_header_data_size,"","\n");
        }
        free(tag_data);
        ///
        if (limits && (++counter) >= limits) {
            break;
        }
    }
    return 0;
};

int main(int arg_c,char *arg_v[]){
    /*
    printfln("0x27 >> 4:%d",0x27 >> 4);
    printfln("0x17 >> 4:%d",0x17 >> 4);
    printfln("0xaf >> 4:%d",0xaf >> 4);
    printfln("0x27 << 4:%d",0x27 << 4);
    printfln("0x17 << 4:%d",0x17 << 4);
    printfln("%x%x",0x27,0xaf);
    print_bin(0xaf);
    */
    //print_flv_file_hex("/Users/reynoldqin/Downloads/1.flv");
    print_flv_file_tag("/Users/reynoldqin/Downloads/1.flv");
	return 0;
}
