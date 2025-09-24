CC      := gcc
CFLAGS  ?=
LDFLAGS ?=
LDLIBS  ?= -lcurl    # ← 追加：curlライブラリにリンク

all: hello

hello: hello.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LDLIBS)

clean:
	rm -f hello

