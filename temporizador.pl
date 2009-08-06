#!/usr/bin/perl

use App::Rad;
App::Rad->run;

use lib "lib";
use temporizador::OnOffIcon;
use temporizador::Config;

sub default {
   my $c = shift;
   my $cfg = temporizador::Config->new;
   
   $cfg->load_config("$ENV{HOME}/.temporizador.conf");
   $cfg->load_config("./.temporizador.conf");
   $cfg->load_config("/etc/temporizador.conf");
   
   
   Gtk2->init;
   temporizador::OnOffIcon->new(conf => $cfg, logout_on_destroy => $c->options->{logout-on-destroy} || 0)->show_all;
   Gtk2->main;
}
