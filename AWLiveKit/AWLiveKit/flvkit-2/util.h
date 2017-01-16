#ifndef util_h
#define util_h
#define HTON16(x)  ((x>>8&0xff)|(x<<8&0xff00))  
#define HTON24(x)  ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00))  
#define HTON32(x)  ((x>>24&0xff)|(x>>8&0xff00)|(x<<8&0xff0000)|(x<<24&0xff000000))  
#define HTONTIME(x) ((x>>16&0xff)|(x<<16&0xff0000)|(x&0xff00)|(x&0xff000000))

void set_log_file(const char *filename);
void aw_log(const char *fmt,...);
int print_hex_str(const unsigned char *s, size_t n, 
        const char *split,
        const char *end);
int int_min(int a,int b);
int int_max(int a, int b);
#endif
