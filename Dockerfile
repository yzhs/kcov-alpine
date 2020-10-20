FROM alpine:3.12 as build

RUN apk add --repository=http://nl.alpinelinux.org/alpine/edge/main/ binutils binutils-dev
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
            alpine-sdk \
            argp-standalone \
            autoconf \
            automake \
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
            su-exec \
            libtool \
            musl-obstack \
            musl-obstack-dev \
            ninja \
            python3 \
            xz-dev \
            zlib-dev

# abuild won't run as root, so we need to set up a user account.
RUN adduser abuild -G abuild; \
    su-exec abuild abuild-keygen -ai

ENV VERSION=37 SRC_DIR=/home/abuild PKG_DIR=/home/abuild/packages

COPY elfutils/* $SRC_DIR/elfutils/
COPY argp-standalone/* $SRC_DIR/argp-standalone/

# We need a version of argp-standalone compiled with -fPIC for buildign the
# full elfutils project.
WORKDIR $SRC_DIR/argp-standalone
RUN chown -R abuild: $SRC_DIR; \
    su-exec abuild abuild && \
    apk add $PKG_DIR/*/*/argp*.apk --allow-untrusted && \
    abuild-sign -k /home/abuild/.abuild/*.rsa $PKG_DIR/*/*/APKINDEX.tar.gz; \
    mv $PKG_DIR /home/abuild/argp

# The packaged version of elfutils does not include libdw which kcov links
# against, so we have to build a custom version.
WORKDIR $SRC_DIR/elfutils
RUN su-exec abuild abuild && \
    apk add $PKG_DIR/*/*/elf*.apk --allow-untrusted


WORKDIR $SRC_DIR
RUN curl -L https://github.com/SimonKagstrom/kcov/archive/v$VERSION.tar.gz \
    | tar xzC $SRC_DIR/ && \
    mkdir kcov-$VERSION/build && \
    cd kcov-$VERSION/build && \
    CXXFLAGS="-D__ptrace_request=int" cmake -G Ninja .. && \
    ninja && \
    ninja install


# Build a small image containing just the obligatory parts.
FROM alpine:3.12
RUN apk add --no-cache --repository=http://nl.alpinelinux.org/alpine/edge/main/ binutils curl

COPY --from=build /home/abuild/argp/*/* /home/abuild/packages/*/* /home/
COPY --from=build /usr/local/bin/kcov /usr/bin/kcov
