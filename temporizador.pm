package temporizador;

use lib "lib";
use temporizador::Schema;
use File::Find;
use Digest::MD5;
use warnings;

sub new {
   my $class   = shift;
   my $connect = shift;
   my $schema  = temporizador::Schema->connection($connect);
   my $hash = {
               rs_dir   => $schema->resultset('Dir')      ,
               rs_arq   => $schema->resultset('Arq')      ,
               rs_path  => $schema->resultset('Path')     ,
               rs_proj  => $schema->resultset('Projeto')  ,
               rs_login => $schema->resultset('Login')    ,
               rs_empre => $schema->resultset('Empregado'),
              };
   my $self = bless $hash, $class;
}

sub set_empregado {
   my $self  = shift;
   my %pars  = @_;

   for my $chave (keys %pars) {
      $pars_filtrados{ $chave } = $pars{ $chave } if grep {$_ eq $chave} qw/id cpf email/;
   }

   $self->{empregado} = $self->{rs_empre}->find(\%pars_filtrados);
}

sub get_empregado {
   my $self = shift;
   $self->{empregado}
}

sub get_projetos {
   my $self = shift;
   my @tmp = $self->{rs_proj}->all
}

sub set_projeto {
   my $self  = shift;
   my %pars  = @_;

   if(keys %pars){
      for my $chave (keys %pars) {
         $pars_filtrados{ $chave } = $pars{ $chave } if grep {$_ eq $chave} qw/id nome/;
      }
      $self->{projeto} = $self->{rs_proj}->find(\%pars_filtrados);
   }else{
      my $user = $self->get_empregado;
      my $log = $user->search_related("logins", undef, {order_by => "data DESC"})->first;
      $self->{projeto} = $log->projeto;
      #my @projs;
      #if((@projs = $self->{rs_proj}->search(undef)) > 1){
      #   die "Projetos...";
      #} else {
      #   $self->{projeto} = $projs[0];
      #}
   }
}

sub get_projeto {
   my $self = shift;
   $self->{projeto}
}

sub get_caminhos {
   my $self = shift;
   map {$_->caminho} $self->{projeto}->paths->all
}

sub get_log {
   my $self = shift;

   my $logs = $self->get_empregado->search_related("logins", {projeto => $self->get_projeto->id});
   ($logs->search(logout => undef)->all)[0];
}

sub is_logged_in {
   my $self = shift;

   defined $self->get_log
}

sub login {
   my $self = shift;

   return if $self->is_logged_in;

   $self->get_empregado->create_related('logins', {projeto => $self->get_projeto->id});
   $self->get_log->dataf;
}

sub logout {
   my $self = shift;

   my $log = $self->get_log;
   return unless defined $log;

   $log->update({logout => 'now()'});
   $log->tempo;
   #$self->{rs_login}->search(
   #                          {
   #                           id => $log->id
   #                          }, 
   #                          {
   #                           "select" => ['logout - data'], 
   #                           as       => ['tempo']
   #                          }
   #                         )->single->get_column("tempo");
}

sub get_dir {
   my $self = shift;
   my %pars = @_;

   for my $chave (keys %pars) {
      $pars_filtrados{ $chave } = $pars{ $chave } if grep {$_ eq $chave} qw/id caminho/;
   }

   $self->{rs_dir}->find(\%pars_filtrados);
}

sub get_arq {
   my $self = shift;
   my %pars = @_;

   for my $chave (keys %pars) {
      $pars_filtrados{ $chave } = $pars{ $chave } if grep {$_ eq $chave} qw/id nome dir/;
   }

   $self->{rs_arq}->find(\%pars_filtrados);
}

sub get_arq_in_dir {
   my $self = shift;
   my $dir  = shift;
   my $nome = shift;

   return unless defined $dir;

   $dir->find_related("arqs", {nome => $nome});
}

sub update_dir {
   my $self = shift;
   my $dir  = shift;

   my $md5 = Digest::MD5::md5_hex(join "|", <$dir/*>);

   if(my $dir_obj = $self->get_dir(caminho => $dir)) {

      if($md5 ne $dir_obj->md5) {
         $dir_obj->update({md5 => $md5, atualizacao => 'now()'});
         return "modificado";
      }
      return
   }
   $self->{rs_dir}->create({caminho => $dir, md5 => $md5});
   return "criado"
}

sub update_arq {
   my $self = shift;
   my $dir  = shift;
   my $arq  = shift;

   my $dir_obj = $self->get_dir(caminho => $dir);
   unless(defined $dir_obj){
      $self->update_dir($dir);
      $dir_obj = $self->get_dir(caminho => $dir);
   }

   open my $FILE, $dir . "/$arq" || die;
   my $md5 = Digest::MD5::md5_hex(join $/, <$FILE>);
   close $FILE;

   if(my $arq_obj = $self->get_arq_in_dir($dir_obj, $arq)) {

      if($md5 ne $arq_obj->md5) {
         $arq_obj->update({md5 => $md5, atualizacao => 'now()'});
         return "modificado";
      }
      return
   }
   $dir_obj->create_related("arqs", {nome => $arq, md5 => $md5});
   return "criado"
}

sub tempo_total_projeto {
   my $self    = shift;
   my $projeto = shift;

   my $proj_obj;
   if(not defined $projeto) {
      $proj_obj = $self->get_projeto;
   } else {
      if($projeto =~ /^\d+$/){
         $proj_obj = $self->{rs_proj}->find($projeto);
      }else{
         $proj_obj = $self->{rs_proj}->find({nome => $projeto});
      }
   }

   my $tempo = $proj_obj->search_related("logins",
                   undef,
                   {
                   "select" => [
                                "date_trunc('second', sum(CASE WHEN logout is NULL THEN now() ELSE logout END - data))"
                               ],
                   as       => [qw/tempo_total/],
                   }
                  )->single;
   $tempo->get_column("tempo_total");
}

sub tempo_empregado_dia {
   my $self      = shift;
   my $empregado = shift;

   my $empre_obj;
   if(not defined $empregado) {
      $empre_obj = $self->get_empregado;
   } else {
      if($empregado =~ /^\d+$/){
         $empre_obj = $self->{rs_empre}->find($empregado);
      }elsif($empregado =~ /\@/){
         $empre_obj = $self->{rs_empre}->find({email => $empregado});
      }elsif($empregado =~ /^\d{3}\.\d{3}\.\d{3}-\d{2}$/){
         $empre_obj = $self->{rs_empre}->find({cpf => $empregado});
      }else {
         $empre_obj = $self->{rs_empre}->find({nome => $empregado});
      }
   }
   my $tempo = $empre_obj->search_related("logins",
                  data => {'>=' => "today()"},
                  {
                  "select" => [
                               "date_trunc('second', sum(CASE WHEN logout is NULL THEN now() ELSE logout END - data))"
                              ],
                  as       => [qw/tempo_total/],
                  }
                 )->single;
   $tempo->get_column("tempo_total");
                
}

sub tempo_projeto_dia {
   my $self      = shift;
   my $empregado = shift;

   my $empre_obj;
   if(not defined $empregado) {
      $empre_obj = $self->get_empregado;
   } else {
      if($empregado =~ /^\d+$/){
         $empre_obj = $self->{rs_empre}->find($empregado);
      }elsif($empregado =~ /\@/){
         $empre_obj = $self->{rs_empre}->find({email => $empregado});
      }elsif($empregado =~ /^\d{3}\.\d{3}\.\d{3}-\d{2}$/){
         $empre_obj = $self->{rs_empre}->find({cpf => $empregado});
      }else {
         $empre_obj = $self->{rs_empre}->find({nome => $empregado});
      }
   }
   my $tempo = $empre_obj->search_related("logins",
                  data => {'>=' => "today()"},
                  projeto => $self->get_projeto->id,
                  {
                  "select" => [
                               "date_trunc('second', sum(CASE WHEN logout is NULL THEN now() ELSE logout END - data))"
                              ],
                  as       => [qw/tempo_total/],
                  }
                 )->single;
   $tempo->get_column("tempo_total");
                
}

sub tempo_empregado_mes {
   my $self      = shift;
   my $empregado = shift;

   my $empre_obj;
   if(not defined $empregado) {
      $empre_obj = $self->get_empregado;
   } else {
      if($empregado =~ /^\d+$/){
         $empre_obj = $self->{rs_empre}->find($empregado);
      }elsif($empregado =~ /\@/){
         $empre_obj = $self->{rs_empre}->find({email => $empregado});
      }elsif($empregado =~ /^\d{3}\.\d{3}\.\d{3}-\d{2}$/){
         $empre_obj = $self->{rs_empre}->find({cpf => $empregado});
      }else {
         $empre_obj = $self->{rs_empre}->find({nome => $empregado});
      }
   }
   my $tempo = $empre_obj->search_related("logins",
                  undef,
                  {
                  "select" => [
                               "date_trunc('second', sum(CASE WHEN logout is NULL THEN now() ELSE logout END - data))",
                               "date_trunc('month', data) AS mes",
                              ],
                  as       => [qw/tempo_total mes/],
                  group_by => "mes",
                  order_by => "mes DESC",
                  }
                 )->single;
   $tempo->get_column("tempo_total");
                
}

sub tempo_extra_empregado_mes {
   my $self      = shift;
   my $empregado = shift;

   my $empre_obj;
   if(not defined $empregado) {
      $empre_obj = $self->get_empregado;
   } else {
      if($empregado =~ /^\d+$/){
         $empre_obj = $self->{rs_empre}->find($empregado);
      }elsif($empregado =~ /\@/){
         $empre_obj = $self->{rs_empre}->find({email => $empregado});
      }elsif($empregado =~ /^\d{3}\.\d{3}\.\d{3}-\d{2}$/){
         $empre_obj = $self->{rs_empre}->find({cpf => $empregado});
      }else {
         $empre_obj = $self->{rs_empre}->find({nome => $empregado});
      }
   }
   my $tempo = $self->{rs_login}->search_literal(
      "SELECT extra 
       FROM (
          SELECT date_trunc('month', dia) AS mes, sum(extra) AS extra 
          FROM (
             SELECT date_trunc('day', data) AS dia,
                date_trunc('second', sum(
                CASE WHEN logout is NULL THEN now()
                   ELSE logout
                END - data)) - interval '8 hour' AS extra 
             FROM login me 
             WHERE ( ( ( me.empregado = ? ) ) ) group by dia order by dia) AS tudo 
          WHERE extra > interval '0 sec' group by mes) AS meses 
       WHERE mes = month()",
       $empre_obj->id,
   )->single;
   $tempo->get_column("extra");
                
}

sub tempo_extra_empregado_dia {
   my $self      = shift;
   my $empregado = shift;

   my $empre_obj;
   if(not defined $empregado) {
      $empre_obj = $self->get_empregado;
   } else {
      if($empregado =~ /^\d+$/){
         $empre_obj = $self->{rs_empre}->find($empregado);
      }elsif($empregado =~ /\@/){
         $empre_obj = $self->{rs_empre}->find({email => $empregado});
      }elsif($empregado =~ /^\d{3}\.\d{3}\.\d{3}-\d{2}$/){
         $empre_obj = $self->{rs_empre}->find({cpf => $empregado});
      }else {
         $empre_obj = $self->{rs_empre}->find({nome => $empregado});
      }
   }
   my $tempo = $empre_obj->search_related("logins",
                  data => {'>=' => "today()"},
                  {
                  "select" => [
                               "CASE WHEN 
                                  date_trunc('second', sum(
                                      CASE WHEN logout is NULL THEN now()
                                           ELSE logout
                                      END - data)) - interval '8 hour'
                                  > interval '0 sec'
                                THEN
                                  date_trunc('second', sum(
                                      CASE WHEN logout is NULL THEN now()
                                           ELSE logout
                                      END - data)) - interval '8 hour'
                               ELSE interval '0 sec'
                               END
                               "
                              ],
                  as       => [qw/tempo_total/],
                  }
                 )->single;
   $tempo->get_column("tempo_total");
                
}










42
