package PicBot::DB;
use Moose;
use PicBot::DB::Main;
use Data::Dumper;

has 'dsn' => (
    is => 'rw',
    isa => 'Str',
    # FIXME
    default => 'dbi:SQLite:dbname=/home/ian/picbot/pics.db',
);

has user => ( is => 'rw', isa => 'Str', default => '' );
has pass => ( is => 'rw', isa => 'Str', default => '' );

has 'schema' => (
    is => 'rw',
    isa => 'PicBot::DB::Main',
    builder => '_schema',
    lazy => 1,
);

sub _schema {
    my ($self) = @_;
    my $ret = PicBot::DB::Main->connect($self->dsn, $self->user, $self->pass);
    $ret->deploy(); # make tables if not there
    return $ret;
}

sub pdb {
    my ($self) = @_;
    return $self->schema->resultset('Pdb');
}

sub tags {
	my ($self) = @_;
	return $self->schema->resultset('Tags');
}

sub insert {
    my ($self, $who, $what, $channel, $network) = @_;

    my $row = $self->pdb->find_or_create({
        said => $who,
        url => $what,
        channel => $channel,
        network => $network,
        fails => 0,
    });
    return $row->pid; #return the pid of the new image
}

sub addtag {
    my ($self, $pid, $tag, $who) = @_;

    if ($tag =~ /^-(.*)/)
    {
    	my $realtag = $1;
    	eval {
    		my $row = $self->tags->find({
    			pid => $pid,
    			who => $who,
    			tag => $realtag
    		});
    		$row->delete();
    	};
    }
    else
    {
    	eval {
    		my $row = $self->tags->create({
    			pid => $pid,
    			who => $who,
    			tag => $tag
    		});
    	};
    }
        
    return $tag if $@; #return tag if we failed the constraint
    return; #return nothing for working
}

sub gettags {
    my ($self, $pid) = @_;

    my @rows = $self->tags->search({
        pid => $pid,
    });
    
    return map {$_->get_column("tag")} @rows;
}

sub fail {
    my ($self, $id) = @_;

    my $pic = $self->pdb->find($id);
    $pic->delete if defined $pic;
}

sub searchtags {
    my ($self, @tags) = @_;
        my $sqlparams;
    
    my $suffix = '';
    my $i = 1;
    for my $tag (@tags){
       $sqlparams->{'tags' . $suffix . '.tag'} = {'LIKE' => $tag};
       $suffix = '_' . ++$i;
    }

   	my $pics = $self->pdb->search(
   	  $sqlparams,
      {
          join => [('tags') x scalar(@tags)], # join the tags table
      });
    
    if ($pics) {
        my $p = $pics->first();
        
        if ($p) {
    		return { id => $p->pid, url => $p->url,
            	     said => $p->said, channel => $p->channel,
                	 network => $p->network, search => $pics, "index" => 1, total=>$pics->count()};
        } else {
        	return undef;
        }
    } else {
    	return undef;
    }
}

sub search {
}

sub getnext {
    my ($self, $last) = @_;
	
	if ($last->{search}) {
		my $p = $last->{search}->next();
		if ($p) {
			return { id => $p->pid, url => $p->url,
                     said => $p->said, channel => $p->channel,
                     network => $p->network, search => $last->{search}, total=>$last->{total}, index=>$last->{index}+1};
		} else {
			return undef;
		}
	}
}

sub fetchrand {
    my ($self) = @_;
    my $p = $self->pdb->slice(int rand $self->pdb->count)->first();
    return { id => $p->pid, url => $p->url,
             said => $p->said, channel => $p->channel,
             network => $p->network };
}

1
