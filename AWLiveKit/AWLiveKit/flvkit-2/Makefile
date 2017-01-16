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

.PHONY: clean 
clean:
	-rm -f *.o *.out $(OUTPUT_PULL)
	-rm -rf *.dSYM/
