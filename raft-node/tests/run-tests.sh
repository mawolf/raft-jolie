#!/bin/bash

#set this one
export JOLIE_HOME=/usr/lib/jolie

#set to the number of nodes to run
NODES_COUNT=10
ITERATIONS=1

# Do not edit below line
#########################################################################

MAX_PORT=$(($NODES_COUNT+8000))
echo $MAX_PORT
#start log verifier and wait a bit to make sure it is up
jolie LogVerifier.ol &

sleep 2

#create server list to give as parameter
server_list=""
for (( i = 8000; i < $MAX_PORT; i++ ))
do
  server_list="$server_list socket://localhost:$i"
done;

# change pwd to make it work with includes and etc
cd ..

#start all RAFT node instances and get their PID
pids=()
for (( i = 8000; i < $MAX_PORT; i++ ))
do
  java -ea:jolie... -ea:joliex... -Djava.rmi.server.codebase=file:/$JOLIE_HOME/extensions/rmi.jar -cp $JOLIE_HOME/lib/libjolie.jar:$JOLIE_HOME/jolie.jar jolie.Jolie -l ./lib/*:$JOLIE_HOME/lib:$JOLIE_HOME/javaServices/*:$JOLIE_HOME/extensions/* -i $JOLIE_HOME/include -C "NODE_LOCATION=\"socket://localhost:$i\"" raft_node.ol --log-service=socket://localhost:9000 $server_list > /dev/null 2>&1 &
  pids+=($!)
done;

# wait to make sure a leader is elected
sleep 5

# Nuke 'em to spread fear and possible new elections.
for (( j = 0; j < $ITERATIONS; j++ ))
do
  for (( i = 0; i < $NODES_COUNT; i++ ))
  do
    kill ${pids[i]}
    sleep 2
    port=$(($i+8000))
    echo $port
    java -ea:jolie... -ea:joliex... -Djava.rmi.server.codebase=file:/$JOLIE_HOME/extensions/rmi.jar -cp $JOLIE_HOME/lib/libjolie.jar:$JOLIE_HOME/jolie.jar jolie.Jolie -l ./lib/*:$JOLIE_HOME/lib:$JOLIE_HOME/javaServices/*:$JOLIE_HOME/extensions/* -i $JOLIE_HOME/include -C "NODE_LOCATION=\"socket://localhost:$port\"" raft_node.ol --log-service=socket://localhost:9000 $server_list > /dev/null 2>&1 &
    pids[$i]=$!
    echo PID: ${pids[i]}
  done;
done;

# change back pwd
cd tests

# wait to make sure nodes are stabilized
sleep 20

# stop verifying log events and give status
jolie LogVerifierClient.ol stop
jolie LogVerifierClient.ol stats
jolie LogVerifierClient.ol status

#clean up (kill all started jolie instances)
for (( i = 0; i < $NODES_COUNT; i++ ))
do
#	echo "Stopping node with PID: " ${pids[i]}
	kill ${pids[i]}
done;

jolie LogVerifierClient.ol shutdown > /dev/null 2>&1
