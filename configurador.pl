#!/usr/bin/perl

use Gtk2 -init;
use Gtk2::GladeXML;
$gladexml = Gtk2::GladeXML->new("Configurador/configurador.glade");
$gladexml->signal_autoconnect_from_package(main);
$quitbtn = $gladexml->get_widget(Quit); 
Gtk2->main;

