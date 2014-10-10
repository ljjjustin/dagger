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

cleanup_on_exit()
{
    exit_code=$? 

    # check exit code
    rm -f ${lockfile}
    exit ${exit_code}
}

if [ $# -ne 2 ]
then
    echo "Usage: $0 <master ip address> <slave ip address>"
    exit
fi

lockfile="/tmp/dump-all-database-to-slave-node.lock"

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
## dumped and copy database to slave node
echo "dumping and coping all database to slave node..."
ssh root@${slave_node} 'nc -l 1024 > /tmp/master.sql'
ssh root@${master_node} 'mysqldump --single-transaction --all-databases --master-data=1 -e | nc ${slave_node} 1024'

## import the dump file
echo "load data from sql file..."
exec_mysql_cmd ${slave_node} "STOP SLAVE"
exec_mysql_cmd ${slave_node} "CHANGE MASTER TO MASTER_HOST='${master_node}',MASTER_USER='${repl_username}',MASTER_PASSWORD='${repl_password}'"
exec_mysql_cmd ${slave_node} "SOURCE /tmp/master.sql"
exec_mysql_cmd ${slave_node} "START SLAVE"
exec_mysql_cmd ${slave_node} "SHOW SLAVE STATUS\G"
