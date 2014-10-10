#!/bin/bash

if [ $# -lt 1 -o $# -gt 2 ]; then
    echo "usage: $0 <memcached addresss> [port]"
    exit 1
fi

if [ $# -eq 1 ]; then
    memcached_host=$1
elif [ $# -eq 2 ]; then
    memcached_host=$1
    memcached_port=$2
fi

memcached_port=${memcached_port:-11211}
timeout=${timeout:-3}

add_key_value() {
    local key=$1
    local value=$2
    local length=${#value}
    echo -e "add ${key} 0 60 ${length}\r\n${value}\r" | nc -w ${timeout} ${memcached_host} ${memcached_port}
}

get_key_value() {
    local key=$1
    echo -e "get ${key}\r" | nc -w ${timeout} ${memcached_host} ${memcached_port}
}

replace_key_value() {
    local key=$1
    local value=$2
    local length=${#value}
    echo -e "replace ${key} 0 60 ${length}\r\n${value}\r" | nc -w ${timeout} ${memcached_host} ${memcached_port}
}

delete_key_value() {
    local key=$1
    echo -e "delete ${key}\r" | nc -w ${timeout} ${memcached_host} ${memcached_port}
}

## connection test
nc -z ${memcached_host} ${memcached_port} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to connect memcached server: ${memcached_host} ${memcached_port}"
    exit -1
fi

## generate test key and value
key=$(tr -cd '[:alnum:]' < /dev/urandom | head -c30 | md5sum | awk '{print $1}')
old_value=$(tr -cd '[:alnum:]' < /dev/urandom | head -c60)
new_value=$(tr -cd '[:alnum:]' < /dev/urandom | head -c60)

## add key test
set -e
add_key_value ${key} ${old_value}
get_key_value ${key}
replace_key_value ${key} ${new_value}
get_key_value ${key}
delete_key_value ${key}
get_key_value ${key}
