#!/usr/bin/perl


use pb;
$configFile = "pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

$basetiNCBI=$pb::basetiNCBI;
$basePB    =$pb::basePB;
$basePBhtml=$pb::basePBhtml;
$basePBicon=$pb::basePBicon;


$qs=$ENV{'QUERY_STRING'};

#$qs="GB159";

@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "db") 
		{$database = $val;} 
	}
$basePBcgi=$basePB;

# Write the HTML

print <<EOF;
Content-type: text/html\n\n
<html>\n

<table><tr>
<td><a href=\"$basePBcgi/pb.cgi\"><img src=\"$basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>Search Page</B></font></td>
</tr></table>
<hr>

<table align="left">
<tr><td>
<b>Taxon name or ID:</b> query by node in the NCBI taxonomy
</td></tr>
<tr><td><font > &nbsp&nbsp<i>Examples</i>: Amorpha <i>or</i> Amor* <i>or</i> Amorpha * <i>or</i> 48130</font></td><tr>
<tr><td>
<form action="$basePBcgi/sql_taxquery.cgi" method="get" name="form1" id="form1">
<input type="text" size="35" maxlength="200" name="qname">
<input type="submit" value="Submit" >
<input type=\"hidden\" name=\"db\" value=\"$database\">
</form>
</td></tr>


<tr><td>
<b>Least common ancestor</b> (<a href="$basePBhtml/lcahelp.htm">What's this?</a>): find node whose LCA is given by this list 
</td></tr>
<tr><td><font > &nbsp&nbsp<i>Example</i>: Dalea, Pisum</td><tr>
<tr><td>
<form action="$basePBcgi/sql_lca_query.cgi" method="get" name="form1" id="form1">
<input type="text" size="35" maxlength="200" name="qname">
<input type="submit" value="Submit" >
<input type=\"hidden\" name=\"db\" value=\"$database\">
</form>
</td></tr>

<tr><td>
<b>Clusters and trees:</b> find clusters/trees containing a list of taxon names
</td></tr>
<tr><td><font > &nbsp&nbsp<i>Example</i>: Homo sapiens, Macaca arctoides</td><tr>
<tr><td>
	<form name="genetreesearch" action="$basePBcgi/my_genetreesearch.cgi" method="post">
	<table summary="" border="0" align="left">
		<tr>
			<td> <input type="text" size="35" maxlength="200" name="queryTaxa"> </td>
			<td><input type="submit" value="Submit" /> </td>
		</tr>
		<tr>
			<td>	<input type="radio" name="contains" value="all" checked="checked" /> Contains all<br /> </td>
			<td><input type="radio" name="contains" value="any" /> Contains any<br /></td>
		</tr>
	</table>
	</form>
</td></tr>


</table>

</body>
</html>



EOF
