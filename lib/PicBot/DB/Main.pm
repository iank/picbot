package PicBot::DB::Main;
use base qw/DBIx::Class::Schema/;
__PACKAGE__->load_namespaces;
__PACKAGE__->deploy; # make new tables if needed
1;
