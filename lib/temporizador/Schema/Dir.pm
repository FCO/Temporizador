package temporizador::Schema::Dir;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("dir");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    sequence => "dir_id",
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
  "md5",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 32,
  },
  "criacao",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 1,
    size => 8,
  },
  "atualizacao",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 1,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("dir_caminho_key", ["caminho"]);
__PACKAGE__->has_many(
  "arqs",
  "temporizador::Schema::Arq",
  { "foreign.dir" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-07 03:13:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lLVK0JHkCZmzHSKwitPtew


# You can replace this text with custom content, and it will be preserved on regeneration
1;
