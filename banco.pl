#!/usr/bin/perl

use lib "lib";
use temporizador::Schema;

use App::Rad;
App::Rad->run;

sub pre_process {
    my $c = shift;

    $c->stash->{DB} = 'temporizador::Schema'->connect('dbi:Pg:dbname=temporizador');
    (my $resultset = $0) =~ s{^.*/|\.pl$}{}g;
    $c->stash->{resultset} = ucfirst $resultset;
}

sub lista {
    my $c = shift;
    my %opt = %{ $c->options };
    my @colunas = _colunas($c);
    if(keys %opt){
        @colunas = grep {my $col = $_; grep {$_ eq $col} keys %opt} @colunas;
    }
    my @ret;
    for my $linha ($c->stash->{DB}->resultset($c->stash->{resultset})->all){
        my @val;
        for my $col (@colunas){
            my $valor = $linha->$col;
            if(ref($valor)){
               if($valor->can("nome")){
                   push @val, $valor->nome;
               }elsif($valor->can("id")){
                   push @val, $valor->id;
               }else{
                   push @val, $valor;
               }
            } else {
               push @val, $valor;
            }
        }
        push @ret, join " - ", @val;
    }
    join $/, @ret
}

sub colunas {
    my $c = shift;
    join $/, _colunas($c);
}

sub _colunas {
    my $c = shift;
    $c->stash->{DB}->resultset($c->stash->{resultset})->result_source->columns;
}

sub cria {
    my $c = shift;
    
    if($c->stash->{DB}->resultset($c->stash->{resultset})->create($c->options)){
        return "OK";
    }else{
        return "Não criado"
    }
}








