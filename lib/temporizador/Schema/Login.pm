package temporizador::Schema::Login;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("login");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('login_id'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "data",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
  "logout",
  {
    data_type => "timestamp without time zone",
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
   my $ret = $1 if $self->data =~ /(\d+:\d+:\d+)/;
   $ret
}

sub tempo {
   my $self = shift;
   my @ret;

   if(defined $self->logout) {
      @ret = temporizador::Schema->resultset('Login')
                ->search({
                          id => $self->id
                         },
                         {
                          "select" => ["date_trunc('second', age(now(), data))"], 
                          as       => [qw/tempo/]
                         });
   }else{
      @ret = temporizador::Schema->resultset('Login')
                ->search({
                          id => $self->id
                         }, 
                         {
                          "select" => ["date_trunc('second', age(now(), data))"], 
                          as       => [qw/tempo/]
                         });
   }
   return $ret[-1]->get_column('tempo');
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;
