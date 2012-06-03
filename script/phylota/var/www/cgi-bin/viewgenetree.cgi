# this is a legacy script file from phylota
#!/usr/bin/perl -w strict
use IO::Socket;
use CGI ':standard';
use FileHandle;
use IPC::Open2;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);

$cgi = new CGI;

$htmlDir  = "http://loco.biosci.arizona.edu/TreeImages";
$localDir = "/var/www/html/TreeImages";

$id = $cgi->param('id');
$treename = $cgi->param('treename');
$ncbitaxid  = $cgi->param('ncbi');
$outfile = $treename . "-" . $id; 

print $cgi->header();

if (-e "$localDir/$outfile.html")
{
   print "<html> <head> " .
    "<meta HTTP-EQUIV=\"REFRESH\" content=\"0; url=$htmlDir/$outfile.html\">" .
	"</head></html>" . "\n";
 
} else {

  local(*HIS_OUT, *HIS_IN);  # Create local handles if needed.

  my $program = "pnggenegraphtree"; 

  $childpid = open2(*HIS_OUT, *HIS_IN, $program)
    or die "can't open pipe to $program: $!";

  print HIS_IN "$treename||||$outfile||||$ncbitaxid\n";

  $his_output = <HIS_OUT>;

  close(HIS_OUT);
  close(HIS_IN);
	
  waitpid($childpid, 0);
  
  print "<html> <head> " .
    "<meta HTTP-EQUIV=\"REFRESH\" content=\"0; url=$his_output\">" .
	"</head></html>" . "\n";

}

	


