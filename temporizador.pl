#!/usr/bin/perl

use App::Rad;
App::Rad->run;

use FindBin qw($Bin);
use lib "$Bin/lib";
use temporizador::GUI;
use temporizador::Config;

sub default {
   my $c = shift;
   my $cfg = temporizador::Config->new;
   
   $cfg->load_config("$ENV{HOME}/.temporizador.conf");
   $cfg->load_config("./.temporizador.conf");
   $cfg->load_config("/etc/temporizador.conf");
   
   my $logout_on_destroy = $c->options->{logout-on-destroy};
   $logout_on_destroy = defined $logout_on_destroy ? $logout_on_destroy : 1;
   
   Gtk2->init;
   temporizador::GUI->new(conf => $cfg, logout_on_destroy => $logout_on_destroy)->show_all;
   Gtk2->main;
}
