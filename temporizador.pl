#!/usr/bin/perl

use lib "lib";
use temporizador::OnOffIcon;
use temporizador::Config;

$cfg = temporizador::Config->new;

$cfg->load_config("$ENV{HOME}/.temporizador.conf");
$cfg->load_config("./.temporizador.conf");
$cfg->load_config("/etc/temporizador.conf");


Gtk2->init;
temporizador::OnOffIcon->new(conf => $cfg)->show_all;
Gtk2->main;

