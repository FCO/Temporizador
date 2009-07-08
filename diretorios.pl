use File::Find;
use Digest::MD5;
use lib "lib";
use temporizador::Schema;

our $schema = temporizador::Schema->connection('dbi:Pg:dbname=temporizador');
our $db_dir = $schema->resultset('Dir');
our $db_arq = $schema->resultset('Arq');
our $path   = $schema->resultset('Path');
our $proj   = $schema->resultset('Projeto');

our $login   = $schema->resultset('Login');

our (@criados, @modificados);

my $projeto = shift;
my @caminhos;

my $proj_atual;

if(defined $projeto) {
   $proj_atual = $proj->find({nome => $projeto});
   @caminhos = map {$_ -> caminho} $proj_atual->paths->all;
} else {
   die "Erro" unless $proj->all == 1;
   $proj_atual = $proj->single;
   @caminhos = map {$_->caminho} $proj_atual->paths->all;
}

my $login;

unless(defined($login = $proj_atual->search_related("logins", {logout => undef})->single)){
   $proj_atual->create_related("logins", {});
   return;
}
$login->update({logout => "now()"});

File::Find::finddepth(\&subrotina, @caminhos);

print "Criados:$/", map {" " x 3, $_, $/} @criados if @criados;
print "Modificados:$/", map {" " x 3, $_, $/} @modificados if @modificados;

sub subrotina {
   my $dir = $File::Find::dir;
   my $arq = $_;
   my $linha_dir = $db_dir->find({caminho => $dir});
   if(-d $File::Find::name) {
      if(not defined $linha_dir){
         push @criados, $dir;
         $db_dir->create({caminho => $dir, md5 => Digest::MD5::md5_hex(join "|", <$dir/*>)});
      }else{
         my $md5 = Digest::MD5::md5_hex(join "|", <$dir/*>);
         if($linha_dir->md5 ne $md5){
            push @modificados, $dir;
            $linha_dir->update({md5 => $md5});
         }
      }
   } else {
      my $linha_arq = $linha_dir->search_related("arqs", {nome => $arq})->single;
      open my $FILE, "$File::Find::name";
      if(not defined $linha_arq){
         $linha_dir->create_related("arqs", {nome => $arq, md5 => Digest::MD5::md5_hex(join $/, <$FILE>)});
         push @criados, $arq;
      } else {
         my $md5 = Digest::MD5::md5_hex(join $/, <$FILE>);
         if($linha_arq->md5 ne $md5){
            push @modificados, $arq;
            $linha_arq->update({md5 => $md5});
         }
      }
      close $FILE;
   }
}
