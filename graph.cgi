#!/usr/bin/perl

use lib "/home/fernando/temporizador/lib";
use lib "/home/fernando/temporizador";
use CGI qw/param header/;
use temporizador;
use DateTime;
use strict;
use warnings;
use diagnostics;

my $temp   = temporizador->new("dbi:Pg:dbname=temporizador", "fernando");
$temp->set_empregado(email => param("user"));

my $linhas = $temp->tempo_projetos_por_dia;
my %proj;
my %dias;
my @projetos;
my %projetos;
my ($dmin, $dmax);
for my $linha ($linhas->all){
   my $dia = (split /\s+/,$linha->get_column("dia"))[0];
   $dias{$dia}->{$linha->get_column("projeto")} = $linha->get_column("tempo_total");
   $projetos{$linha->get_column("projeto")}++;
   
   $dmin ||= $dia;
   $dmax ||= $dia;
   $dmin = $dmin le $dia ? $dmin : $dia;
   $dmax = $dmax ge $dia ? $dmax : $dia;
   #push @{ $proj{$linha->get_column("projeto")}->{tempo} }, $linha->get_column("tempo_total");
   #push @{ $proj{$linha->get_column("projeto")}->{dia} }, (split /\s+/,$linha->get_column("dia"))[0];
}
$dmin =~ /^(\d{4})-(\d{2})-(\d{2})$/;
my $min = DateTime->new(year => $1, month => $2, day => $3);
$dmax =~ /^(\d{4})-(\d{2})-(\d{2})$/;
my $max = DateTime->new(year => $1, month => $2, day => $3);
my @datetimedays;
my $novadata = $min;

while($novadata < $max){
    push @datetimedays, $novadata if $novadata->month == $max->month and $novadata->year == $max->year;
    $novadata = $novadata->clone->add(days => 1);
}
    push @datetimedays, $max;

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
my $graph = new $mod( 600, 400 );
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










