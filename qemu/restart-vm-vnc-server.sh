#!/bin/bash

if [ $# -ne 1 ]; then
    echo "usage: $0 <instance uuid>"
    exit
fi

instance_uuid=$1
instance_name=$(ps -ef | grep ${instance_uuid} | grep -o 'instance-[0-9a-f]\{8\}' | head -1)

# get instance name
if [ "x" = "${instance_name}" ]; then
    echo "instance ${instance_uuid} is not running"
    exit
fi

# get instance vnc info
listen_info=$(virsh qemu-monitor-command --hmp ${instance_name} "info vnc" | grep -A1 Server| grep address | tr -d '\r')
listen_host=$(echo ${listen_info} | awk '{print $2}' | cut -d: -f1)
listen_port=$(echo ${listen_info} | awk '{print $2}' | cut -d: -f2)
vnc_listen_num=$((listen_port-5900))

# restart instance vnc server
virsh qemu-monitor-command --hmp ${instance_name} "change vnc none"
sleep 2
virsh qemu-monitor-command --hmp ${instance_name} "change vnc ${listen_host}:${vnc_listen_num}"
