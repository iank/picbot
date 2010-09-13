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

sub spawn {
    my ($nick,$server,@channels) = @_;
    die "Need nick/server/etc\n" unless @channels;
    my ($s,$p) = split /:/, $server;
    $p //= 6667;

    my $r = Robit->new(
        nick => $nick,
        server => $s,
        port => $p,
        channels => [ @channels ],
        ignores => [ qr/bot\d*_*$/, 'qq', 'botse', 'Redundant', 'TylerDurden', 'Bit', 'DeepTime', 'Madeline', 'cubert'],
        heap => {
            db => PicBot::DB->new(),
            ua => LWP::UserAgent::POE->new(timeout => 7),
            last => {},
        },
    );
    
    $r->add_handler('msg', \&capture_img);
    $r->add_handler('public', \&capture_img);
    $r->add_handler('action', \&capture_img);
    $r->add_handler('addressed', \&capture_img);

    $r->add_handler('addressed', \&source);
    $r->add_handler('addressed', \&fail);

    $r->add_handler('addressed', \&stats);
    $r->add_handler('addressed', \&addtag);
    $r->add_handler('addressed', \&showtags);
    $r->add_handler('addressed', \&searchtags);
    $r->add_handler('addressed', \&next);
    $r->add_handler('addressed', \&whosaid);
    $r->add_handler('addressed', \&vote);
    $r->add_handler('addressed', \&img); # catchall, must be last

    $r->add_handler('msg', \&source);
    $r->add_handler('msg', \&fail);
    
    $r->add_handler('msg', \&stats);
    $r->add_handler('msg', \&addtag);
    $r->add_handler('msg', \&showtags);
    $r->add_handler('msg', \&searchtags);
    $r->add_handler('msg', \&next);
    $r->add_handler('msg', \&whosaid);
    $r->add_handler('msg', \&vote);
    $r->add_handler('msg', \&img); # catchall, must be last

    $r->spawn();
}

sub addtag {
	my ($robit,$what,$where,$who) = @_;
	my $last = $robit->heap->{last};
	if ($what =~ /^taglast/) {
		return unless exists $last->{$where};
		my @tags = split /\s+/, $what;
		shift @tags; #remove taglast
        s/,// for @tags;
		
		#addtag returns the tag back when things fail, so that we can do a grep
		#and join to make some sane output if someone tries to add existing tags
		my @failed = map {$robit->heap->{db}->addtag($last->{$where}->{id}, $_, $who)} @tags;
		my $failedlist = join(", ", (grep {defined $_} @failed));
		
		if ($failedlist) {
			$robit->irc->yield(privmsg => $where => "$who: existing tags: ".$failedlist);
		} else {
			$robit->irc->yield(privmsg => $where => "$who: added tags");
		}
		return 1;
	}
	return 0;
}

sub showtags {
	my ($robit,$what,$where,$who) = @_;
	my $last = $robit->heap->{last};
	
	if ($what =~ /^(?:last)?tags/) {
		my @tags = $robit->heap->{db}->gettags($last->{$where}->{id});
		
		if (@tags) {
			$robit->irc->yield(privmsg => $where => "$who: " . join(", ", @tags));
		} else {
			$robit->irc->yield(privmsg => $where => "$who: no tags");
		}
		return 1;
	}
	return 0;
}

sub searchtags {
	my ($robit,$what,$where,$who) = @_;
	
	if ($what =~ /^search(?:tags?)?\s+(\S+)/) {
		my @tags = split /\s+/, $what;
		shift @tags; #remove search
		
        my $last = $robit->heap->{last};
        my $pic =  $robit->heap->{db}->searchtags(@tags);
        
        if ($pic) {
        	$last->{$where} = $pic;
        	# Quit your whining: if there's no data, crashing is like a feature
        	$robit->irc->yield(privmsg => $where => "$who: FOUND (".$pic->{index}."/".$pic->{total}.") " . $last->{$where}->{url});
        } else {
        	$robit->irc->yield(privmsg => $where => "$who: not found");
        }
        
        return 1;
	}
	return 0;
}

sub next {
	my ($robit,$what,$where,$who) = @_;
	
	if ($what =~ /^next(?:search|image|img)?/) {
        my $last = $robit->heap->{last};
		if ($last->{$where}{search}) {
			my $next = $robit->heap->{db}->getnext($last->{$where});
			if ($next) {
				$last->{$where} = $next;
				$robit->irc->yield(privmsg => $where => "$who: FOUND (".$next->{index}."/".$next->{total}.") " . $last->{$where}->{url});
				return 1;
			}
		}
	}
	return 0;
}

sub whosaid {
    my ($robit,$what,$where,$who) = @_;
    my $last = $robit->heap->{last};
    if ($what =~ /^whosaid/) {
        return unless exists $last->{$where};
        $robit->irc->yield(privmsg => $where => "$who: " . $last->{$where}->{said}
            . ' in ' . $last->{$where}->{channel} . ' on ' . $last->{$where}->{network});
        return 1;
    }
}

sub stats {
    my ($robit, $what, $where, $who) = @_;
    if ($what =~ /^stats?/) {
        my $reply = "$who: " . $robit->heap->{db}->pdb->count() . " pics " . $robit->heap->{db}->tags->count() . " tags";
        $robit->irc->yield(privmsg => $where => $reply);
        return 1;
    }
}

# This should be addressed, and be the last on the chain
sub img {
    my ($robit,$what,$where,$who) = @_;
    my $last = $robit->heap->{last};
    $last->{$where} = $robit->heap->{db}->fetchrand();
    # Quit your whining: if there's no data, crashing is like a feature
    $robit->irc->yield(privmsg => $where => "$who: " . $last->{$where}->{url});
    return 1;
}

sub source {
    my ($robit,$what,$where,$who) = @_;
    if ($what =~ /^source/) {
        $robit->irc->yield(privmsg => $where => "http://github.com/iank/picbot");
    } elsif ($what =~ /^help/) {
        $robit->irc->yield(privmsg => $where => "Tell me about an image URL to add it. sage deletes the last image said in-channel. GO BOLDLY BEFORE THE THRONE OF LULZ");
    } else { return 0 }
    return 1;
}

sub fail {
    my ($robit,$what,$where,$who) = @_;
    my $last = $robit->heap->{last};
    if ($what =~ /sage|404/) {
        if (exists $last->{$where}) {
            $robit->heap->{db}->fail($last->{$where}->{id});
            delete $last->{$where};
            $robit->irc->yield(privmsg => $where => "$who: 10-4");
        }
        return 1;
    }
}

sub capture_img {
    my ($robit,$what,$where,$who) = @_;
    my $db = $robit->heap->{db};
    my $ua = $robit->heap->{ua};

    if ($what =~ m!(http://\S+\.(?:$extensions))(?:\s|$)!i) {
        my $url = $1;
        my $r = $ua->head($url);
        if ($r->is_success) {
            print "$url\n";
            my $pid = $db->insert($who,$url,$where,$robit->server);
			my @tags = PicBot::AutoTag::checkurl($robit->heap->{ua}, $url, $pid);
			
			my @failed = map {$robit->heap->{db}->addtag($pid, $_, "autotagger")} @tags;

            my $last = $robit->heap->{last};
            $last->{$where} = $robit->heap->{db}->fetchrand();
            # Quit your whining: if there's no data, crashing is like a feature
            $robit->irc->yield(privmsg => $where => $last->{$where}->{url});

            return 1;
        }
    }
}

sub vote {
    my ($robit, $what, $chan, $said) = @_;
    my $db = $robit->heap->{db};
    my $last = $robit->heap->{last};

    #original loudbot code had sagelast also, we don't have that here, yet
    if ($what =~ /^twitlast/i) {
        my $reply = 'no.';
        my $action = lc $1;

        return if $chan !~ /#/;

        if (exists $last->{$chan}->{url}) {
                print time, "vote: tweet\n" . Dumper($last->{$chan}) . "\n";
                my $id = PicBot::Twitter::tweet($last->{$chan}->{url});
                $reply = defined $id
                            ? "http://twitter.com/snausagebringer/status/$id"
                            : "Could not twatter.  It's probably broken.";

                $reply .= ' (' . $last->{$chan}->{said}  . '/'
                       . $last->{$chan}->{channel} . ')';
                delete $last->{$chan}->{url};
        }

        $robit->irc->yield(privmsg => $chan => "$said: $reply") if $reply;

        return 1; # handled
    }
}

1
