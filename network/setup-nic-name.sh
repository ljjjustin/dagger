#!/bin/bash

get_nic_driver_name() {
    nic=$(echo $1 | tr -d ' ')
    echo $(ethtool -i ${nic} | grep driver | awk '{print $2}')
}

set_nic_init_script() {
    nic=$(echo $1 | tr -d ' ')
    nic_new_name=$2
    nic_script_file="/etc/sysconfig/network-scripts/ifcfg-${nic_new_name}"

    cat > ${nic_script_file} << EOF
DEVICE=${nic_new_name}
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=static
EOF
}

set_default_network() {
    nic=$(echo $1 | tr -d ' ')
    nic_script_file="/etc/sysconfig/network-scripts/ifcfg-${nic}"

    default_route_info=$(ip route | grep default)
    if [ x"${default_route_info}" != "x" ]
    then
        gateway_device=$(echo ${default_route_info} | awk '{print $5}')
        gateway_address=$(echo ${default_route_info} | awk '{print $3}')
        address_info=$(ifconfig ${gateway_device} | grep -w inet)
        if [ x"${address_info}" != "x" ]
        then
            ip_address=$(echo ${address_info} | awk '{print $2}' | cut -d ':' -f2)
            ip_netmask=$(echo ${address_info} | awk '{print $4}' | cut -d ':' -f2)
            cat >> ${nic_script_file} << EOF
IPADDR=${ip_address}
NETMASK=${ip_netmask}
EOF
        fi
        if [ x"${gateway_address}" != "x" ]
        then
            cat >> ${nic_script_file} << EOF
GATEWAY=${gateway_address}
EOF
        fi
    fi
}

gen_nic_udev_rule() {
    nic_mac_address=$1
    nic_device_name=$2
    echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="'${nic_mac_address}'", ATTR{type}=="1", KERNEL=="eth*", NAME="'${nic_device_name}'"'
}

set_nic_udev_rule() {
    nic=$(echo $1 | tr -d ' ')
    nic_new_name=$2
    nic_config_file='/etc/udev/rules.d/70-persistent-net.rules'
    nic_mac_address=$(ip link show dev ${nic} | grep ether | awk '{print $2}')
    nic_udev_rule=$(gen_nic_udev_rule ${nic_mac_address} ${nic_new_name})

    sed -i '/'${nic_mac_address}'/ d' ${nic_config_file}
    echo ${nic_udev_rule} >> ${nic_config_file}
}

## distinguish one Gigabit NIC and ten Gigabit NIC
declare -a one_gb_nics
declare -a ten_gb_nics
nic_device_list=$(cat /proc/net/dev | grep 'eth[0-9]' | awk -F ':' '{print $1}' | tr -d ' ')
for nic in ${nic_device_list}
do
    ethtool ${nic} | grep '10000base' > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        one_gb_nics=(${one_gb_nics[@]} ${nic})
    else
        ten_gb_nics=(${ten_gb_nics[@]} ${nic})
    fi
done

## modify udev configuration to make the NIC have the right name
nic_seq_number=0
for nic in $(echo ${one_gb_nics[@]} | sort)
do
    new_name="eth${nic_seq_number}"
    set_nic_udev_rule ${nic} ${new_name}
    set_nic_init_script ${nic} ${new_name}
    let nic_seq_number=nic_seq_number+1
done
for nic in $(echo ${ten_gb_nics[@]} | sort)
do
    new_name="eth${nic_seq_number}"
    set_nic_udev_rule ${nic} ${new_name}
    set_nic_init_script ${nic} ${new_name}
    let nic_seq_number=nic_seq_number+1
done

## setup default network
set_default_network eth0

## remove udev rule generator to prevent udev rewrite udev rules
echo -n > /lib/udev/rules.d/75-persistent-net-generator.rules

## reload all NIC driver to make udev take effect
nic_driver_modules=''
for nic in ${nic_device_list}
do
    driver_name=$(get_nic_driver_name ${nic})
    if [ x"${nic_driver_modules}" != "x" ]
    then
        nic_driver_modules="${nic_driver_modules} ${driver_name}"
    else
        nic_driver_modules="${driver_name}"
    fi
done

echo ${nic_driver_modules}

for module_name in ${nic_driver_modules}
do
    modprobe -r ${module_name}
done

for module_name in ${nic_driver_modules}
do
    modprobe ${module_name}
done

## restart network
/etc/init.d/network restart

## unset bash variables
unset one_gb_nics
unset ten_gb_nics
unset nic_device_list
unset nic_driver_modules
