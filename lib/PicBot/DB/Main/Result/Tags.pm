package PicBot::DB::Main::Result::Tags;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('tags');
__PACKAGE__->add_columns(qw/ tid pid tag who/);
__PACKAGE__->add_unique_constraint(['pid', 'tag']);
__PACKAGE__->set_primary_key('tid');

1
