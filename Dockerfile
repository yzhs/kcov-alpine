FROM alpine:edge as build

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk update && \
    apk add \
        alpine-sdk \
        argp-standalone \
        autoconf \
        automake \
        binutils \
        binutils-dev \
        bison \
        bsd-compat-headers \
        build-base \
        bzip2-dev \
        cmake \
        curl-dev \
        elfutils-dev \
        flex-dev \
        fts \
        fts-dev \
        g++ \
        gcc \
        libtool \
        musl-obstack \
        musl-obstack-dev \
        ninja \
        python \
        wget \
        xz-dev \
        zlib-dev

ENV SRC_DIR=/home/abuild PKG_DIR=/home/abuild/packages

RUN adduser abuild -G abuild; \
    mkdir -p $SRC_DIR/{elfutils,argp-standalone}; \
    sudo -u abuild abuild-keygen -ai

COPY elfutils/* $SRC_DIR/elfutils/
COPY argp-standalone/* $SRC_DIR/argp-standalone/

RUN cd $SRC_DIR/argp-standalone; \
    chown -R abuild: $SRC_DIR; \
    sudo -u abuild abuild && \
    apk add $PKG_DIR/*/*/argp*.apk --allow-untrusted && \
    abuild-sign -k /home/abuild/.abuild/*.rsa $PKG_DIR/*/*/APKINDEX.tar.gz; \
    mv $PKG_DIR /home/abuild/argp
RUN cd $SRC_DIR/elfutils; \
    sudo -u abuild abuild && \
    apk add $PKG_DIR/*/*/elf*.apk --allow-untrusted

RUN cd $SRC_DIR; \
    wget https://github.com/SimonKagstrom/kcov/archive/v36.tar.gz; \
    tar xf v36.tar.gz

RUN cd $SRC_DIR/kcov-36 && \
    mkdir build && \
    cd build && \
    CXXFLAGS="-D__ptrace_request=int" CFLAGS="-D__ptrace_request=int" cmake -G Ninja .. && \
    ninja && \
    ninja install

FROM alpine:edge
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk update && \
    apk add \
        binutils \
        curl \
        flex \
        fts \
        musl-obstack

COPY --from=build /home/abuild/argp/*/* /home/abuild/packages/*/* /home/
COPY --from=build /usr/local/bin/kcov /usr/bin/kcov

RUN apk add /home/*.apk --allow-untrusted

ENTRYPOINT ["/usr/bin/kcov"]
