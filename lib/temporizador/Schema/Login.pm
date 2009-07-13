package temporizador::Schema::Login;

use strict;
use warnings;
use DateTime;
use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("login");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    sequence => "login_id",
    is_nullable => 0,
    size => 4,
  },
  "data",
  {
    data_type => "datetime",
    default_value => 'now()',
    is_nullable => 0,
    size => 8,
  },
  "logout",
  {
    data_type => "datetime",
    default_value => undef,
    is_nullable => 1,
    size => 8,
  },
  "projeto",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "empregado",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "projeto",
  "temporizador::Schema::Projeto",
  { id => "projeto" },
);
__PACKAGE__->belongs_to(
  "empregado",
  "temporizador::Schema::Empregado",
  { id => "empregado" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-07 03:13:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XMduDa5XZR0/S8iYe5Da9w

sub dataf {
   my $self = shift;
   my $ret = $self->data->hms;
   $ret
}

sub tempo {
   my $self = shift;
   my %par  = @_;
   my($inicio, $fim);

   if(exists $par{inicio} and $self->data < $par{inicio}){
      $inicio = $par{inicio};
   } else {
      $inicio = $self->data;
   }
   if(defined $self->logout) {
      if(exists $par{fim} and $self->logout > $par{fim}){
         $fim = $par{fim};
      } else {
         $fim = $self->logout;
      }
      my $diferenca;
      $diferenca = $fim - $inicio;
      return $diferenca;
   }else{
      return DateTime->now->set_time_zone("America/Sao_Paulo") - $inicio;
   }
}

sub tempof {
   my $self = shift;
   my ($h, $m, $s) = $self->tempo(@_)->in_units("hours", "minutes", "seconds");
   $s %= 60;
   join ":", map {sprintf "%02d", $_} $h, $m, $s
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;
