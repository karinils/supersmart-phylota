$S = "trans=123\n  bob=1333\n  name=99\n";
while ( $S =~ /^(.*)$/mg ) {
    print "$1\n";
}
