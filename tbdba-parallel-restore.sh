#/bin/bash
# 
# Why shell? I don't know!
# 
dir="./"
parallel=24
socket="/var/lib/mysql/mysql.sock"
user="root"
pass=""
host="localhost"
print_usage()
{
  cat <<EOF
 NAME:
    tbdba-parallel-restore.sh

 SYNTAX:
    Sample:
       1. Restore the split file in dir /opt/dump/
          tbdba-parallel-restore.sh -d /opt/dump/ -S /var/lib/mysql/mysql.socket -uroot -p***

 FUNCTION:
    Restore the split file of mysqldump parallel.
    Works with "tbdba-restore-mysqldump.pl"

 PARAMETER:
    -d the directory of split files           Default: ./
    -u the user which connect to the database Default: root
    -p the password                           Default:
    -S the MySQL socket                       Default: /var/lib/mysql/mysql.sock
    -c How many concurrency thread to restore Default: 24
EOF
}
if [ $# -lt 1 ];then
  print_usage
  exit -1
fi
while getopts ":d:p:u:c:h:S:" opt; do
  case $opt in
    d)
      dir=$OPTARG   #get the value
      ;;
    c)
      parallel=$OPTARG   #get the value
      ;;
    u)
      user=$OPTARG       # user default: root
      ;;
    p)
      pass=$OPTARG       # password default: "" 
      ;;
    h)
      host=$OPTARG       # host default: localhost 
      ;;
    S)
      socket=$OPTARG   #get the value
      ;;
    ?)
      print_usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
for f in `ls $dir/split*.sql`
do
  echo $f
  password=""
  if [ "x$pass" != "x" ];then
    password="-p$pass"
  fi
  cat $f|mysql -u$user $password -h$host -S $socket &
  run=`ps -ef | grep "$socket" | wc -l`
  while [ $run -gt $parallel ]
  do
    sleep 2
    run=`ps -ef | grep "$socket" | wc -l`
  done
done
