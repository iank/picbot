package PicBot::DB::Main::Result::Tags;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('tags');
__PACKAGE__->add_columns("pid", "who", "tag");
__PACKAGE__->set_primary_key('pid','tag');
__PACKAGE__->belongs_to("pic", "PicBot::DB::Main::Result::Pdb", {pid=>"pid"});

1
