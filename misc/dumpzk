#!/usr/bin/env perl -w
# $Id: export.pl 261440 2009-11-02 17:22:53Z asloane $

use strict;
use warnings;

use Net::ZooKeeper qw(:node_flags :acls :errors);

my $zkh = Net::ZooKeeper->new($ARGV[0] || 'localhost:2181');

sub dumptree
{
  my ($node) = @_;
  foreach my $path (sort $zkh->get_children($node)) { 
    my $p = $node . "/" . $path;
    $p = "/" . $path if($node eq '/');
    my $contents = $zkh->get($p);
    printf("%s,%s\n", $p, $contents);
    dumptree($p);
  }
}

dumptree("/");
