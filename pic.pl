#!/usr/bin/perl -T
use strict;
use warnings;

use JSON qw/to_json/;
use Redis;
use CGI;
use List::Util qw/min/;

my $r = Redis->new;

my $q = CGI->new;
my $v = $q->Vars;

my $n = $v->{n} // 1;
$n = min($n, 100);
my @l;

if (exists $v->{404} && $v->{404} && exists $v->{url} ) { // /pic?404=yes&url=foo is present
    $r->del($v->{url}); // delete it

    print to_json({deleted = 1});
} else if ( exists $v->{404} && $v->{404} && !( exists $v->{url}) ) {
    print to_json({deleted = 0, error = "no url"});
} else if ( exists $v->{404} && !($v->{404}) ) {
    print to_json({deleted = 0, error = "wat"});
}

if (exists $v->{type}) {
    my @hack = $r->keys("*." . $v->{type});
    push @l, $hack[int rand @hack] for 1..$n;
} else {
    push @l, $r->randomkey for 1..$n;
}

if (exists $v->{redir} && $v->{redir}) {
    print $q->redirect(@l[0]);
    exit;
}

print "Content-type: application/json\n\n";
if (@l == 1) {
    print to_json({pic => @l});
} else {
    print to_json({pics => \@l});
}
