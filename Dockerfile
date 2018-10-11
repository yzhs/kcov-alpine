FROM alpine:edge

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk update && \
    apk add alpine-sdk binutils binutils-dev cmake curl-dev elfutils-dev g++ \
            gcc ninja wget zlib-dev build-base bison flex-dev zlib-dev \
            bzip2-dev xz-dev argp-standalone bsd-compat-headers autoconf \
            automake libtool fts fts-dev musl-obstack-dev musl-obstack

ENV SRC_DIR=/home/kcov-src PKG_DIR=/home/guest/packages

RUN mkdir -p $SRC_DIR/elfutils /home/guest; \
    chown -R guest:root /home/guest; \
    addgroup guest abuild; \
    HOME=/home/guest sudo -Eu guest abuild-keygen -ai

COPY elfutils/* $SRC_DIR/elfutils/
COPY argp-standalone/* $SRC_DIR/argp-standalone/

RUN cd $SRC_DIR; \
    chown -R guest:root elfutils argp-standalone

RUN cd $SRC_DIR/argp-standalone; \
    HOME=/home/guest sudo -Eu guest abuild && \
    apk add $PKG_DIR/*/*/argp*.apk --allow-untrusted && \
    abuild-sign -k /home/guest/.abuild/*.rsa $PKG_DIR/*/*/APKINDEX.tar.gz; \
    rm -r $PKG_DIR
RUN cd $SRC_DIR/elfutils; \
    HOME=/home/guest sudo -Eu guest abuild && \
    apk add $PKG_DIR/*/*/elf*.apk --allow-untrusted

RUN cd $SRC_DIR; \
    wget https://github.com/SimonKagstrom/kcov/archive/v36.tar.gz; \
    tar xf v36.tar.gz

RUN apk add python

RUN cd $SRC_DIR/kcov-36 && \
    mkdir build && \
    cd build && \
    CXXFLAGS="-D__ptrace_request=int" CFLAGS="-D__ptrace_request=int" cmake -G Ninja .. && \
    ninja && \
    ninja install

ENTRYPOINT ["kcov"]
CMD ["--help"]

