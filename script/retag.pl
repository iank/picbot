#!/usr/bin/perl

use strict;
use warnings;

use PicBot::AutoTag;
use PicBot::DB;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new();
my $db = PicBot::DB->new();

my $pdb = $db->pdb();

while(my $row = $pdb->next()) {
	my $pid = $row->pid();
	my $url = $row->url();
	
	my @tags = PicBot::AutoTag::checkurl($ua, $url, $pid);
	print "$url : ",join(", ", @tags),"\n" if (@tags);
	my @failed = map {$db->addtag($pid, $_, "autotagger")} @tags;
	
	print "existing tags: ", join(", ", @failed), "\n" if (@failed);
}