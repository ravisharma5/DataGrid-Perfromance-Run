#!/bin/sh
#
# Takes the JBoss PID as an argument. 
#
# Make sure you set JAVA_HOME
#
# Create thread dumps a specified number of times (i.e. LOOP) and INTERVAL. 
#
# Thread dumps will be collected in the file "jstack_threaddump.out", in the same directory from where this script is been executed.
#
# Usage: sh ./threaddump_linux_jstack-continuous.sh <JBOSS_PID>
#

# Number of times to collect data.
LOOP=6
# Interval in seconds between data points.
INTERVAL=20
# Setting the Java Home, by giving the path where your JDK is kept
JAVA_HOME=/home/jdk1.6.0_21

for ((i=1; i <= $LOOP; i++))
do
   $JAVA_HOME/bin/jstack -l $1 >> jstack_threaddump.out
   echo "thread dump #" $i
   if [ $i -lt $LOOP ]; then
    echo "sleeping..."
    sleep $INTERVAL
  fi
done
