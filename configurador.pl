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


our $gladexml = Gtk2::GladeXML->new("Configurador/configurador.glade");
$gladexml->signal_autoconnect_from_package(main);
my $arvore = $gladexml->get_widget("projetos_arvore");
$arvore->signal_connect(visibility_notify_event => \&pega_projetos);
$arvore->signal_connect("cursor-changed" => \&selected);
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

sub selected {
   my $tree = shift;
   my ($model, $iter) = $tree->get_selection->get_selected;
   return unless $iter;
   my $proj = $model->get ($iter, 0);

   my $tempo = $temp->ultimo_login_projeto(nome => $proj);
   my $ultimo_login = $gladexml->get_widget("ultimo_login");
   $ultimo_login->set_text($tempo || "Nunca");

   $tempo = $temp->tempo_total_projeto_dia(projeto => $proj);
   my $tempo_proj = $gladexml->get_widget("tempo_total_hj");
   $tempo_proj->set_text($tempo);

   $tempo = $temp->tempo_total_projeto(projeto => $proj);
   $tempo_proj = $gladexml->get_widget("tempo_total");
   $tempo_proj->set_text($tempo);
}







