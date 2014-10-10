#!/bin/bash
#
# Usage: $0 <master ip address> <slave ip address>
#
# Assumption:
#   1. you can ssh to the servers without password.

exec_mysql_cmd() {
    local host=$1
    shift
    local cmd=$@
    ssh root@${host} 'mysql -e "'${cmd}'"'
}

read_mysql_variable() {
    local host=$1
    local variable=$2
    exec_mysql_cmd ${host} 'show global variables' | grep ${variable} | awk '{print $2}'
}

read_slave_state() {
    local host=$1
    local field=$2
    exec_mysql_cmd ${host} 'show slave status\G' | grep ${field} | awk '{print $2}'
}

set_mysql_config() {
    local host=$1
    local section=$2
    local option=$3
    local value=$4
    ssh root@${host} 'sed -i -e "'"/^\[$section\]/,/^\[.*\]/ s|^\($option[ \t]*=[ \t]*\).*$|\1$value|"'" /etc/my.cnf'
}

cleanup_on_exit()
{
    exit_code=$? 

    # check exit code
    rm -f ${lockfile}
    exit ${exit_code}
}


if [ $# -ne 2 ]; then
    echo "usage: $0 <master ip address> <slave ip address>"
    exit
fi

lockfile="/tmp/exchange-mysql-master-slave.lock"

[ -f ${lockfile} ] && exit 0

touch ${lockfile}

trap "cleanup_on_exit" EXIT

master_node=$1
slave_node=$2

repl_username=${repl_username:-replicator}
repl_password=${repl_password:-sdA1akx4d3}

## check the specified mysql master is really a master
read_only=$(read_mysql_variable ${master_node} read_only)
if [[ "${read_only}" != "OFF" ]]; then
    echo "The master node you specified is read only."
    echo "Maybe you specified the wrong master node. exiting ..."
    exit
fi
## check the specified mysql slave is really a slave
read_only=$(read_mysql_variable ${slave_node} read_only)
if [[ "${read_only}" != "ON" ]]; then
    echo "The slave node you specified is not read only."
    echo "Maybe you specified the wrong slave node. exiting ..."
    exit
fi
## check master and slave relation ship
real_master=$(read_slave_state ${slave_node} Master_Host)
if [[ "${real_master}" != "${master_node}" ]]; then
    echo "The master and slave are NOT a pair, exiting ..."
    exit
fi
## check if slave is active
is_slave_active=$(read_slave_state ${slave_node} Seconds_Behind_Master)
if [[ "NULL" == "${is_slave_active}" ]]; then
    echo "Slave is NOT active, slave MUST be active before switching."
    exit
fi
## disable puppet agent
ssh root@${master_node} 'puppet agent --disable'
ssh root@${slave_node}  'puppet agent --disable'

## set mysql master to be read only
echo "set master node to be read only..."
exec_mysql_cmd ${master_node} 'set global read_only=1'
## wait until binlog has been synchronized
echo "wait until slave has been synchronized with master:"
has_synchronized=$(read_slave_state ${slave_node} Seconds_Behind_Master)
while [[ "${has_synchronized}" != "0" ]]
do
    if [[ "NULL" == "${has_synchronized}" ]]; then
        echo "slave has problem on synchronizing with master, exit ..."
        exec_mysql_cmd ${master_node} 'set global read_only=0'
        exit
    fi
    sleep 3 && echo -n ">"
    has_synchronized=$(read_slave_state ${slave_node} Seconds_Behind_Master)
done
## reset mysql slave and make it to be writable
echo "reset slave and make it writable..."
exec_mysql_cmd ${slave_node} 'STOP SLAVE; CHANGE MASTER TO MASTER_HOST=""; RESET SLAVE; set global read_only=0'
## update mysql configuration file
echo "update slave config file..."
set_mysql_config ${slave_node} mysqld read_only 0

## reset mysql master and make it to be slave
echo "reset master and make it to be slave..."
exec_mysql_cmd ${master_node} 'STOP SLAVE'
exec_mysql_cmd ${master_node} "CHANGE MASTER TO MASTER_HOST='${slave_node}',MASTER_USER='${repl_username}',MASTER_PASSWORD='${repl_password}'"
exec_mysql_cmd ${master_node} 'START SLAVE'
## update mysql configuration file
echo "update master config file..."
set_mysql_config ${master_node} mysqld read_only 1
