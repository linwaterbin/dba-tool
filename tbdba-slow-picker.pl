#!/usr/bin/perl
use Getopt::Long;
use Time::Local;
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
    'f|slow-log=s', 	# write result to database
    'd|debug',          # debug mode
    's|start=s',
    'u|until=s',
    'i|ignore'
    'z|timezone=i'
) or print_usage();
my $slowfile = "/u01/mysql/log/slow.log";
my $start = "";
my $unitl = "";
my $ignore = 0;
my $timezone = 0;
$slowfile = $opt{f} if $opt{f};
$start = $opt{s} if $opt{s};
$until = $opt{u} if $opt{u};
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
  $u = $u + $timezone*3600; # Time zone +8
  my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdest)=(gmtime($u));
  $year = int($year) + 1900;
  $mon = $mon + 1;
  my $curtime = sprintf("%4d-%02d-%02d %02d:%02d:%02d",$year,$mon,$day,$hour,$min,$sec);
  return $curtime;
}

my $chunk = "";
my $query_time = "";
my $inTime = 0;
my $doneTime = "";
my $startTime = "";
my $row_examined = 0;
my $linenum = 0;
open (F, $slowfile) || die "Could not open $slowfile: $!\n";
my @f = <F>;
close F;
my $total = @f;
open(SLOWLOG,"<$slowfile") or print "Can't open file $slowfile";
while (<SLOWLOG>) {
  $linenum +=1;
  if($linenum % 30000 == 0){
    print STDERR int(100*$linenum/$total)."% finished $linenum\/$total To ".todatetime($doneTime)." \n";
  }
###     # Time: 110621 16:53:03
###     # User@Host: root[root] @ localhost []
###     # Query_time: 171.489260  Lock_time: 0.000504 Rows_sent: 0  Rows_examined: 0
###     use tc15;
###     SET timestamp=1308646383;
###     alter table tc_biz_order_0248 add index IND_BIZ_ORDER_SELLERIDGMT(SELLER_ID,GMT_MODIFIED);
  my $sql_from = "";
  my $sql_to = "";
  my $user = "";
  my $host = "";
 
  ###     # Time: 110621 16:53:03
# Time: 110614  5:10:00
  ## This code wont work again when the year 2100 come.
  if($_ =~ m/^\# Time\: (\d{2})(\d{2})(\d{2})\s+(\d+\:\d+\:\d+)/){
    # print "[+==+]$_ ".todatetime($doneTime)."\n" if $opt{d};
    $doneTime = "20$1-$2-$3 $4";
    $doneTime = tounixtime($doneTime);
  }
 
  ###   # User@Host: tc[tc] @  [172.23.67.115]
  ###   # User@Host: tc[tc] @  [172.24.168.108]
  elsif($_ =~ m/^\# User\@Host\: (\w+)\[(\w*)\] \@\s+\[(\w|\.)+\]/){
    if($inTime eq 1){
      # Between the interval
      my $show_qt = sprintf("%11.6f",$query_time);
      my $show_st = sprintf("%21s",todatetime(($doneTime-$query_time)));
      my $show_dt = sprintf("%21s",todatetime($doneTime));
      my $show_re = sprintf("%8d",$row_examined);
      print "# QueryTime:$show_qt Start:$show_st Done:$show_dt Rows examin:$show_re\n";
      print $chunk;
    }
    $inTime = 0;
    $chunk = "";
    $chunk .= $_;
    $user = $1;
    $host = $3;
  }
###  # Query_time: 1.384300  Lock_time: 0.000103 Rows_sent: 1  Rows_examined: 3764
###  use tc15;
###  SET timestamp=1309416998;
###  select count(*) from tc_biz_order_0245 where  is_main = 1 and (biz_type=100 or biz_type=200 or biz_type=300 or biz_type=500) and pay_status=6 and seller_id=11202805 and status=0 and gmt_create>=date_format('2011-06-20 14:56:33','%Y-%m-%d %T') and gmt_create<=date_format('2011-06-30 15:56:33','%Y-%m-
###  %d %T') and seller_rate_status = 5;

  elsif($_ =~ m/^\#\sQuery_time\: (\d+\.\d+)\s+Lock_time\: (\d+\.\d+) Rows_sent: (\d+)\s+Rows_examined\: (\d+)/){
    $chunk .= $_;
    $query_time = $1;
    $startTime = $doneTime - $query_time;
    $lock_time = $2;
    $row_sent = $3;
    $row_examined = $4;
  }

###  use tc15;
  elsif($_ =~ m/^use\s(\w+)/){
    $chunk .= $_;
    $db = $1;
  }
###  SET timestamp=1309416998;
  elsif($_ =~ m/^SET timestamp=(\d+)/){
    $chunk .= $_;
    $unixtime = $1;
  }
  else{
    if( 
       ( $inTime == 0 ) and
       ($startTime >= tounixtime($start) and $startTime <= tounixtime($until)) or
       ($doneTime <= tounixtime($until) and $doneTime >= tounixtime($start))
      ){
      print "inTime\n" if $opt{d};
      $inTime = 1;
    }
    $chunk .= $_;
  }
}
print STDERR "Done\n";
