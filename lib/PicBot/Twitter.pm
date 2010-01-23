package PicBot::Twitter;
use strict;
use warnings;

use Net::Twitter;

# FIXME: expedite the repo migration at the expense of ugliness
our $USER;
our $PASS;

sub tweet {
    my ($tw) = @_;
    my $twit = Net::Twitter->new({username=>"ikspicbot", password=>"onetwothreefourfivesix", useragent_class => 'LWP::UserAgent::POE'});
    return eval {
        chomp(my $id = $twit->update($tw)->{id});
        return $id;
    }
}

1
