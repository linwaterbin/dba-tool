#!/bin/awk -f

#cipher 3des-cbc
#ib_logfile2                                                                                                  100% 1000MB  76.9MB/s   00:13
#ib_logfile1                                                                                                  100% 1000MB  83.3MB/s   00:12
#ib_logfile3                                                                                                  100% 1000MB  83.3MB/s   00:12
#ib_logfile0                                                                                                  100% 1000MB  83.3MB/s   00:12

BEGIN {oldcipher = "start";speed=0;}
{
    if($1 == "cipher"){
        speeds[oldcipher] = speed/4;
        speed=0;oldcipher = $2;
    }
    if($1 ~ /ib_logfile/){
        x = index($4,"MB/s")
        speed += substr($4,0,x);
    }
}
END {
    speeds[oldcipher] = speed/4;
    for (s in speeds){
        print s " " speeds[s]
    }
}
