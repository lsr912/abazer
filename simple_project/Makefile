OBJS = file1.o file2.o main.o
CC = gcc
DEFS =
INCLUDES =
CPPFLAGS =
CFLAGS =
COMPILE = $(CC) -c $(DEFS) $(INCLUDES) $(CPPFLAGS) $(CFLAGS)
LINK = $(CC) $(LDFLAGS) -o $@

.SUFFIXES:
.SUFFIXES: .c .o
.c.o:
	$(COMPILE) $<

test: $(OBJS)
	$(LINK) $(OBJS)

clean:
	rm *.o


