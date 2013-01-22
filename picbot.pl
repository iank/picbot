#!/usr/bin/perl
use strict;
use warnings;

use POE qw(Component::IRC Component::IRC::Plugin::Connector);
use LWP::UserAgent::POE;
use Redis;

my $ua = LWP::UserAgent::POE->new();
my $last = {};

my $nickname = 'picbot';
my $ircname  = 'picbot';
my $server   = 'irc.freenode.org';
 
my @channels = (qw/##turtles #peltkore #ncsulug ##church-of-picbot/);
my $extensions = 'jpe?g|.ng|p.m|gif|svg|bmp|tiff';
 
# We create a new PoCo-IRC object
my $irc = POE::Component::IRC->spawn(
   nick => $nickname,
   ircname => $ircname,
   server  => $server,
) or die "Oh noooo! $!";
 
POE::Session->create(
    package_states => [
        main => [ qw(_start irc_001 irc_public) ],
    ],
    heap => { irc => $irc },
);
 
$poe_kernel->run();
 
sub _start {
    my $heap = $_[HEAP];
 
    # retrieve our component's object from the heap where we stashed it
    my $irc = $heap->{irc};
    $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
    $irc->plugin_add( 'Connector' => $heap->{connector} );
 
    $irc->yield( register => 'all' );
    $irc->yield( connect => { } );
    return;
}
 
sub irc_001 {
    my $sender = $_[SENDER];
 
    # Since this is an irc_* event, we can get the component's object by
    # accessing the heap of the sender. Then we register and connect to the
    # specified server.
    my $irc = $sender->get_heap();
 
    print "Connected to ", $irc->server_name(), "\n";
 
    # we join our channels
    $irc->yield( join => $_ ) for @channels;
    return;
}
 
sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

    my $r = Redis->new(reconnect => 60);
    my $reply = $last->{$where} = $r->randomkey;
    if ($what =~ m!(https?://\S+\.(?:$extensions))(?:\s|$)!i) {
        my $url = $1;
        return unless $ua->head($url)->is_success;
        $r->set($url => 1);
        $reply = "$nick: k. $reply";
    } elsif ($what =~ /^$nickname[,:]\s+(sage|404)\b/) {
        return unless defined $last->{$where};
        $r->del($last->{$where});
        $reply = "10-4. $reply";
    } elsif ($what =~ /^$nickname[,:]/) {
    } else { return; }

    $irc->yield(privmsg => $channel => $reply);
    return;
}
