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
while getopts ":d:p:u:p:h:S:" opt; do
  case $opt in
    d)
      dir=$OPTARG   #get the value
      ;;
    p)
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
      echo "How to use: $0 [-d the-dir-of-sql-file] [-p parallel_count]" >&2
      echo "How to use: $0 -d /u01/bak/dump " >&2
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
  cat $f|mysql -u$user -p$pass -h$host -S $socket &
  run=`ps -ef | grep "$socket" | wc -l`
  while [ $run -gt $parallel ]
  do
    sleep 2
    run=`ps -ef | grep "$socket" | wc -l`
  done
done
