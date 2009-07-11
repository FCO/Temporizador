package temporizador::Schema::Path;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("path");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    sequence => "path_id",
    is_nullable => 0,
    size => 4,
  },
  "caminho",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "projeto",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("path_caminho_key", ["caminho"]);
__PACKAGE__->belongs_to(
  "projeto",
  "temporizador::Schema::Projeto",
  { id => "projeto" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-07 03:13:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PTfUixuPwG7lzIlEeNcFvw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
