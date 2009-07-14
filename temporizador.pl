#!/usr/bin/perl

use Gtk2::TrayIcon;
use Gtk2::Notify -init, "Temporizador";
use lib ".";
use lib "./lib";
use temporizador;
use temporizador::Schema;
#use File::Find;
#use Digest::MD5;
use strict;
use warnings;

# die "o Temporizador precisa ser configurado antes de ser utilizado (config.pl)$/"
#     unless -f "temporizador.conf";

my %conf;
my $CONF;
my $conf_file;
for my $path (qw|./.|, $ENV{HOME} . "/.", qw|/etc/ /|){
    $conf_file = $path . "temporizador.conf" if -f $path . "temporizador.conf";
}
die "temporizador.conf nao encontrado" unless $conf_file;
if( open $CONF, "<", $conf_file ){
    while(my $linha = <$CONF>){
        $linha =~ /^\s*(\w+)\s*:\s*(.*)\s*$/;
        $conf{$1} = $2;
    }
}
close $CONF;

my $email = shift;
$email ||= $conf{user};

my $mudou = 0;
unless(exists $conf{root}){
   ($conf{root} = $0) =~ s{/.*?$}{};
   $mudou++;
}
unless(exists $conf{dbname}){
   for my $arq ($ENV{HOME}."/temporizador.sql", $conf{root}."/temporizador.sql", qw{temporizador.sql /var/temporizador.sql}){
      if(-f $arq){
         $conf{dbname} = $arq;
         last;
      }
   }
   $mudou++;
}
unless(exists $conf{banco}){
   $conf{banco} = "SQLite";
   $mudou++;
}
unless(exists $conf{icone_on}){
   $conf{icone_on} = "on.png";
   $mudou++;
}
unless(exists $conf{icone_off}){
   $conf{icone_off} = "off.png";
   $mudou++;
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

unless(exists $conf{user}){
   $email = $temp->{rs_empre}->first->email;
   $conf{user} = $email;
   $mudou++;
}

if($mudou) {
   open my $CONF, ">", $conf_file;
   for my $set (sort keys %conf){
      print { $CONF } "$set: $conf{$set}$/";
   }
   close $CONF;
}

$temp->set_empregado(email => $email);
$temp->set_projeto;

Gtk2->init;

my $icon= Gtk2::TrayIcon->new("test");
my $event = Gtk2::EventBox->new;
my $base = $conf{root};
my $on  = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("$base/$conf{icone_on}"));
my $off = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("$base/$conf{icone_off}"));
our %images = (on => $on, off => $off);
$event->add($images{ $temp->is_logged_in ? "on" : "off"});
our $EVENT = $event;
$icon->add($event);
$icon->show_all;
$event->set_tooltip_text($temp->get_projeto->nome);

$event->signal_connect('button_release_event', \&click);

Gtk2->main;

sub timer {
   my $event = $EVENT;
   if(my $log = $temp->get_log){
      my $retorno = $log->tempof;
      Gtk2::Notify->new("Temporizador", $retorno, 25, $event)->show;
   }
   42;
}

sub click {
   my $eventbox = shift;
   my $evento   = shift;

   loginout($eventbox) if $evento->button == 1;
   menu($eventbox)     if $evento->button == 3;
}


## menu de exibicao
## esse menu aparece quando o usuario
## clica com o botao direito no icone
## do projeto
sub menu {
    my $eventbox = shift;
    my $menu = Gtk2::Menu->new();

    my $proj_atual = $temp->get_projeto;

    # adiciona tempo atual da atividade como 
    # primeiro item do menu (apenas se atividade 
    # estiver sendo registrada no momento)
    my $log = $temp->get_log;
    if($log){
       my ($h, $m, $s) = map {sprintf "%02d", $_} $log->tempo->in_units("hours", "minutes", "seconds");
       $s = sprintf "%02d", $s % 60;
       my $menu_tempo = Gtk2::SeparatorMenuItem->new_with_label(join ":", $h, $m, $s);
       $menu->add($menu_tempo);
    }

    # adiciona projeto atual
    # TODO: clicar no projeto atual deveria abrir
    # opcoes do projeto (ou não?)
    # TODO: deveriam ser tarefas, e não projetos
    my $menu_atual = Gtk2::SeparatorMenuItem->new_with_label("Projeto Atual: " . $proj_atual->nome);
    $menu->add($menu_atual);

    my $menu_sep = Gtk2::SeparatorMenuItem->new();
    $menu->add($menu_sep) if $temp->get_projetos > 1;

    for my $proj ($temp->get_projetos){
       next if $proj_atual-> id == $proj->id;
       my $menu_proj = Gtk2::MenuItem->new_with_label($proj->nome);
       $menu_proj->signal_connect(activate => sub{muda_projeto($eventbox, $proj->id)});
       $menu->add($menu_proj);
    }

    $menu_sep = Gtk2::SeparatorMenuItem->new();
    $menu->add($menu_sep);

    my $menu_quit = Gtk2::MenuItem->new_with_label("sair");
    $menu_quit->signal_connect(activate => sub{exit});
    $menu->add($menu_quit);

    $menu->show_all;

    #popup menu, the three is for right mouse button
    no warnings;
    $menu->popup(undef,undef,undef,3,undef,undef);
}

sub muda_projeto {
   my $event = shift;
   my $proj  = shift;
   #$event->remove($images{ $temp->is_logged_in ? "off" : "on"});
   eval {$event->remove($images{"off"})};
   eval {$event->remove($images{"on"})};
   my $old_proj = $temp->get_projeto->nome;
   my $retorno = logout() if $temp->is_logged_in;
   $retorno .= $/ x 2;
   $temp->set_projeto(id => $proj);
   $event->set_tooltip_text($temp->get_projeto->nome);
   $retorno .= "Projeto atual: " . $temp->get_projeto->nome;
   Gtk2::Notify->new($temp->get_projeto->nome, $retorno, 25, $event)->show;
   $event->add($images{ $temp->is_logged_in ? "on" : "off"});
   $icon->show_all;
}

sub loginout {
   my $event  = shift;
   #my $evento = shift;
   #my $image  = shift;
   our $timer;

   my $retorno;
   if($temp->is_logged_in){
      $retorno = logout();
      Glib::Source->remove($timer) if defined $timer;
   }else{
      $retorno = "Hora Atual: " . $temp->login;
      $timer = Glib::Timeout->add(1000 * 60 * 30, \&timer);
   }

   $event->set_tooltip_text($temp->get_projeto->nome);

   Gtk2::Notify->new($temp->get_projeto->nome, $retorno, 25, $event)->show;

   $event->remove($images{ $temp->is_logged_in ? "off" : "on"});
   $event->add($images{ $temp->is_logged_in ? "on" : "off"});
   $icon->show_all;
}

sub logout {
   our (@criados, @modificados);
   #File::Find::finddepth(\&subrotina, $temp->get_caminhos);
   my $ult_proj = $temp->get_projeto->nome;
   my $tempo_hj = $temp->tempo_empregado_dia;
   my $tempophj = $temp->tempo_projeto_dia;
   my $tempo = $temp->logout;
   my $return;
   $return .= qq#$ult_proj deslogado:$/$/#;
   $return .= qq#TEMPO: $tempo$/#;
   $return .= qq#Tempo hoje $ult_proj: $tempophj$/#;
   $return .= qq#Tempo hoje total: $tempo_hj$/#;
   #$return .= "Criados:$/" . (join $/, @criados) . $/ if @criados;
   #$return .= "Modificados:$/" . (join $/, @modificados) . $/ if @modificados;

   $return
}

sub subrotina {
   my $dir = $File::Find::dir;
   my $arq = $_;
   my(@criados, @modificados);
   if(-d $File::Find::name) {
      my $mod_cri = $temp->update_dir($dir);
      push @criados    , $dir if defined $mod_cri && $mod_cri eq "criado";
      push @modificados, $dir if defined $mod_cri && $mod_cri eq "modificado";
   } else {
      my $mod_cri = $temp->update_arq($dir, $arq);
      push @criados    , $File::Find::name if defined $mod_cri && $mod_cri eq "criado";
      push @modificados, $File::Find::name if defined $mod_cri && $mod_cri eq "modificado";
   }
}
END {
print "Saindo...$/";
   $temp->logout;
}
