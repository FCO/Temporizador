#!/usr/bin/perl

use Gtk2::Ex::FormFactory::Popup;

use Gtk2::TrayIcon;

Gtk2->init;

my $icon= Gtk2::TrayIcon->new("test");
my $label= Gtk2::Label->new("Teste");
my $event = Gtk2::EventBox->new;
my $on  = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("on.jpeg"));
my $off = Gtk2::Image->new_from_pixbuf(Gtk2::Gdk::Pixbuf->new_from_file("off.jpeg"));
local @images = ($off, $on);
$event->add($off);
$icon->add($event);
$icon->show_all;

$event->signal_connect('button_release_event', \&click, $image);


Gtk2->main;

sub click {
   use Gtk2::Notify -init, "Temporizador";

   my $event  = shift;
   my $evento = shift;
   my $image  = shift;

   my $retorno = roda();

   Gtk2::Notify->new("Temporizador", $retorno, 250, $event)->show;

   $event->remove($images[0]);
   @images[0, 1] = @images[1, 0];
   $event->add($images[0]);
   $icon->show_all;
}

sub roda {
   use File::Find;
   use Digest::MD5;
   use lib "lib";
   use temporizador::Schema;
   
   our $schema = temporizador::Schema->connection('dbi:Pg:dbname=temporizador');
   our $db_dir = $schema->resultset('Dir');
   our $db_arq = $schema->resultset('Arq');
   our $path   = $schema->resultset('Path');
   our $proj   = $schema->resultset('Projeto');
   
   our $login   = $schema->resultset('Login');
   
   my $projeto = shift;
   my @caminhos;
   
   my $proj_atual;
   
   if(defined $projeto) {
      $proj_atual = $proj->find({nome => $projeto});
      @caminhos = map {$_ -> caminho} $proj_atual->paths->all;
   } else {
      die "Erro" unless $proj->all == 1;
      $proj_atual = $proj->single;
      @caminhos = map {$_->caminho} $proj_atual->paths->all;
   }
   
   my $log;
   
   unless(defined($log = $proj_atual->search_related("logins", {logout => undef})->single)){
      $proj_atual->create_related("logins", {});
      my $log = $proj_atual->search_related("logins", {logout => undef}, {order_by => "data DESC"})->single;
      return $log->data;
   }
   $log->update({logout => "now()"});
   $log = $login->search({id => $log->id}, 
   {
    order_by => "data DESC",
    "select" => ['logout - data'],
    "as"     => [qw/tempo/],
   })->single;
   my $tempo = $log->get_column('tempo');
   
   our (@criados, @modificados);
   
   File::Find::finddepth(\&subrotina, @caminhos);
   
   my $return;
   $return .= "TEMPO: $tempo$/";
   $return .= "Criados:$/" . (join $/, @criados, $/) if @criados;
   $return .= "Modificados:$/" . (join $/, @modificados, $/) if @modificados;

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
