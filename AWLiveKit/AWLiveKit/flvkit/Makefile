SOURCES = \
	  ../rtmp/amf.c \
	  ../rtmp/log.c \
	  ../rtmp/parseurl.c \
	  ../rtmp/rtmp.c \
	  flv.c

OUTPUT = flv.out 

$(OUTPUT) : $(SOURCES)
	gcc -o $(OUTPUT) $(SOURCES) -g
	chmod +x $(OUTPUT)

.PHONY: clean 
clean:
	-rm -f *.o *.out $(OUTPUT)
	-rm -rf *.dSYM/
