#!/usr/bin/perl

use lib "/home/fernando/temporizador/lib";
use lib "/home/fernando/temporizador";
use CGI qw/param header/;
use temporizador;
use DateTime;
use strict;
use warnings;

my $temp   = temporizador->new("dbi:Pg:dbname=temporizador", "fernando");
$temp->set_empregado(email => param("user"));

my $linhas = $temp->tempo_projetos_por_dia();
my %proj;
my %dias;
my @projetos;
my %projetos;
my ($dmin, $dmax);
for my $linha ($linhas->all){
   my $dia = (split /\s+/,$linha->get_column("dia"))[0];
   $dias{$dia}->{$linha->get_column("projeto")} = $linha->get_column("tempo_total");
   $projetos{$linha->get_column("projeto")}++;
}
my $mesIni;
my $year  = param("ano") || DateTime->today->year;
my $month = param("mes") || DateTime->today->month;
$mesIni = DateTime->new(day => 1, month => $month, year => $year);
my $mesFim = DateTime->last_day_of_month(month => $mesIni->month, year => $mesIni->year);
$mesFim = $mesFim > DateTime->today ? DateTime->today : $mesFim;
my @datetimedays;
my $novadata = $mesIni;

while($novadata <= $mesFim){
    push @datetimedays, $novadata if $novadata->month == $mesIni->month and $novadata->year == $mesIni->year;
    $novadata = $novadata->clone->add(days => 1);
}

@projetos = sort keys %projetos;
my @dia;
my @proj;
for my $dia (@datetimedays){
   push @dia, $dia->strftime("%d/%m");
   for my $proj (0 .. $#projetos){
      push @{ $proj[$proj] }, exists $dias{$dia->ymd}->{$projetos[$proj]} ? $dias{$dia->ymd}->{$projetos[$proj]} : 0;
   }
}
my @data = (\@dia, @proj);
my $mod = "GD::Graph::";
if(param("type")){
   $mod .= param("type");
}else{
   $mod .= "lines";
}
eval "require $mod";
my $graph = new $mod( 1000, 400 );
$graph->set( 
        x_label           => 'Dia',
        y_label           => 'Horas por projeto (h)',
        title             => 'Dias de trabalho de ' . $temp->get_empregado->nome,
);

my $rs = $temp->{rs_proj};

$graph->set_legend(map {$rs->find($_)->nome} @projetos);

#$graph->plot( \@data )->png;

my $format = $graph->export_format;
print header("image/$format");
binmode STDOUT;
print $graph->plot(\@data)->$format();









