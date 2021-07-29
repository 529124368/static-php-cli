#!/bin/sh

# Here are 3 steps in configuration of extensions
# before_configure
# in_configure
# after_configure

self_dir=$(cd "$(dirname "$0")";pwd)
php_dir=$(find $self_dir/source -name "php-*" -type d | tail -n1)

function do_xml_compiler() {
    cd $self_dir/source/liblzma-* && \
        ./configure && \
        make -j4 && \
        make install && \
        echo "liblzma compiled!" && sleep 2s && \
        cd ../libxml2-* && \
        ./configure --prefix=/usr --with-lzma --without-python && \
        make -j4 && \
        make install && \
        echo "libxml2 compiled!" && sleep 2s
}

function do_curl_compiler() {
    cd $self_dir/source/curl-* && \
        CC=gcc CXX=g++ CFLAGS=-fPIC CPPFLAGS=-fPIC ./configure \
            --without-nghttp2 \
            --with-ssl=/usr \
            --with-pic=pic \
            --enable-ipv6 \
            --enable-shared=no \
            --without-libidn2 \
            --disable-ldap \
            --without-libpsl \
            --without-lber \
            --enable-ares && \
        make -j4 && \
        make install && \
        echo "curl compiled!" && \
        cat "$self_dir/ac_override_1" "$php_dir/ext/curl/config.m4" "$self_dir/ac_override_2" > /tmp/aa && \
        mv /tmp/aa "$php_dir/ext/curl/config.m4"
}

function do_copy_extension() {
    ext_dir=$(find $self_dir/source -name "$1-*" -type d | tail -n1)
    mv $ext_dir $php_dir/ext/$1
    if [ $? != 0 ]; then
        echo "Compile error! ext: $1, ext_dir=$ext_dir"
        exit 1
    fi
}

function check_before_configure() {
    list=$(cat "$self_dir/extensions.txt" | grep -v "^#" | grep -v "^$")
    xml_sign="no"
    for loop in $list
    do
        case $loop in
        bcmath) ;;
        calendar) ;;
        ctype) ;;
        filter) ;;
        gd) ;;
        hash) ;;
        iconv) ;;
        json) ;;
        mbstring) ;;
        mysqlnd) ;;
        openssl) ;;
        pcntl) ;;
        pdo) ;;
        pdo_mysql) ;;
        phar) ;;
        posix) ;;
        sockets) ;;
        sqlite3) ;;
        tokenizer) ;;
        zlib) ;;
        curl)
            do_curl_compiler
            if [ $? != 0 ]; then
                echo "Compile curl error!"
                exit 1
            fi
            ;;
        dom|xml|libxml|xmlreader|xmlwriter|simplexml)
            if [ "$xml_sign" = "no" ]; then
                do_xml_compiler
                if [ $? != 0 ]; then
                echo "Compile libxml2 error!"
                exit 1
            fi
                xml_sign="yes"
            fi
            ;;
        inotify) do_copy_extension inotify ;;
        redis) do_copy_extension redis ;;
        swoole) do_copy_extension swoole ;;
        mongodb) do_copy_extension mongodb ;;
        event) do_copy_extension event ;;
        esac
    done
}

function check_after_buildconf() {
    list=$(cat "$self_dir/extensions.txt" | sed 's/#.*//g' | sed -e 's/[ ]*$//g' | grep -v "^\s*$")
    for loop in $list
    do
        case $loop in
        event)
            sed -ie 's@\$abs_srcdir/php7@$abs_srcdir/ext/event/php7@' $php_dir/configure
            sed -ie 's@\$phpincludedir/ext/sockets/php_sockets.h@$abs_srcdir/ext/sockets/php_sockets.h@' $php_dir/configure
            cp -f $php_dir/ext/event/php8/*.h $php_dir/ext/event
            ;;
        esac
    done
}

function check_in_configure() {
    php_configure=""
    list=$(cat "$self_dir/extensions.txt" | sed 's/#.*//g' | sed -e 's/[ ]*$//g' | grep -v "^\s*$")
    for loop in $list
    do
        case $loop in
        bcmath)             php_configure="$php_configure --enable-bcmath" ;;
        calendar)           php_configure="$php_configure --enable-calendar" ;;
        ctype)              php_configure="$php_configure --enable-ctype" ;;
        curl)               php_configure="$php_configure --with-curl" ;;
        dom)                php_configure="$php_configure --enable-dom" ;;
        event)              php_configure="$php_configure --with-event-core --with-event-extra --with-event-openssl" ;;
        filter)             php_configure="$php_configure --enable-filter" ;;
        gd)
            case $1 in
            7.3.*|7.2.*)    php_configure="$php_configure --with-gd" ;;
            7.4.*|8.*)      php_configure="$php_configure --enable-gd" ;;
            esac
            ;;
        hash)
            case $1 in
            7.3.*|7.2.*)    php_configure="$php_configure --enable-hash" ;;
            esac
            ;;
        iconv)              php_configure="$php_configure --with-iconv" ;;
        inotify)            php_configure="$php_configure --enable-inotify" ;;
        json)
            case $1 in
            7.*)            php_configure="$php_configure --enable-json" ;;
            esac
            ;;
        libxml)
            case $1 in
            7.3.*|7.2.*)    php_configure="$php_configure --enable-libxml" ;;
            7.4.*|8.*)      php_configure="$php_configure --with-libxml" ;;
            esac
            ;;
        mbstring)           php_configure="$php_configure --enable-mbstring" ;;
        mongodb)            php_configure="$php_configure --enable-mongodb" ;;
        mysqlnd)            php_configure="$php_configure --enable-mysqlnd" ;;
        openssl)            php_configure="$php_configure --with-openssl --with-openssl-dir=/usr" ;;
        pcntl)              php_configure="$php_configure --enable-pcntl" ;;
        pdo)                php_configure="$php_configure --enable-pdo" ;;
        pdo_mysql)          php_configure="$php_configure --with-pdo-mysql=mysqlnd" ;;
        phar)               php_configure="$php_configure --enable-phar" ;;
        posix)              php_configure="$php_configure --enable-posix" ;;
        redis)              php_configure="$php_configure --enable-redis --disable-redis-session" ;;
        simplexml)          php_configure="$php_configure --enable-simplexml" ;;
        sockets)            php_configure="$php_configure --enable-sockets" ;;
        sqlite3)            php_configure="$php_configure --with-sqlite3" ;;
        
        swoole)
            php_configure="$php_configure --enable-swoole"
            have_openssl=$(echo $list | grep openssl)
            if [ "$have_openssl" != "" ]; then
                php_configure="$php_configure --enable-openssl --with-openssl --with-openssl-dir=/usr"
            fi
            have_hash=$(echo $list | grep hash)
            if [ "$have_hash" = "" ]; then
                case $1 in
                7.3.*|7.2.*)    php_configure="$php_configure --enable-hash" ;;
                esac
            fi
            ;;
        tokenizer)          php_configure="$php_configure --enable-tokenizer" ;;
        xml)                php_configure="$php_configure --enable-xml" ;;
        xmlreader)          php_configure="$php_configure --enable-xmlreader" ;;
        xmlwriter)          php_configure="$php_configure --enable-xmlwriter" ;;
        zlib)               php_configure="$php_configure --with-zlib" ;;
        *)
            echo "Unsupported extension '$loop' !" >&2
            exit 1
            ;;
        esac
    done
    echo $php_configure
}

function check_after_configure() {
    list=$(cat "$self_dir/extensions.txt" | grep -v "^#" | grep -v "^$")
    for loop in $list
    do
        case $loop in
        swoole)
            sed -ie 's/swoole_clock_gettime(CLOCK_REALTIME/clock_gettime(CLOCK_REALTIME/g' "$php_dir/ext/swoole/include/swoole.h"
            ;;
        event)
            sed -ie 's/-levent /-levent -levent_openssl /' $php_dir/Makefile
            ;;
        esac
    done
}

$1 $2