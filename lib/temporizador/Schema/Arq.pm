package temporizador::Schema::Arq;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("arq");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    sequence => "arq_id",
    is_nullable => 0,
    size => 4,
  },
  "dir",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "nome",
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
    default_value => undef,
    is_nullable => 1,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("arq_dir_key", ["dir", "nome"]);
__PACKAGE__->belongs_to("dir", "temporizador::Schema::Dir", { id => "dir" });


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-07 03:13:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kXWEKpZ2Il5bzU+Mp87gnA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
