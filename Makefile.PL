use inc::Module::Install;

name 'PicBot';
all_from 'lib/PicBot.pm';

requires 'Robit' => '0.00';
requires 'LWP::UserAgent::POE' => '0.02';
requires 'SQL::Translator' => 0; # for deploy
requires 'DBIx::Class' => 0; # for database

install_script 'picbot';

WriteAll;
