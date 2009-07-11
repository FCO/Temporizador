package temporizador::Schema::Funcao;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("funcao");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    sequence => "funcao_id",
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
  "descricao",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("funcao_nome_key", ["nome"]);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-07 03:13:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:asJNn44gMrIi0Zr2HWkzDQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
