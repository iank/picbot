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

sub bail {
    print "Content-type: application/json\n\n";
    print to_json($_[0]);
    exit;
}

# /pic?404=yes&url=foo
if (exists $v->{404} && $v->{404} && exists $v->{url} ) {
    my $deleted = $r->del($v->{url});
    bail({deleted => $deleted});
} elsif ( exists $v->{404} && $v->{404} && !( exists $v->{url}) ) {
    bail({deleted => 0, error => "no url"});
} elsif ( exists $v->{404} && !($v->{404}) ) {
    bail({deleted => 0, error => "wat"});
}

if (exists $v->{type}) {
    my @hack = $r->keys("*." . $v->{type});
    push @l, $hack[int rand @hack] for 1..$n;
} else {
    push @l, $r->randomkey for 1..$n;
}

if (exists $v->{redir} && $v->{redir}) {
    print $q->redirect($l[0]);
    exit;
}

if (@l == 1) {
    bail({pic => @l});
} else {
    bail({pics => \@l});
}
