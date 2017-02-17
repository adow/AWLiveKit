SOURCES_PULL = \
	  ../rtmp/amf.c \
	  ../rtmp/log.c \
	  ../rtmp/parseurl.c \
	  ../rtmp/rtmp.c \
	  util.c \
	  flvrtmp.c \
	  flvpull.c

OUTPUT_PULL = flv-rtmp-pull

$(OUTPUT_PULL) : $(SOURCES_PULL)
	gcc -o $(OUTPUT_PULL) $(SOURCES_PULL) -g
	chmod +x $(OUTPUT_PULL)

SOURCES_PUSH = \
	  ../rtmp/amf.c \
	  ../rtmp/log.c \
	  ../rtmp/parseurl.c \
	  ../rtmp/rtmp.c \
	  util.c \
	  flvrtmp.c \
	  flvpush.c

OUTPUT_PUSH = flv-rtmp-push

$(OUTPUT_PUSH) : $(SOURCES_PUSH)
	gcc -o $(OUTPUT_PUSH) $(SOURCES_PUSH) -g
	chmod +x $(OUTPUT_PUSH)

.PHONY: clean 
clean:
	-rm -f *.o *.out $(OUTPUT_PULL) $(OUTPUT_PUSH)
	-rm -rf *.dSYM/
