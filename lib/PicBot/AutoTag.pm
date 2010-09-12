package PicBot::AutoTag;

use strict;
use warnings;

use Data::Dumper;
use POE qw(Component::Client::HTTP);
use HTML::TreeBuilder;

my $db;

#$lut is a table of regex and subs to call when the regex matches
my $lut = {
	"fukung.net/" => \&fukung,
};

my $http = POE::Component::Client::HTTP->spawn(
	Agent     => 'picbot http://github.com/iank/PicBot',   # defaults to something long
	Alias     => 'autotager',                  # defaults to 'weeble'
	Timeout   => 60,                    # defaults to 180 seconds
	FollowRedirects => 2,               # defaults to 0 (off)
  );

POE::Session->create(
           inline_states => {
             _start => sub { print "Autotagger online\n"; },
           },
           package_states => ["Picbot::AutoTag" => [qw//]],
);

sub initdb {$db = shift;}; # steal the db from picbot

sub checkurl {
	my ($url, $pid, $who) = @_;
	
	for my $re (keys %$lut) {
		if ($url =~ /$re/) {
			$lut->{$re}->($url);
		}
	}	
}

sub fukung {
	my ($url, $pid, $who) = @_;
	
	
}

sub addtags {
	my $pid = shift;
	my $who = shift;
	my @tags = @_;
	
	die "No DB loaded" if !defined($db);
	
	$db->addtag($_) for @tags;
}

1;