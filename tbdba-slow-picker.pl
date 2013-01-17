#!/usr/bin/perl
#use Benchmark;
use Getopt::Long;
use Time::Local;
use Time::HiRes qw ( time alarm sleep );
use POSIX qw(tzset);

@t = localtime(time);
$gmt_offset_in_seconds = timegm(@t) - timelocal(@t);

my $script_start = time;
my $script_now = $script_start;
my $script_pre = $script_start;
my %opt = (
);
sub print_usage{
  print <<EOF;
 NAME:
        tbdba-slow-picker.pl
        Here is what I want: Which SQL is running Between Between t1 and t2?

 SYNTAX:
        Sample:
        tbdba-slow-picker.pl --start "2012-4-26 04:30:00" -until "2012-4-26 04:40:00" -f slow.log > 1.log
        tbdba-slow-picker.pl --ignore --start "2012-4-26 04:30:00" -until "2012-4-26 04:40:00" -f slow.log > 1.log
            (ignore this: QueryTime:375.017626 Start:2012-4-26 4:27:3 Done:2012-4-26 4:33:19)
 To do:
        Add this feature to mk/pt-query-digest --type=slowlog ...

 FUNCTION:
        Get all the slow SQL between 

        [==++ Why this tool? ++==]
        Problem:
          [==++ Here is what I want: Which SQL is running Between Between t1 and t2? ++==]
          The time given in slow log is "Done Time"(when sql was finished), and the SQL was started at ("Done Time" - "Query Time").
          No matter mysqldumpslow or pt/mk-query-digest just use the "Done Time".
        How to fix:
          This script just return all the SQL between t1 and t2,with start time and end time.

        How it help me?
          tbdba-slow-picker.pl --start "2012-4-26 04:30:00" -until "2012-4-26 04:40:00" -f /u01/mysql/log/slow.log > 1.log
          grep "Start" 1.log 
          QueryTime:375.017626 Start:2012-4-26 4:27:3 Done:2012-4-26 4:33:19
          QueryTime:374.867952 Start:2012-4-26 4:27:4 Done:2012-4-26 4:33:19
          QueryTime:375.233387 Start:2012-4-26 4:27:3 Done:2012-4-26 4:33:19
          QueryTime:374.874397 Start:2012-4-26 4:27:4 Done:2012-4-26 4:33:19
          QueryTime:374.834887 Start:2012-4-26 4:27:4 Done:2012-4-26 4:33:19

          grep Rows_examined 1.log       
          # Query_time: 374.124272  Lock_time: 0.000168 Rows_sent: 0  Rows_examined: 0
          # Query_time: 374.926089  Lock_time: 0.000072 Rows_sent: 1  Rows_examined: 5545
          # Query_time: 375.547116  Lock_time: 0.000161 Rows_sent: 0  Rows_examined: 0
          .......(repeat)
          # Query_time: 374.173232  Lock_time: 0.000073 Rows_sent: 1  Rows_examined: 0

          I found that all the sql between 4:27:3 and 4:33:19 was hold...

        If I use mk/pt-query-digest,here is the sample:
          mk-query-digest --type=slowlog --since="2012-04-26 04:27:00" --until="2012-04-26 04:28:25" --print --no-report slow.log
          No query will be output.
          But the query which started at 04:27:04 ended at 04:33:19 should be here.

 PARAMETER:
    most of the parameter is self explained
        -f|slow-log=s
                slow log file
        -d|debug
                debug mode; more output will be there
        -s|start=s
                start from the time 
        -u|until=s
                until the time 
        -i|ignor-start
                ignore the start time line:
                QueryTime:374.834887 Start:2012-4-26 4:27:4 Done:2012-4-26 4:33:19
        -i|ignor-start=i
                current Timezone.
EOF
  exit ;
}

GetOptions(\%opt,
    'f|slow-log=s',   # write result to database
    'd|debug',          # debug mode
    's|start=s',
    'u|until=s',
    'i|ignore',
    'z|timezone=i'
) or print_usage();
my $debug = 0;
my $slowfile = "/u01/mysql/log/slow.log";
my $start = "2000-01-01 00:00:00";
my $until = "2038-01-01 23:59:59";
my $ignore = 0;
my $timezone = 0;
$debug = 1 if $opt{d};
$slowfile = $opt{f} if $opt{f};
if($opt{s}){
  $start = $opt{s} if $opt{s};
}
else{
  print STDERR "No input of 'start time' with -s. Use $start as default.\n";
}
if($opt{u}){
  $until = $opt{u} if $opt{u};
}
else{
  print STDERR "No input of 'until time' with -u. Use $until as default.\n";
}
$ignore = $opt{i} if $opt{i};
$timezone = $opt{z} if $opt{z};

if( !-e $slowfile){
  print_usage(); 
  exit 1;
}

sub tounixtime{
  my $d = $_[0];
  if($d =~ /(\d+)\-(\d+)\-(\d+) (\d+)\:(\d+)\:(\d+)/){
    return timelocal($6,$5,$4,$3,$2-1,$1);
  }
  return -1;
}
sub todatetime{
  my $u = int($_[0]);
  #$u = $u + $timezone*3600; # Time zone +8
  $u = $u + $gmt_offset_in_seconds; # Time zone +8
  my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdest)=(gmtime($u));
  $year = int($year) + 1900;
  $mon = $mon + 1;
  my $curtime = sprintf("%4d-%02d-%02d %02d:%02d:%02d",$year,$mon,$day,$hour,$min,$sec);
  return $curtime;
}
sub timeBetween{
	my $c = $_[0]; # current time
	my $s = $_[1]; # start time
	my $u = $_[2]; # until time

 	#if(
	#	($startTime >= tounixtime($start) and $startTime <= tounixtime($until)) or
	#				($doneTime <= tounixtime($until) and $doneTime >= tounixtime($start))
	return 0;
}
$script_pre = $script_now;
$script_now = time;
print STDERR "script start. Now timestamp: $script_now \n" if $debug;
print STDERR "\nstart picking slow log from <$start> to <$until> \n";
my $chunk = "";
my $query_time = "";
my $inTime = 0;
my $doneTime = "";
my $startTime = "";
my $row_examined = 0;
my $linenum = 0;
my $bytesdone = 0;
my $bytespre = 0;
my $remaintime = 0;
my $elapsed = 0;
$total = -s $slowfile;
#  open (F, $slowfile) || die "Could not open $slowfile: $!\n";
#  my @f = <F>;
#  close F;
#  my $total = @f;
open(SLOWLOG,"<$slowfile") or print STDERR "Can't open file $slowfile";
$start = tounixtime($start);
$until = tounixtime($until);

#     # Time: 130116 16:15:36
#     # User@Host: monitor[monitor] @  [172.20.164.65]
#     # Thread_id: 3874220129  Schema: tianji  Last_errno: 0  Killed: 0
#     # Query_time: 1.106857  Lock_time: 0.000073  Rows_sent: 0  Rows_examined: 0  Rows_affected: 1  Rows_read: 0
#     # Bytes_sent: 11  Tmp_tables: 0  Tmp_disk_tables: 0  Tmp_table_sizes: 0
#     # InnoDB_trx_id: A23AAB72C
#     SET timestamp=1358324136;
#     insert ignore into 
#      <can be any thing here>
#     # User@Host: monitor[monitor] @  [172.24.67.48]
#     # Thread_id: 3874219975  Schema: tianji  Last_errno: 0  Killed: 0
#
#  We use prelineflag to identify last line's type.
#  There are three line type: T U O
#  		T: # Time: 130116 16:15:36
#  		U: # User@Host: monitor[monitor] @  [172.24.67.48]
#  		O: all other case 
#  (1) everytime in line T, 
#				frist,  we output the "chunk" fisrt
#			  second, we update sinTime status
#       then,   inital sinTime; set uinTime to 0
#  (2) in line U, 
#				if pre line is T, do nothing
#				if pre line is O, we output the chuck fisrt
#       then, set uinTime to 0
#  (3) in Line "# Query_time: 1.106857"
#       if try to update uinTime again
#       then, update uinTime 
# 
#   sinTime means the sql start time piont is in the interval, so query happened in the interval
#   uinTime means the sql   end time piont is in the interval, so query happened in the interval
#   
#


my $sinTime = 0;
my $uinTime = 0;
my $preLineFlag = 0;
my $curLineFlag = 0;
my $curTimeInfo = '';
my $preTimeInfo = '';
while (<SLOWLOG>) {
  $linenum += 1;
  $bytesdone += length;
  if($linenum % 100000 == 0){
    $script_pre = $script_now;
    $script_now = time;
    $elapsed = $script_now-$script_start;
    $remaintime = $elapsed*($total-$bytesdone)/$bytesdone;
    my $stderroutput = sprintf("%6.2f%% finished; Total speed %4.1f MB/s, now speed %4.1f MB/s; Remain time:%5d seconds\n",
          100*$bytesdone/$total,
          $bytesdone/$elapsed/1024/1024,
          ($bytesdone-$bytespre)/($script_now-$script_pre)/1024/1024,
          $remaintime);
    print STDERR $stderroutput;
    $bytespre = $bytesdone;
  }
  ###     # Time: 110621 16:53:03
  ###     # User@Host: root[root] @ localhost []
  ###     # Query_time: 171.489260  Lock_time: 0.000504 Rows_sent: 0  Rows_examined: 0
  ###     use tc15;
  ###     SET timestamp=1308646383;
  ###     alter table tablename add index ...(SELLER_ID,GMT_MODIFIED);
  my $sql_from = "";
  my $sql_to = "";
  my $user = "";
  my $host = "";
 
  ###     # Time: 110621 16:53:03
  # Time: 110614  5:10:00
	# Time: 130116 16:15:36
  ## This code wont work again when the year 2100 come.

	$curLineFlag = 'O';
  if($_ =~ m/^\# Time\: (\d{2})(\d{2})(\d{2})\s+(\d+\:\d+\:\d+)/){
		#
		#  Here we try to output any chunk befor,if exist	
		#
		$curTimeInfo = $_;
		if($uinTime or $sinTime)
		{
      # Between the interval
      my $show_qt = sprintf("%11.6f",$query_time);
      my $show_st = sprintf("%21s",todatetime(($doneTime-$query_time)));
      my $show_dt = sprintf("%21s",todatetime($doneTime));
      my $show_re = sprintf("%8d",$row_examined);
      print "# Start:$show_st Done:$show_dt;QueryTime:$show_qt; Rows examin:$show_re\n";
			print $preTimeInfo;
      print $chunk;
    }
		$sinTime = 0;
		$uinTime = 0;
	  $chunk = '';

		$curLineFlag = 'T';
    $doneTime = "20$1-$2-$3 $4";
    $doneTime = tounixtime($doneTime);
		if($doneTime >= $start and $doneTime <= $until)
		{
			$uinTime = 1;
    }
		elsif($doneTime - $until > 3600*20){
			# if doneTime if far away until time, we quit
			exit;
		}
		else{
			$uinTime = 0;
		}
		if($debug){
			print STDERR "  [d]".$_."";
			print STDERR "  [d]".todatetime($doneTime)."\n";
			print STDERR "  [d]".$uinTime."\n\n";
		}
  }
 
  ###   # User@Host: tc[tc] @  [172.23.67.115]
  ###   # User@Host: tc[tc] @  [172.24.168.108]
  elsif($_ =~ m/^\# User\@Host\: (\w+)\[(\w*)\] \@\s+\[(\w|\.)+\]/){
		#
		#  Here we try to output any chunk befor,if exist	
		#
		if( $preLineFlag ne 'T' and ($sinTime or $uinTime))
		{
      # Between the interval
      my $show_qt = sprintf("%11.6f",$query_time);
      my $show_st = sprintf("%21s",todatetime(($doneTime-$query_time)));
      my $show_dt = sprintf("%21s",todatetime($doneTime));
      my $show_re = sprintf("%8d",$row_examined);
      print "# Start:$show_st Done:$show_dt;QueryTime:$show_qt; Rows examin:$show_re\n";
			print $preTimeInfo;
      print $chunk;
    }
		$sinTime = 0;
		#$uinTime = 0;
		$chunk = '';

		$curLineFlag = 'U';
    $user = $1;
    $host = $3;
  }
###  # Query_time: 1.384300  Lock_time: 0.000103 Rows_sent: 1  Rows_examined: 3764
###  use tc15;
###  SET timestamp=1309416998;
###  select count(*) from tablename where  is_main = 1 and (type= or type= or type= or type=) and pay_status=6 and seller_id=and status=0 and gmt_create>=date_format('2011-06-20 14:56:33','%Y-%m-%d %T') and gmt_create<=date_format('2011-06-30 15:56:33','%Y-%m-
###  %d %T');

  elsif($_ =~ m/^\#\sQuery_time\: (\d+\.\d+)\s+Lock_time\: (\d+\.\d+) Rows_sent: (\d+)\s+Rows_examined\: (\d+)/){
    $query_time = $1;
    $startTime = $doneTime - $query_time;
		if($startTime >= $start and $startTime <= $until)
		{
			$sinTime = 1;
    }
		else{
			$sinTime = 0;
		}
    $lock_time = $2;
    $row_sent = $3;
    $row_examined = $4;
  }

###  use tc15;
  elsif($_ =~ m/^use\s(\w+)/){
    $db = $1;
  }
###  SET timestamp=1309416998;
  elsif($_ =~ m/^SET timestamp=(\d+)/){
    $unixtime = $1;
  }
  else{
  }
	if($curLineFlag ne 'T'){
		 $chunk .= $_;
	}
	$preLineFlag = $curLineFlag;
	$preTimeInfo = $curTimeInfo;
}
print STDERR "Done\n";
