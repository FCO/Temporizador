#!/usr/bin/perl

use lib "lib";
use temporizador::Schema;
use DateTime;

use App::Rad;
App::Rad->run;

sub pre_process {
    my $c = shift;

    $c->load_config("temporizador.conf");

    (my $resultset = $0) =~ s{^.*/|\.pl$}{}g;
    $resultset = ucfirst $resultset;
    my $connect_str = 'dbi:' . $c->config->{banco} . ':dbname=' . $c->config->{dbname};
    $c->stash->{Schema} = 'temporizador::Schema'->connect($connect_str, $c->config->{dbuser}, $c->config->{dbpass});
    $c->stash->{DB}     = $c->stash->{Schema}->resultset($resultset);
}

sub default {
   shift()->execute("lista");
}

sub lista {
    my $c = shift;
    my %opt = %{ $c->options };
    my @colunas = _colunas($c);
    if(keys %opt){
        @colunas = grep {my $col = $_; grep {$_ eq $col} keys %opt} @colunas;
    }
    my @ret;
    for my $linha ($c->stash->{DB}->all){
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
    $c->stash->{DB}->result_source->columns;
}

sub cria {
    my $c = shift;

    my @relation = $c->stash->{DB}->result_source->relationships;

    if(@relation){
        for my $rel(@relation){
           my $int = 1 if $c->options->{$rel} =~ /^\d+$/;
           if(exists $c->options->{$rel}){
               my $rs    = $c->stash->{DB}->result_source->relationship_info($rel)->{source};
               my $relrs = $c->stash->{Schema}->resultset($rs);
               my @cols  = $relrs->result_source->columns;
               for my $col (@cols){
                   if($relrs->result_source->column_info($col)->{data_type} eq "integer"){
                       next unless $int
                   }
                   if(my $obj = $relrs->find({ $col => $c->options->{$rel} })){
                       $c->options->{$rel} = $obj;
                   }
               }
           }
        }
    }
    my @cols  = $c->stash->{DB}->result_source->columns;
    for my $col (@cols){
        if($col eq "data" or $col eq "inicio"){
            $c->options->{$col} = DateTime->now->set_time_zone("America/Sao_Paulo");
        }
    }
    
    if($c->stash->{DB}->create($c->options)){
        return "OK";
    }else{
        return "Não criado"
    }
}

sub apaga {
    my $c = shift;
    
    if($c->stash->{DB}->find($c->options)->delete){
        return "OK";
    }else{
        return "Não apagado"
    }
}








