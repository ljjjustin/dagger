#!/bin/bash

usage() {
    echo "usage: $0 <test|uc|lg|zhsh|zhj|sh|mm|qn|shzh|xd|sjtu|dbn>"
    exit
}

if [ $# -ne 1 ]; then
    usage >&2
fi

env=$1
case $env in
    dev)
        prefix='10.0.0'
        ;;
    dev2)
        prefix='10.0.2'
        ;;
    dev3)
        prefix='10.0.3'
        ;;
    dev4)
        prefix='10.0.4'
        ;;
    dev5)
        prefix='10.0.5'
        ;;
    test)
        prefix='10.0.1'
        ;;
    lg)
        prefix='10.1.0'
        ;;
    zhsh)
        prefix='10.3.0'
        ;;
    qn)
        prefix='10.4.0'
        ;;
    mm)
        prefix='10.5.0'
        ;;
    xd)
        prefix='10.7.0'
        ;;
    sh)
        prefix='10.8.0'
        ;;
    shzh)
        prefix='10.9.0'
        ;;
    hlgw)
        prefix='10.11.0'
        ;;
    ghxw)
        prefix='10.13.0'
        ;;
    dbn)
        prefix='10.22.0'
        ;;
    zhj)
        prefix='10.100.0'
        ;;
    sjtu)
        prefix='10.120.136'
        ;;
    uc)
        prefix='10.255.0'
        ;;
    *)
        usage >&2
        ;;
esac

cidr="${prefix}.0/24"
nmap -n -sL -PM "${cidr}" 2>/dev/null | grep "^Nmap scan" | awk '{print $5}'
