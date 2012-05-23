#!/usr/bin/perl -w

use IO::Socket;
use CGI ':standard';
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);

$remote_host = "loco.biosci.arizona.edu";
$remote_port = "6180";

$cgi = new CGI;

$contains = $cgi->param('contains');
$queryTaxa= $cgi->param('queryTaxa');

my $cmd;

if ($contains eq 'all') {
   $cmd = 'relation|';
}
else {
   $cmd = 'any|';
}

$cmd = $cmd . $queryTaxa . "\n";

$socket = IO::Socket::INET->new(PeerAddr => $remote_host,
                                PeerPort => $remote_port,
                                Proto    => "tcp",
                                Type     => SOCK_STREAM)
    or die "Couldn't connect to $remote_host:$remote_port : $@\n";

# ... do something with the socket

print $socket $cmd;

$answer = <$socket>;

# send back search results
print
     $cgi->header() .
     $cgi->start_html( -title => 'Gene tree search results') .
     $cgi->h1('Gene Tree Search Results') . "\n";

my @params = split(/&&&&/, $answer);

print '<TABLE border="1" cellspacing="0" cellpadding="0">' . "\n";

my $returnCode = $params[0];

my $sid  = GetDateTime() . int(rand(10000)); 

my $preURL = "http://loco.biosci.arizona.edu/cgi-bin/viewgenetree.cgi";

if($returnCode>0) {
   my @trees = split(/,/,$params[1]);
   my @queryInfo = split(/&&/,$params[2]);

   my $row = 1;
   print "<tr><th>Row</th><th>  Tree Name </th></tr>\n";
   foreach my $t (@trees) {
		print "<tr><th>$row</th><th>" .
		"<a href=\"$preURL?id=$sid&treename=$t&ncbi=$queryInfo[1]\"/>" .
		$t . "</a> </th></tr>\n";
		++$row;
   }   
}elsif($returnCode==0) {
	  print "<tr><th> No gene tree was found for your query taxa.</th></tr>\n";
}else {
	  print "<tr><th><font color='red'>Error:</font> $params[1]</th></tr>\n";
}

print "</TABLE>\n";

print $cgi->end_html . "\n";


#print $answer;

# and terminate the connection when we're done
close($socket);


# return a string in YYYYMMDDHHMISS
sub GetDateTime {
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, 
                $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
                
$YY = 1900+$yearOffset;

$MM = $month;
if($month < 10) {
  $MM =  "0$month";
}

$DD = $dayOfMonth;
if($dayOfMonth<10) {
  $DD = "0$dayOfMonth";
}

$HH = $hour;
if($hour<10) {
   $HH="0$hour";
}

$TT = $minute;
if($minute<10) {
   $TT="0$minute";
}

$SS = $second;
if($second<10) {
   $SS = "0$second";
}


$mydatetime = "$YY$MM$DD$HH$TT$SS";

return $mydatetime;
}
