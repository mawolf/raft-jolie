#!/bin/bash

#set this one
export JOLIE_HOME=/usr/lib/jolie

#set to the number of nodes to run
NODES_COUNT=10

# Do not edit below line
#########################################################################

#create server list to give as parameter
server_list=""
for (( i = 0; i < $NODES_COUNT; i++ ))
do
  server_list="$server_list socket://localhost:800$i"
done;
 
#start all RAFT node instances and get their PID
pids=()
for (( i = 0; i < $NODES_COUNT; i++ ))
do
  jolie -C "NODE_LOCATION=\"socket://localhost:800$i\"" RAFT.ol $server_list &
  pids+=($!)
done;

#run the monitoring instance
jolie MonitorNode.ol $server_list

killall java

#clean up (kill all started jolie instances)
for (( i = 0; i < $NODES_COUNT; i++ ))
do
	echo "kill " ${pids[i]}
	kill ${pids[i]}
done;
