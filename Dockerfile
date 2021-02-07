FROM alpine as builder

ENV BITCOIN_VER 0.21.0
ENV DB_VER 4.8.30.NC

# Install dependencies for Berkelay DB
RUN apk --no-cache add autoconf automake build-base

# https://www.oracle.com/technetwork/jp/products/berkeleydb/downloads/index-090620-ja.html
COPY db-$DB_VER.tar.gz db-$DB_VER.tar.gz
RUN tar xzf db-4.8.30.NC.tar.gz &&\
        cd db-$DB_VER/build_unix &&\
        sed s/__atomic_compare_exchange/__db_atomic_compare_exchange/ -i ../dbinc/atomic.h &&\
        ../dist/configure --prefix=/usr/local --enable-cxx --disable-shared --with-pic &&\
        make && make install

# Install dependencies for bitcoin-core
RUN apk --no-cache add\
        build-base\
        autoconf\
        automake\
        libtool\
        chrpath\
        libevent-dev\
        boost-dev

# https://github.com/bitcoin/bitcoin
COPY v$BITCOIN_VER.tar.gz v$BITCOIN_VER.tar.gz
RUN tar xzf v$BITCOIN_VER.tar.gz
WORKDIR bitcoin-$BITCOIN_VER
RUN ./autogen.sh &&\
        LDFLAGS=-L/usr/local/lib CPPFLAGS=-I/usr/local/include ./configure\
        --prefix=/bitcoin\
        --mandir=/usr/share/man\
        --disable-tests\
        --disable-ccache\
        --disable-zmq\
        --with-gui=no\
        --with-utils\
        --with-libs\
        --with-daemon &&\
        make &&\
        make install

FROM alpine as bitcoin
COPY --from=builder /bitcoin /bitcoin

RUN apk --no-cache add libevent boost

RUN mkdir -p /bitcoin/data &&\
        addgroup -S bitcoin &&\
        adduser -SDH -G bitcoin bitcoin &&\
        chown bitcoin:bitcoin /bitcoin/data

USER bitcoin
WORKDIR /bitcoin

EXPOSE 8333 18333 18444 8332 18332 18443
VOLUME /bitcoin/data
ENTRYPOINT /bitcoin/bin/bitcoind -datadir=/bitcoin/data
