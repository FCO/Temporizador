package temporizador::Config;

use strict;
use warnings;
use Carp;

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

sub load_config {
   my $self  = shift;
   my @files = @_;
   return if grep {not -f} @files;
   push @{ $self->{files} }, @files;
   $self->{mudou}++;
   $self;
}

sub config :lvalue {
   my $self = shift;
   my $opt  = shift;
   $self->{conf} = $self->confs_by_files if $self->{mudou};
   $self->{mudou} = 0;
   $self->{conf}->{$opt} = "" unless exists $self->{conf}->{$opt};
   $self->{conf}->{$opt}
}

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
