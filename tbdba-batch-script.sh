#!/bin/bash
#  Sample:
#   ./batch-script.sh -n tc.read.master -s update.stargate.myddl.sh
#  Note about how to write the "update.stargate.myddl.sh"
#   (1) You should use '>/dev/null 2>&1' to suppression some known distinctive
#       e.g. : rpm -qa|grep "stargate" >/dev/null 2>&1
#
#  Implementation note of the script
#   (1) How to getting ssh to execute a command in the background on target machine 
#       http://stackoverflow.com/questions/29142/getting-ssh-to-execute-a-command-in-the-background-on-target-machine
#       So if -f is on, ssh node "sh -c 'nohup >.. 2>... &'"
#       Thanks the community and thanks stackoverflow
#set -x
nodes=''
script=''
scriptoutput=''
sleeptimeout=300
mkdir -p log

print_usage()
{
  cat <<EOF
 NAME:
    tbdba-batch-update.sh

 SYNTAX:
    Sample:
       1. tbdba-batch-update.sh -n nodes.txt -s update.script.sh -o sample.output
          Using ssh, Execute [update.script.sh] on every node in nodes.txt.
          And make sure the result is exactly same as sampel.output,if not, exit immidiatly

 FUNCTION:
          Update something to a batch of host, and make sure it works exactly as what we expect

 PARAMETER:
    -n a file where put the node list
    -s the script you wanna execute 
    -f force to continue even if the output is different from the sample output
    -o the output of the script. If on any node, the script output an different result, script will exit.
    -t if -f is on,all the script will parallelly executed on all the node.After the command sent, we will wait for 300s ,then check the result
    -h help information
EOF
}

day=7  	# default value
force=0	# default is serial, and exit if the output is different from the sample output
sshparam=" -t -o BatchMode=yes "
while getopts ":n:s:fo:t:" opt; do
  case $opt in
    n)
      nodes=$OPTARG   #get the value
      ;;
    s)
      script=$OPTARG   #get the value
      ;;
    f)
      force=1
      ;;
    o)
      scriptoutput=$OPTARG   #get the value
      ;;
    t)
      sleeptimeout=$OPTARG   #get the value
      ;;
    ?)
      print_usage
      exit 1
      ;;
    :)
      print_usage
      exit 1
      ;;
  esac
done

if [ ! -f $nodes ];then
    echo " -n required or the file $nodes is not exist"
    print_usage
    exit
fi
if [ ! -f $script ];then
    echo " -s required or the file $script is not exist"
    print_usage
    exit
fi
if [ ! -f $scriptoutput ];then
    echo " -o required or the file $scriptoutput is not exist"
    print_usage
    exit
fi

for node in `cat $nodes`
do
  remotelog="/tmp/batch-log-$node.log"
  echo "Start working on $node"
  scp $script $node:/tmp/
  ssh $node "chmod +x /tmp/$script"
  if [ $force -eq 1 ];then
    ssh $sshparam $node "sh -c 'nohup /tmp/$script 1>$remotelog 2>$remotelog &'" > ./log/$node.log
  else 
    ssh $sshparam $node "/tmp/$script" > ./log/$node.log
    diffflag=`diff -Nur $scriptoutput ./log/$node.log|wc -l`
    if [ $diffflag -ne 0 ];then
      echo "Exception on node $node,exit.Check ./log/$node.log"
      exit
    fi
  fi
done

if [ $force -eq 1 ];then
  # There should be a report of all the result
  sleep $sleeptimeout
  for node in `cat $nodes`
  do
    remotelog="/tmp/batch-log-$node.log"
    scp $node:$remotelog ./log/$node.log
    diffflag=`diff -Nur $scriptoutput ./log/$node.log|wc -l`
    if [ $diffflag -ne 0 ];then
      echo "Exception on node $node. Check ./log/$node.log with diff -Nur $scriptoutput ./log/$node.log"
    fi
  done
fi
