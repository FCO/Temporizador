#!/usr/bin/perl

use temporizador;
use Gtk2 -init;
use Gtk2::GladeXML;

my %conf;
my $CONF;
if( open $CONF, "<", "temporizador.conf" ){
    while(my $linha = <$CONF>){
        $linha =~ /^\s*(\w+)\s*:\s*(.*)\s*$/;
        $conf{$1} = $2;
    }
}   
close $CONF; 

unless(exists $conf{dbname}){
   $conf{dbname} = "temporizador.sql";
}
unless(exists $conf{banco}){
   $conf{banco} = "SQLite";
}
unless(exists $conf{icone_on}){
   $conf{icone_on} = "on.png";
}
unless(exists $conf{icone_off}){
   $conf{icone_off} = "off.png";
}
our $temp = temporizador->new("dbi:$conf{banco}:dbname=$conf{dbname}" .
                              (
                               $conf{dbhost}
                                ?";host=$conf{dbhost}"
                                :""
                              ),
                              $conf{dbuser},
                              $conf{dbpass},
                             );


$gladexml = Gtk2::GladeXML->new("Configurador/configurador.glade");
$gladexml->signal_autoconnect_from_package(main);
my $arvore = $gladexml->get_widget("projetos_arvore");
$arvore->signal_connect(visibility_notify_event => \&pega_projetos);
Gtk2->main;

sub pega_projetos {
   my $tree = shift;
   my $display_model = Gtk2::TreeStore->new("Glib::String");
   $display_model->set($display_model->append(undef), 0 => $_) for map {$_->nome} $temp->get_projetos;
   $tree->set_model($display_model);

   my $col = Gtk2::TreeViewColumn->new_with_attributes(
      "Projeto",
      Gtk2::CellRendererText->new,
      "text",
      0
   );
   my $cel = Gtk2::CellRendererText->new;
   $tree->append_column($col);
}







