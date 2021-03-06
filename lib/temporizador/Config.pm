package temporizador::Config;

use strict;
use warnings;
use Carp;

=pod 

=head1 new

   my $conf = temporizador::Config->new( $opcao1, $opcao2, $opcao3, ...)

instancia novo arquivo de configuracao. Pode receber uma lista de elementos como opcoes.

=cut


sub new {
   my $class   = shift;
   my @options = @_;
   my $self    = bless {
                         files   => [],
                         options => [@options],
                         conf    => {},
                         mudou   => 0,
                       }, $class;
   $self;
}

=pod

=head1 load_config

   $conf->load_config('arquivo.conf')
   $conf->load_config('arq1.conf', 'arq2.conf', ...)

carrega um ou mais arquivos de configuracao passados como parametro. 
Retorna o proprio objeto, para facilitar encadeamento.

=cut

sub load_config {
   my $self  = shift;
   my @files = @_;
   return if grep {not -f} @files;
   push @{ $self->{files} }, @files;
   $self->{mudou}++;
   $self;
}

=pod 

=head1 config

  my $valor = $conf->config('item');  # getter
  
  $conf->config('item') = $valor;     # setter

Acessor principal para valores dentro de arquivos de configuracao

=cut 

sub config :lvalue {
   my $self = shift;
   my $opt  = shift;
   $self->{conf} = $self->confs_by_files if $self->{mudou};
   $self->{mudou} = 0;
   $self->{conf}->{$opt} = "" unless exists $self->{conf}->{$opt};
   $self->{conf}->{$opt}
}

=pod

=head1 confs_by_files

=cut

sub confs_by_files {
   my $self = shift;
   my %conf;
   FILE: for my $file (reverse @{ $self->{files} }){
      if(open my $FILE, "<", $file){
         LINE: while(my $line = <$FILE>){
            my ($name, $value) = $line =~ /^\s*(\w+)\s*:\s*(.+?)\s*$/;
            next LINE if @{ $self->{options} } and not grep {$_ eq $name} @{ $self->{options} };
            $conf{$name} = $value;
         }
         close $FILE;
      }
   }
   \%conf
}

=pod

=head1 save_config

  $conf->save_config('arquivo.conf');

Grava as configuracoes de $conf no arquivo especificado.

=cut

sub save_config {
   my $self = shift;
   my $file = shift;
   open my $FILE, ">", $file || croak "Couldn't open file \"$file\"";
   if(@{ $self->{options} }){
      for my $name(sort @{ $self->{options} }){
         print { $FILE } "$name: ", $self->{conf}->{$name}, $/;
      }
   } else {
      for my $name (sort keys %{ $self->{conf} }){
         print { $FILE } "$name: ", $self->{conf}->{$name}, $/;
      }
   }
   $self;
}


return 42
