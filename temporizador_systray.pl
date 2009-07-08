#!/usr/bin/perl

use Gtk2::TrayIcon;
use Gtk2::Notify -init, "Temporizador";
use lib "lib";
use temporizador::Schema;
use File::Find;
use Digest::MD5;
use warnings;

my $email = 'fernandocorrea@gmail.com';

our $schema = temporizador::Schema->connection('dbi:Pg:dbname=temporizador');
our $db_dir = $schema->resultset('Dir');
our $db_arq = $schema->resultset('Arq');
our $path   = $schema->resultset('Path');
our $proj   = $schema->resultset('Projeto');
our $login  = $schema->resultset('Login');
our $user   = $schema->resultset('Empregado');

our $user_id = $user->find({email => $email})->id;

Gtk2->init;

my $icon= Gtk2::TrayIcon->new("test");
my $event = Gtk2::EventBox->new;
my $on  = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("on.jpeg"));
my $off = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("off.jpeg"));
our @images = is_logged() ? ($on, $off) : ($off, $on);
$event->add($images[0]);
$icon->add($event);
$icon->show_all;

$event->signal_connect('button_release_event', \&click);

Gtk2->main;

sub click {
   my $event  = shift;
   my $evento = shift;
   my $image  = shift;

   my $retorno = tenta_logar();

   Gtk2::Notify->new("Temporizador", $retorno, 25, $event)->show;

   $event->remove($images[0]);
   @images[0, 1] = @images[1, 0];
   $event->add($images[0]);
   $icon->show_all;
}

sub pega_projeto {
   my $projeto = shift;
   if(defined $projeto) {
      return $proj->find({nome => $projeto});
   } else {
      die "Erro" unless $proj->all == 1;
      return $proj->single;
   }
}
sub pega_caminhos {
   my $projeto = shift;
   map {$_->caminho} $projeto->paths->all;
}

sub pega_log {
   my $projeto = shift;
   die "pega_log" unless defined $projeto;
   return $projeto->search_related("logins", {empregado => $user_id, logout => undef}, {order_by => "data DESC"})->single;
}

sub is_logged {
   (my @tmp = $login->search({logout => undef})->all) > 0
}

sub tenta_logar {
   my $projeto = shift;

   our $proj_obj = pega_projeto($projeto);
   
   our $log;
   
   unless(defined($log = pega_log($proj_obj))){
      $proj_obj->create_related("logins", {});
      return pega_log($proj_obj)->data;
   } else {
      return logout($log, $proj_obj);
   }
}

sub logout {
   my $log      = shift;
   my $proj_obj = shift;
   $log->update({logout => "now()"});
   $log = $login->search({id => $log->id}, 
   {
    order_by => "data DESC",
    "select" => ['logout - data'],
    "as"     => [qw/tempo/],
   })->single;
   my $tempo = $log->get_column('tempo');
   
   our (@criados, @modificados);
   my @caminhos = pega_caminhos($proj_obj);
   
   File::Find::finddepth(\&subrotina, @caminhos);
   
   my $return;
   $return .= "TEMPO: $tempo$/";
   $return .= "Criados:$/" . (join $/, @criados) . $/ if @criados;
   $return .= "Modificados:$/" . (join $/, @modificados) . $/ if @modificados;

   $return
}

sub subrotina {
   my $dir = $File::Find::dir;
   my $arq = $_;
   my $linha_dir = $db_dir->find({caminho => $dir});
   if(-d $File::Find::name) {
      if(not defined $linha_dir){
         push @criados, $dir;
         $db_dir->create({caminho => $dir, md5 => Digest::MD5::md5_hex(join "|", <$dir/*>)});
      }else{
         my $md5 = Digest::MD5::md5_hex(join "|", <$dir/*>);
         if($linha_dir->md5 ne $md5){
            push @modificados, $dir;
            $linha_dir->update({md5 => $md5});
         }
      }
   } else {
      my $linha_arq = $linha_dir->search_related("arqs", {nome => $arq})->single;
      open my $FILE, "$File::Find::name";
      if(not defined $linha_arq){
         $linha_dir->create_related("arqs", {nome => $arq, md5 => Digest::MD5::md5_hex(join $/, <$FILE>)});
         push @criados, $File::Find::name;
      } else {
         my $md5 = Digest::MD5::md5_hex(join $/, <$FILE>);
         if($linha_arq->md5 ne $md5){
            push @modificados, $File::Find::name;
            $linha_arq->update({md5 => $md5, atualizacao => 'now()'});
         }
      }
      close $FILE;
   }
}
END {
print "Saindo...";
   logout($log, $proj_obj);
}
