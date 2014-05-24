#!/bin/bash

# check if we can build 32bits binaries
cat > /tmp/conftest.c << _LT_EOF
int main() { return 0;}
_LT_EOF
gcc -m32 /tmp/conftest.c -o /tmp/conftest > /dev/null 2>&1
can32bits=$?
rm /tmp/conftest.c /tmp/conftest 2> /dev/null


MACHINE_TYPE=`uname -m`
if [ ${MACHINE_TYPE} == 'x86_64' ]; then
    destarchs="64"
    if [[ ${can32bits} -eq 0 ]]; then
	destarchs="64 32"
    fi
else
    destarchs="32"
fi

for destarch in $destarchs; do

    gccopts="-Wl,-Bstatic -m${destarch} -O2 -pipe -Iinclude -Llibs -Bstatic \
	-Wall -Wno-trigraphs -fno-strict-aliasing -fno-common -ggdb -Wl,-Bdynamic"

    ## quarrantined options:
    ## "-fPIC" (only works for shared libraries, not used)
    ## useful options:
    ## "-O2" to enable optimizations
    ## "-ggdb" to enable debug symbols
    ## "-DDEBUG_LOG -DDEBUG_MEM" to enable debuging of memory allocation
    ## unknown what they do, even if the are used "-DGETHOSTBYNAME -DGETSERVBYNAME"

    if [[ ! -f libs/libdebug${destarch}.a ]]; then
	gcc $gccopts -c -o obj/log${destarch}.o src/libdebug/log.c
	gcc $gccopts -c -o obj/memory${destarch}.o src/libdebug/memory.c
	gcc $gccopts -c -o obj/hex${destarch}.o src/libdebug/hex.c
	ar crv libs/libdebug${destarch}.a obj/log${destarch}.o obj/memory${destarch}.o obj/hex${destarch}.o > /dev/null
    fi

    if [[ ! -f libs/libconfig${destarch}.a ]]; then
	gcc $gccopts -c -o obj/scan${destarch}.o src/libconfig/scan.c
	gcc $gccopts -c -o obj/parse${destarch}.o src/libconfig/parse.c
	gcc $gccopts -c -o obj/config${destarch}.o src/libconfig/config.c
	ar crv libs/libconfig${destarch}.a obj/scan${destarch}.o obj/parse${destarch}.o obj/config${destarch}.o > /dev/null
    fi

    if [[ ! -f libs/libz${destarch}.a ]]; then
	pushd . > /dev/null
	rm -r 3rdparty/tmp/zlib-1.2.8 2> /dev/null
	mkdir 3rdparty/tmp/ 2> /dev/null
	tar xzf 3rdparty/zlib-1.2.8.tar.gz --directory 3rdparty/tmp/

	DESTDIR=`pwd`/3rdparty/tmp/
	cd $DESTDIR/zlib-1.2.8
        CFLAGS="-m${destarch}" ./configure --static > /tmp/build${destarch}.log 2>&1
        make install DESTDIR=$DESTDIR >> /tmp/build${destarch}.log 2>&1
	popd > /dev/null
	cp $DESTDIR/usr/local/lib/libz.a libs/libz${destarch}.a
    fi

    if [[ ! -f libs/libcurl${destarch}.a ]]; then
	pushd . > /dev/null
	rm -r 3rdparty/tmp/curl-7.30.0 2> /dev/null
	mkdir 3rdparty/tmp/ 2> /dev/null
	tar xjf 3rdparty/curl-7.30.0.tar.bz2 --directory 3rdparty/tmp/

	DESTDIR=`pwd`/3rdparty/tmp/
	cd $DESTDIR/curl-7.30.0
	export CFLAGS="-m${destarch}"
	./configure --enable-static --without-libidn --disable-shared --disable-ssl \
	    --disable-ipv6 --disable-rtsp --disable-dict --disable-gopher --disable-https \
	    --disable-telnet --disable-smtp --disable-smtps --disable-imap --disable-imaps \
	    --disable-pop3 --disable-pop3s --disable-ftps --without-ssl --without-polarssl \
	    --disable-ldap --disable-ldaps --disable-debug --disable-ntlm-wb \
	    --disable-tls-srp --prefix=/usr/local/${destarch} >> /tmp/build${destarch}.log 2>&1
	make install DESTDIR=$DESTDIR >> /tmp/build${destarch}.log 2>&1
        popd > /dev/null
	cp $DESTDIR/usr/local/${destarch}/lib/libcurl.a libs/libcurl${destarch}.a
    fi

    rnopts="-lm -ldl -lpthread -static-libgcc \
	-lconfig${destarch} -ldebug${destarch} \
	-lcurl${destarch} -lz${destarch} -lrt \
	-DLINUX -I3rdparty/tmp/usr/local/${destarch}/include"

    rncfiles="src/asterix.c src/sacsic.c src/helpers.c \
	src/startup.c src/crc32.c src/red_black_tree.c \
	src/red_black_tree_misc.c src/red_black_tree_stack.c \
	src/md5.c"

    gcc $gccopts -o bin/reader_network${destarch} $rncfiles src/reader_network.c $rnopts
    #strip bin/reader_network${destarch} 2> /dev/null
    gcc $gccopts -DCLIENT_RRD -o bin/reader_rrd3${destarch} $rncfiles src/reader_rrd3.c $rnopts

done
#exit
gcc $gccopts -o bin/client_time src/client_time.c src/sacsic.c src/helpers.c src/startup.c $rnopts
gcc $gccopts -o bin/client src/client.c src/sacsic.c src/helpers.c src/startup.c $rnopts
gcc $gccopts -o bin/cleanast src/utils/cleanast.c $rnopts
#gcc -Wall -Iinclude/ src/memresp/memresp.c -o bin/memresp -DLINUX
#gcc -Wall -Iinclude/ src/memresp/memresps.c -o bin/memresps -DLINUX

exit

# old binaries

#gcc -Wall -Iinclude/ src/cmpclock.c -o bin/cmpclock
#echo client_rrd
#gcc -g -o bin/client_rrd src/client_rrd.c src/sacsic.c src/helpers.c $params
#strip bin/client_rrd
#echo client_rrd2
#gcc -g -o bin/client_rrd2 src/client_rrd2.c src/sacsic.c src/helpers.c $params
#strip bin/client_rrd
#echo client
#gcc -g -o bin/client src/client.c src/sacsic.c src/helpers.c src/startup.c $params
#strip bin/client
#echo client_filter
#gcc -g -o bin/client_filter src/client_filter.c src/sacsic.c src/helpers.c src/startup.c $params
#echo repeater_network
#gcc -Wall -g -o bin/repeater_network src/repeater_network.c src/asterix.c src/sacsic.c src/helpers.c src/startup.c $params
#strip bin/reader_network

#COMPILATION FOR SOLARIS

#CUR_DIR=`pwd`
##gcc -Wall -g -o bin/subscriber_SOL src/subscriber.c -L${CUR_DIR}/libs/lib/ -I${CUR_DIR}/include/ -I${CUR_DIR}/libs/include/ -lm -lconfig -ldebug -lsocket -lnsl -DSOLARIS
#gcc -Wall -g -o bin/reader_network_SOL src/reader_network.c src/asterix.c src/sacsic.c src/helpers.c src/startup.c src/crc32.c src/red_black_tree.c src/red_black_tree_misc.c src/red_black_tree_stack.c -L${CUR_DIR}/libs/lib_SOL/ -I${CUR_DIR}/include/ -I${CUR_DIR}/libs/include/ -lm -lconfig -ldebug -lsocket -lnsl -DSOLARIS
#gcc -Wall -g -o bin/client src/client.c src/sacsic.c src/helpers.c src/startup.c -L/aplic/reader/conversor_asterix0.45.1/libs/lib/ -Iinclude -Ilibs/include -lm -lconfig -ldebug -lsocket -lnsl -v

#gcc -Wall -g -Iinclude -o bin/cleanast_SOL src/cleanast.c
#gcc -Wall -g -Iinclude -lnsl -lsocket -o bin/memresp_SOL src/memresp/memresp.c -DSOLARIS