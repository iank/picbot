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
}

sub addtag {
    my ($self, $pid, $tag, $who) = @_;

    eval {
    my $row = $self->tags->create({
        pid => $pid,
        who => $who,
        tag => $tag
    });
    };
    
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
    my $pics = $self->pdb;
    my @lastpids;
    
    for my $tag (@tags) {
        my $cond;
        
        if (@lastpids) {
        	push @$cond, {'tags.tag' => {LIKE => "%$tag%"}, 'tags.pid' => $_ } for @lastpids;
        } else { #first run
          $cond = {'tags.tag' => {LIKE => "%$tag%"} };
        }
        
    	$pics = $self->pdb->search(
    	  $cond,
          {
          join => 'tags', # join the tags table
          });
        
        last if $pics->count()==0; #end if not found
        
        @lastpids = (); #clear it out for next iteration
        for my $row ($pics->all()) {
        	push @lastpids, $row->pid;
        }
    }
    
    if ($pics && $pics->count()) {
        my $p = $pics->slice(int rand $pics->count)->first();
   
    	return { id => $p->pid, url => $p->url,
                 said => $p->said, channel => $p->channel,
                 network => $p->network };
    } else {
    	return undef;
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
