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
                              mes     => $c->options->{month}  ,
                              ano     => $c->options->{year}   ,
                              projeto => $c->options->{project},
                             )
   ]
}

sub write_xls {
   my $c = shift;
   require Spreadsheet::SimpleExcel;
   my $data = show_times($c);
   my $cols = 0;
   my $day;
   for my $line (@$data){
      $cols = $cols <= @$line ? @$line : $cols;
   }
   for my $line (@$data){
      if($c->options->{month} and $c->options->{year}){
         $day = DateTime->new(day => $line->[0], month => $c->options->{month}, year => $c->options->{year});
      } elsif ($c->options->{month}) {
         $day = DateTime->new(day => $line->[0], month => $c->options->{month}, year => DateTime->now->year);
      } elsif ($c->options->{year}) {
         $day = DateTime->new(day => $line->[0], month => DateTime->now->month, year => $c->options->{year});
      } else {
         $day = DateTime->new(day => $line->[0], month => DateTime->now->month, year => DateTime->now->year);
      }
      $day->set_time_zone($c->stash->{temp}->{timezone});
      $line->[$cols] =
         $c->stash->{temp}
            ->tempo_projeto_dia(
                                DateTime => $day                  ,
                                projeto  => $c->options->{project},
                               );
   }
   
   my $excel = Spreadsheet::SimpleExcel->new;
   my @title = (qw/Dia/, ((qw/Entrada Saida/) x (($cols - 1) / 2)), qq/Total Diario/);
   my $horas = $c->stash->{temp}
                    ->tempo_projeto_mes(
                                        "return" => "DateTime",
                                        mes      => $c->options->{month},
                                        ano      => $c->options->{year},
                                        projeto  => $c->options->{project},
                                       );
   my ($h, $m, $s) = map {sprintf "%02d", $_} $horas->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   my $horaf = "$h:$m:$s";

   push @$data, [ ("") x $cols ];
   push @$data, [
                 ("") x ($cols - 1),
                 "Total",
                 $horaf
                ];
   push @$data, [ ("") x ($cols - 1), "Valor/hora", $c->stash->{cfg}->config("valor_por_hora") ||= 1 ];
   push @$data, [ ("") x ($cols - 1), "Valor do mes", $c->stash->{cfg}->config("valor_por_hora") * $horas->hours];
   $excel->add_worksheet(
                         my $name = $day->month_abbr
                         . " "
                         . $day->year,
                         {
                          -headers => \@title,
                          -data => $data
                         }
                        );
   #$excel->set_data_format($name,[("s") x ($cols + 1)]);
   my $filename;
   if(exists $c->options->{filename}) {
      ($filename = $c->options->{filename}) =~ s/(.*)(?:\.xls)?/$1.xls/;
   } else {
      $filename = lc($day->month_abbr) . "_" . $day->year . ".xls";
   }
   $excel->output_to_file($filename) or die $excel->errstr();
   "Created \"$filename\""
}






