package PicBot;
use strict;
use warnings;

use Robit;
use PicBot::DB;
use PicBot::Twitter;
use LWP::UserAgent::POE;
use Data::Dumper;
use PicBot::AutoTag;
use feature ':5.10';

my $extensions = 'jpe?g|png|p.m|gif|svg|bmp|tiff';

sub spec {
    return {
        nick => 'picbot',
        heap => {
            db => PicBot::DB->new(),
            ua => LWP::UserAgent::POE->new(timeout => 7),
            last => {},
        },
        ignores => [ qr/bot\d*_*$/, 'qq', 'botse', 'Redundant', 'TylerDurden', 'Bit', 'DeepTime', 'Madeline', 'cubert'],
        handlers => {
            msg       => sub { PicBot::capture_img(@_) },
            public    => sub { PicBot::capture_img(@_) },
            action    => sub { PicBot::capture_img(@_) },
            addressed => [
                sub { PicBot::capture_img(@_) },
                sub { PicBot::source(@_) },
                sub { PicBot::fail(@_) },

                sub { PicBot::stats(@_) },
                sub { PicBot::addtag(@_) },
                sub { PicBot::showtags(@_) },
                sub { PicBot::searchtags(@_) },
                sub { PicBot::next(@_) },
                sub { PicBot::whosaid(@_) },
                sub { PicBot::vote(@_) },
                sub { PicBot::img(@_) },
            ],
        },
    };
}

sub addtag {
    my ($robit, $args) = @_;
    my $last = $robit->heap->{last};
    if ($args->{what} =~ /^taglast/) {
        return unless exists $last->{$args->{where}};
        my @tags = split /\s+/, $args->{what};
        shift @tags; #remove taglast
        s/,// for @tags;
        
        #addtag returns the tag back when things fail, so that we can do a grep
        #and join to make some sane output if someone tries to add existing tags
        my @failed = map {$robit->heap->{db}->addtag($last->{$args->{where}}->{id}, $_, $args->{who})} @tags;
        my $failedlist = join(", ", (grep {defined $_} @failed));
        
        if ($failedlist) {
            $robit->cb->reply($args->{where} => $args->{who} . ": existing tags: ".$failedlist);
        } else {
            $robit->cb->reply($args->{where} => $args->{who} . ": added tags.");
        }
        return 1;
    }
    return 0;
}

sub showtags {
    my ($robit,$args) = @_;
    my $last = $robit->heap->{last};
    
    if ($args->{what} =~ /^(?:last)?tags/) {
        my @tags = $robit->heap->{db}->gettags($last->{$args->{where}}->{id});
        
        if (@tags) {
            $robit->cb->reply(
                $args->{where} =>
                $args->{who} . ': ' . join(', ', @tags)
            );
        } else {
            $robit->cb->reply(
                $args->{where} =>
                $args->{who} . ': no tags.' 
            );
        }
        return 1;
    }
    return 0;
}

sub searchtags {
    my ($robit,$args) = @_;
    
    if ($args->{what} =~ /^search(?:tags?)?\s+(\S+)/) {
        my @tags = split /\s+/, $args->{what};
        shift @tags; #remove search
        
        my $last = $robit->heap->{last};
        my $pic =  $robit->heap->{db}->searchtags(@tags);
    
        if ($pic) {
            $last->{$args->{where}} = $pic;
            # Quit your whining: if there's no data, crashing is like a feature
            $robit->cb->reply($args->{where} => $args->{who} . ': FOUND ('.$pic->{index}.'/'.$pic->{total}.") " . $last->{$args->{where}}->{url});
        } else {
            $robit->cb->reply($args->{where} => $args->{who}.': not found');
        }
    
        return 1;
    }
    return 0;
}

sub next {
    my ($robit,$args) = @_;
    
    if ($args->{what} =~ /^next(?:search|image|img)?/) {
        my $last = $robit->heap->{last};
        if ($last->{$args->{where}}{search}) {
            my $next = $robit->heap->{db}->getnext($last->{$args->{where}});
            if ($next) {
                $last->{$args->{where}} = $next;
                $robit->cb->reply($args->{where} => $args->{who}.': FOUND ('.$next->{index}.'/'.$next->{total}.') ' . $last->{$args->{where}}->{url});
                return 1;
            }
        }
    }
    return 0;
}

sub whosaid {
    my ($robit,$args) = @_;
    my $last = $robit->heap->{last};
    if ($args->{what} =~ /^(whosaid|sauce)/) {
        return unless exists $last->{$args->{where}};
        $robit->cb->reply($args->{where} => $args->{who}.': ' . $last->{$args->{where}}->{said}
            . ' in ' . $last->{$args->{where}}->{channel} . ' on ' . $last->{$args->{where}}->{network});
        return 1;
    }
}

sub stats {
    my ($robit, $args) = @_;
    if ($args->{what} =~ /^stats?/) {
        my $reply = $args->{who}.': ' . $robit->heap->{db}->pdb->count() . ' pics ' . $robit->heap->{db}->tags->count() . ' tags.';
        $robit->cb->reply($args->{where} => $reply);
        return 1;
    }
}

# This should be addressed, and be the last on the chain
sub img {
    my ($robit,$args) = @_;
    my $last = $robit->heap->{last};
    $last->{$args->{where}} = $robit->heap->{db}->fetchrand();
    # Quit your whining: if there's no data, crashing is like a feature
    $robit->cb->reply($args->{where} => $args->{who}.': ' . $last->{$args->{where}}->{url});
    return 1;
}

sub source {
    my ($robit,$args) = @_;
    if ($args->{what} =~ /^source/) {
        $robit->cb->reply($args->{where} => "http://github.com/iank/picbot");
    } elsif ($args->{what} =~ /^help/) {
        $robit->cb->reply($args->{where} => "Tell me about an image URL to add it. sage deletes the last image said in-channel. GO BOLDLY BEFORE THE THRONE OF LULZ");
    } else { return 0 }
    return 1;
}

sub fail {
    my ($robit,$args) = @_;
    my $last = $robit->heap->{last};
    if ($args->{what} =~ /^sage\b|^404\b/) {
        if (exists $last->{$args->{where}}) {
            $robit->heap->{db}->fail($last->{$args->{where}}->{id});
            delete $last->{$args->{where}};
            $robit->cb->reply($args->{where} => $args->{who}.': 10-4');
        }
        return 1;
    }
}

sub capture_img {
    my ($robit,$args) = @_;
    my $db = $robit->heap->{db};
    my $ua = $robit->heap->{ua};

    if ($args->{what} =~ m!(http://\S+\.(?:$extensions))(?:\s|$)!i) {
        my $url = $1;
        my $r = $ua->head($url);
        if ($r->is_success) {
            print "$url\n";
            my $pid = $db->insert($args->{who},$url,$args->{where},$robit->server);
            my @tags = PicBot::AutoTag::checkurl($robit->heap->{ua}, $url, $pid);
            
            my @failed = map {$robit->heap->{db}->addtag($pid, $_, "autotagger")} @tags;

            my $last = $robit->heap->{last};
            $last->{$args->{where}} = $robit->heap->{db}->fetchrand();
            # Quit your whining: if there's no data, crashing is like a feature
            $robit->cb->reply($args->{where} => $last->{$args->{where}}->{url});

            return 1;
        }
    }
}

sub vote {
    my ($robit, $args) = @_;
    my $db = $robit->heap->{db};
    my $last = $robit->heap->{last};

    if ($args->{what} =~ /^twitlast/i) {
        my $reply = 'no.';
        my $action = lc $1;

        return if $args->{where} !~ /#/;

        if (exists $last->{$args->{where}}->{url}) {
                print time, "vote: tweet\n" . Dumper($last->{$args->{where}}) . "\n";
                my $id = PicBot::Twitter::tweet($last->{$args->{where}}->{url});
                $reply = defined $id
                            ? "http://twitter.com/snausagebringer/status/$id"
                            : "Could not twatter.  It's probably broken.";

                $reply .= ' (' . $last->{$args->{where}}->{said}  . '/'
                       . $last->{$args->{where}}->{channel} . ')';
                delete $last->{$args->{where}}->{url};
        }

        $robit->cb->reply($args->{where} => $args->{who}.": $reply") if $reply;

        return 1; # handled
    }
}

1
