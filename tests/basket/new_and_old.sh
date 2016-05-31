#!/bin/bash
export JOLIE_HOME=/usr/lib/jolie
echo "iterations,milliseconds"
for (( j=0; j < 10; j++ ))
do
for (( i=5000; i < 100000; i=i+5000 ))
do
        java -Dsun.io.serialization.extendedDebugInfo=true -XX:+UseParallelGC -Xms5G -Xmx5G -ea:jolie... -ea:joliex... -Djava.rmi.server.codebase=file:/$JOLIE_HOME/extensions/rmi.jar -cp $JOLIE_HOME/lib/libjolie.jar:$JOLIE_HOME/jolie.jar jolie.Jolie -l ./lib/*:$JOLIE_HOME/lib:$JOLIE_HOME/javaServices/*:$JOLIE_HOME/extensions/* -i $JOLIE_HOME/include  basket.ol &
	basket=$!
	jolie basket_client.ol $i
	kill $basket
	rm -rf .tmp
done;
done;
