CC = clang
CFLAGS=-Wall -Wextra -Werror -std=c99 -g

objects=msfss.o

.PHONY: all
all: msfss

msfss: $(objects)
	$(CC) $(CFLAGS) $(objects) -o msfss

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf msfss
	rm -rf *.o
