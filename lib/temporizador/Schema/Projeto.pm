package temporizador::Schema::Projeto;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("projeto");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    sequence => "projeto_id",
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
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("projeto_nome_key", ["nome"]);
__PACKAGE__->has_many(
  "logins",
  "temporizador::Schema::Login",
  { "foreign.projeto" => "self.id" },
);
__PACKAGE__->has_many(
  "paths",
  "temporizador::Schema::Path",
  { "foreign.projeto" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-07 03:13:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7rNSb3Tu8upGtM+MzMFvpw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
