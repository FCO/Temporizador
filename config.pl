#!/usr/bin/perl

use App::Rad;
App::Rad->run;


sub post_process {
    my $c = shift;
    my %conf;
    return $c->post_process unless $c->cmd =~ /^[sg]et_/;
    open $CONF, "<", "temporizador.conf";
    if(defined $CONF){
        while(my $linha = <$CONF>){
            $linha =~ /^\s*(\w+)\s*:\s*(.*)\s*$/;
            $conf{$1} = $2;
        }
    }
    close $CONF;
    if($c->stash->{valor}){
        $conf{$c->stash->{par}} = $c->stash->{valor};
        open $CONF, ">", "temporizador.conf";
        for my $nome(sort keys %conf){
            print { $CONF } "$nome: $conf{$nome}$/";
        }
        close $CONF;
    } else {
        print $conf{$c->stash->{par}}, $/;
    }
}

sub set_user {
    my $c = shift;
    $c->stash->{par}   = "user";
    $c->stash->{valor} = $c->argv->[0] || "";
}

sub get_user {
    my $c = shift;
    $c->stash->{par}   = "user";
}

sub set_banco {
    my $c = shift;
    $c->stash->{par}   = "banco";
    $c->stash->{valor} = $c->argv->[0] || "";
}

sub get_banco {
    my $c = shift;
    $c->stash->{par}   = "banco";
}

sub set_dbname {
    my $c = shift;
    $c->stash->{par}   = "dbname";
    $c->stash->{valor} = $c->argv->[0] || "";
}

sub get_dbname {
    my $c = shift;
    $c->stash->{par}   = "dbname";
}

sub set_dbuser {
    my $c = shift;
    $c->stash->{par}   = "dbuser";
    $c->stash->{valor} = $c->argv->[0] || "";
}

sub get_dbuser {
    my $c = shift;
    $c->stash->{par}   = "dbuser";
}

sub set_dbpass {
    my $c = shift;
    $c->stash->{par}   = "dbpass";
    $c->stash->{valor} = $c->argv->[0] || "";
}

sub get_dbpass {
    my $c = shift;
    $c->stash->{par}   = "dbpass";
}

sub set_root {
    my $c = shift;
    $c->stash->{par}   = "root";
    $c->stash->{valor} = $c->argv->[0] || "";
}

sub get_root {
    my $c = shift;
    $c->stash->{par}   = "root";
}





