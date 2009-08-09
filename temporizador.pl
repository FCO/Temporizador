#!/usr/bin/perl

use App::Rad;
App::Rad->run;

use FindBin qw($Bin);
use lib "$Bin/lib";
use temporizador::GUI;
use temporizador::Config;

sub pre_process {
   my $c = shift;
   $c->stash->{cfg} = temporizador::Config->new;
   
   $c->stash->{cfg}->load_config("$ENV{HOME}/.temporizador.conf");
   $c->stash->{cfg}->load_config("./.temporizador.conf");
   $c->stash->{cfg}->load_config("/etc/temporizador.conf");

   my $connect_string = "dbi:"
                        . $c->stash->{cfg}->config("banco")
                        . ":dbname="
                        . $c->stash->{cfg}->config("dbname");
   $c->stash->{temp}
      = temporizador::TempGtk2->new(
                                    $connect_string,
                                    $c->stash->{cfg}->config("dbuser"),
                                    $c->stash->{cfg}->config("dbpass"),
                                    logout_on_destroy => $pars{logout_on_destroy}                 || 0 ,
                                    tempo_alerta      => $c->stash->{cfg}->config("tempo_alerta") || 30,
                                   );

}

sub post_process {
   my $c = shift;
   if(not ref $c->{output}){
      print $c->{output}, $/;
   } elsif (ref $c->{output} eq "ARRAY") {
      my $format = _format($c->{output});
      for my $elem (@{ $c->{output} }){
         printf $format, @$elem;
      }
   } else {
      warn "Sorry, I don't know what to do with this data..."
   }
}

sub _format {
   my $table = shift;
   for my $line (@$table){
      for my $col (0 .. $#$line){
         $sizes[$col] = $sizes[$col] > length $line->[$col] ? $sizes[$col] : length $line->[$col];
      }
   }
   @sizes = map {$_ < 3 ? 3 : $_} @sizes;
   "| " . (join " | ", map {"\% ${_}s"} @sizes) . " |$/";
}
   
sub default {
   my $c = shift;
   $c->execute("gui");
}

sub gui {
   my $c = shift;
   my $logout_on_destroy = $c->options->{logout-on-destroy};
   $logout_on_destroy = defined $logout_on_destroy
                        ? $logout_on_destroy
                        : 1;
   
   Gtk2->init;
   temporizador::GUI->new(
                          conf              => $c->stash->{cfg}  ,
                          temp              => $c->stash->{temp} ,
                          logout_on_destroy => $logout_on_destroy,
                         )->show_all;
   Gtk2->main;
}

sub status {
   my $c = shift;
   my $ret;
   if($c->stash->{temp}->is_logged_in) {
      $ret = "Logado";
   } else {
      $ret = "Deslogado";
   }
   $ret .= "$/Projeto: " . $c->stash->{temp}->get_projeto->nome . $/;
   $ret .= "Usuário: " . $c->stash->{temp}->get_empregado->nome . $/;
   $ret .= "Tempo Atual: " . $c->stash->{temp}->get_log->tempof . $/ if $c->stash->{temp}->is_logged_in;
   $ret .= "Tempo trabalhado hoje: " . $c->stash->{temp}->tempo_empregado_dia . $/;
   $ret .= "Tempo do projeto hoje: " . $c->stash->{temp}->tempo_projeto_dia . $/;

   $ret;
}

sub start {
   my $c = shift;
   $c->stash->{temp}->login;
}

sub stop {
   my $c = shift;
   $c->stash->{temp}->logout;
}

sub show_times {
   my $c = shift;
   [
    $c->stash->{temp}
       ->horarios_projeto_mes(
                              mes     => $c->options->{month},
                              projeto => $c->options->{project},
                             )
   ]
}








