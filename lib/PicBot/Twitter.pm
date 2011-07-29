package PicBot::Twitter;
use strict;
use warnings;

use Net::Twitter::OAuth;

# FIXME: expedite the repo migration at the expense of ugliness
our ($KEY,$SECRET) = die "hi";
our ($TOKEN,$TSECRET) = die "I like turtles.";

sub tweet {
    my ($tw) = @_;

    my $twit = Net::Twitter::OAuth->new(consumer_key=>$KEY, consumer_secret=>$SECRET);
    $twit->access_token($TOKEN);
    $twit->access_token_secret($TSECRET);

    return eval {
        chomp(my $id = $twit->update($tw)->{id});
        return $id;
    }
}

1
