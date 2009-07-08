package temporizador::Schema::Empregado;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("empregado");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('empregado_id'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "nome",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "cpf",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 14,
  },
  "email",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("empregado_cpf_key", ["cpf"]);
__PACKAGE__->add_unique_constraint("empregado_email_key", ["email"]);
__PACKAGE__->has_many(
  "logins",
  "temporizador::Schema::Login",
  { "foreign.empregado" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-07 03:13:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lhVMlSJ2o+fixaa3Ib679A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
