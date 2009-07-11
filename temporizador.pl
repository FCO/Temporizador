#!/usr/bin/perl

use Gtk2::TrayIcon;
use Gtk2::Notify -init, "Temporizador";
use lib "/home/fernando/temporizador";
use lib "/home/fernando/temporizador/lib";
use temporizador;
use temporizador::Schema;
#use File::Find;
#use Digest::MD5;
use warnings;

die "o Temporizador precisa ser configurado antes de ser utilizado (config.pl)$/"
    unless -f "temporizador.conf";

my %conf;
open $CONF, "<", "temporizador.conf";
if(defined $CONF){
    while(my $linha = <$CONF>){
        $linha =~ /^\s*(\w+)\s*:\s*(.*)\s*$/;
        $conf{$1} = $2;
    }
}
close $CONF;


my $email = shift;
$email ||= $conf{user};

our $temp = temporizador->new("dbi:$conf{banco}:dbname=$conf{dbname}", $conf{dbuser}, $conf{dbpass});
$temp->set_empregado(email => $email);
$temp->set_projeto;

Gtk2->init;

my $icon= Gtk2::TrayIcon->new("test");
my $event = Gtk2::EventBox->new;
my $base = $conf{root};
my $on  = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("$base/on.jpeg"));
my $off = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("$base/off.jpeg"));
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

sub menu {
    my $eventbox = shift;
    my $menu = Gtk2::Menu->new();

    my $proj_atual = $temp->get_projeto;

    my $log = $temp->get_log;
    if($log){
       my ($h, $m, $s) = map {sprintf "%02d", $_} $log->tempo->in_units("hours", "minutes", "seconds");
       $s = sprintf "%02d", $s % 60;
       my $menu_tempo = Gtk2::SeparatorMenuItem->new_with_label(join ":", $h, $m, $s);
       $menu->add($menu_tempo);
    }

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

    my $menu_quit = Gtk2::MenuItem->new_with_label("quit");
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

   my $retorno;
   if($temp->is_logged_in){
      $retorno = logout();
      Glib::Source->remove($timer) if defined $timer;
   }else{
      $retorno = "Hora Atual: " . $temp->login;
      our $timer = Glib::Timeout->add(1000 * 60 * 30, \&timer);
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
print "Saindo...";
   $temp->logout;
}
