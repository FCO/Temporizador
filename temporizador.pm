package temporizador;

use lib "lib";
use temporizador::Schema;
#use File::Find;
#use Digest::MD5;
use warnings;
use DateTime;
use DateTime::Duration;

sub new {
   my $class   = shift;
   my $connect = shift;
   my $schema  = temporizador::Schema->connection($connect, @_);
   my $hash = {
               rs_dir   => $schema->resultset('Dir')      ,
               rs_arq   => $schema->resultset('Arq')      ,
               rs_path  => $schema->resultset('Path')     ,
               rs_proj  => $schema->resultset('Projeto')  ,
               rs_login => $schema->resultset('Login')    ,
               rs_empre => $schema->resultset('Empregado'),
               timezone => "America/Sao_Paulo",
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

sub ultimo_login_projeto {
   my $self  = shift;
   my %pars  = @_;
   $projeto = $self->{rs_proj}->find(\%pars);
   my $ult = $projeto->search_related("logins", undef, {order_by => "data DESC"})->first;
   return unless $ult;
   $ult->data->dmy("/") . " " . $ult->data->hms;
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
      die "Usuario não configurado$/" unless $user;
      my $log = $user->search_related("logins", undef, {order_by => "data DESC"})->first;
      if($log){
         return $self->{projeto} = $log->projeto;
      }else{
         return $self->{projeto} = $self->{rs_proj}->first;
      }
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

   my $proj = $self->get_projeto;
   return unless $proj;

   my $logs = $self->get_empregado->search_related("logins", {projeto => $proj->id});
   ($logs->search(logout => undef)->all)[0];
}

sub is_logged_in {
   my $self = shift;

   defined $self->get_log
}

sub login {
   my $self = shift;

   return if $self->is_logged_in;

   $self->get_empregado->create_related('logins', {
                                                   projeto => $self->get_projeto->id,
                                                   data    => DateTime->now->set_time_zone($self->{timezone}),
                                                  }
   );
   $self->get_log->dataf;
}

sub logout {
   my $self = shift;

   my $log = $self->get_log;
   return unless defined $log;

   $log->update({logout => DateTime->now->set_time_zone($self->{timezone})});
   $log->tempof;
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
         $dir_obj->update({md5 => $md5, atualizacao => DateTime->now->set_time_zone($self->{timezone})});
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
         $arq_obj->update({md5 => $md5, atualizacao => DateTime->now->set_time_zone($self->{timezone})});
         return "modificado";
      }
      return
   }
   $dir_obj->create_related("arqs", {nome => $arq, md5 => $md5});
   return "criado"
}

sub tempo_total_projeto {
   my $self    = shift;
   my %par     = @_;
   my $projeto = $par{projeto};

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

   my $tempo = $proj_obj->search_related("logins");
   my $tempo_total = DateTime::Duration->new;
   for my $log (map{$_->tempo}$tempo->all){
         $tempo_total += $log;
   }
   return $tempo_total if exists $par{retorno} and $par{retorno} eq "DateTime";
   ($h, $m, $s) = map {sprintf "%02d", $_} $tempo_total->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   "$h:$m:$s"
}

sub tempo_empregado_dia {
   my $self      = shift;
   my %par       = @_;
   my $empregado = $par{empregado};
   my $dia       = $par{DateTime};
   unless(defined $dia){
      if(exists $par{dia} and exists $par{mes} and exists $par{ano}){
         $dia = DateTime->new(day => $par{dia}, month => $par{mes}, year => $par{ano});
      } else {
         $dia = DateTime->now;
      }
   }
   $dia->set_time_zone($self->{timezone})->truncate(to => 'day');
   my %dia = (
              inicio => $dia->clone->truncate(to => 'day'),
              fim    => $dia->clone->truncate(to => 'day')->add(days => 1)->subtract(seconds => 1)
             );

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
   my $tempo = $empre_obj->search_related("logins", [
                                                     {
                                                      data   => {
                                                                 '>=' => $dia->clone->ymd,
                                                                 '<' => $dia->clone->add(days => 1)->ymd,
                                                                }
                                                     },
                                                     {
                                                      logout => {
                                                                 '>=' => $dia->clone->ymd,
                                                                 '<' => $dia->clone->add(days => 1)->ymd,
                                                                }
                                                     },
                                                    ]
   );
   my $tempo_total = DateTime::Duration->new;
   for my $log ($tempo->all){
         $tempo_total += $log->tempo(%dia);
   }
   return $tempo_total if exists $par{retorno} and $par{retorno} eq "DateTime";
   ($h, $m, $s) = map {sprintf "%02d", $_} $tempo_total->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   "$h:$m:$s"
}

sub tempo_projeto_dia {
   my $self      = shift;
   my %par       = @_;
   my $projeto   = $par{projeto};
   my $empregado = $par{empregado};
   my $dia;
   unless(defined $par{DateTime}){
      if(exists $par{dia} and exists $par{mes} and exists $par{ano}){
         $dia = DateTime->new(day => $par{dia}, month => $par{mes}, year => $par{ano});
      } else {
         $dia = DateTime->now;
      }
   }else{
      $dia = $par{DateTime}->clone;
   }
   $dia->set_time_zone($self->{timezone})->truncate(to => 'day');
   my %dia = (
              inicio => $dia->clone->truncate(to => 'day'),
              fim    => $dia->clone->truncate(to => 'day')->add(days => 1)->subtract(seconds => 1)
             );

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
   my $tempo = $empre_obj->search_related("logins", { -or => [
                                                              {
                                                               data   => {
                                                                          '>=' => $dia->clone->ymd,
                                                                          '<' => $dia->clone->add(days => 1)->ymd,
                                                                         }
                                                              },
                                                              {
                                                               logout => {
                                                                          '>=' => $dia->clone->ymd,
                                                                          '<' => $dia->clone->add(days => 1)->ymd,
                                                                         }
                                                              },
                                                             ],
                                                     projeto => $projeto || $self->get_projeto->id
                                                    }
   );
   my $tempo_total = DateTime::Duration->new;
   for my $log (map{$_->tempo(%dia)}$tempo->all){
         $tempo_total += $log->is_negative ? $log * -1 : $log;
   }
   return $tempo_total if exists $par{retorno} and $par{retorno} eq "DateTime";
   ($h, $m, $s) = map {sprintf "%02d", $_} $tempo_total->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   "$h:$m:$s"
}

sub tempo_total_projeto_dia {
   my $self      = shift;
   my %par       = @_;
   my $projeto   = $par{projeto};
   my $empregado = $par{empregado};
   my $dia;
   unless(defined $par{DateTime}){
      if(exists $par{dia} and exists $par{mes} and exists $par{ano}){
         $dia = DateTime->new(day => $par{dia}, month => $par{mes}, year => $par{ano});
      } else {
         $dia = DateTime->now;
      }
   }else{
      $dia = $par{DateTime};
   }
   $dia->set_time_zone($self->{timezone})->truncate(to => 'day');
   my %dia = (
              inicio => $dia->clone->truncate(to => 'day'),
              fim    => $dia->clone->truncate(to => 'day')->add(days => 1)->subtract(seconds => 1)
             );

   my $tempo = $self->{rs_proj}->find({nome => $projeto})
             ->search_related("logins", { -or => [
                                                  {
                                                   data   => {
                                                              '>=' => $dia->clone->ymd,
                                                              '<' => $dia->clone->add(days => 1)->ymd,
                                                             }
                                                  },
                                                  {
                                                   logout => {
                                                              '>=' => $dia->clone->ymd,
                                                              '<' => $dia->clone->add(days => 1)->ymd,
                                                             }
                                                  },
                                                 ],
                                        }
   );
   my $tempo_total = DateTime::Duration->new;
   for my $log (map{$_->tempo(%dia)}$tempo->all){
         $tempo_total += $log->is_negative ? $log * -1 : $log;
   }
   return $tempo_total if exists $par{retorno} and $par{retorno} eq "DateTime";
   ($h, $m, $s) = map {sprintf "%02d", $_} $tempo_total->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   "$h:$m:$s"
}

sub tempo_projetos_por_dia {
   my $self      = shift;
   my %par       = @_;
   my $empregado = $par{empregado};
   my $mes       = $par{mes} || DateTime->now->set_time_zone($self->{timezone})->month;
   my $ano       = $par{ano} || DateTime->now->set_time_zone($self->{timezone})->year;
   my $prim = DateTime->new(day => 1, month => $mes, year => $ano);
   my $ulti = DateTime->last_day_of_month(year=>$prim->year,month =>$prim->month)->add(days => 1)->subtract( seconds => 1 );
   $ulti = $ulti > DateTime->now ? DateTime->now : $ulti;
   $prim->add(days => 1);
   $ulti->set_time_zone($self->{timezone})->add(days => 1);
   
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
   my $tempo = $empre_obj->search_related("logins", {data => {'>=' => $prim->ymd, '<=' => $ulti->ymd}});
   my %dias;
   for my $linha($tempo->all){
      unless(exists $dias{$linha->data->day}->{$linha->projeto->id}->{inicio}){
         $dias{$linha->data->day}->{$linha->projeto->id}->{inicio} = $linha->projeto->inicio;
      }
      unless(exists $dias{$linha->data->day}->{$linha->projeto->id}->{fim}){
         $dias{$linha->data->day}->{$linha->projeto->id}->{fim} = $linha->projeto->fim;
      }
      unless(exists $dias{$linha->data->day}->{$linha->projeto->id}->{tempo}){
         $dias{$linha->data->day}->{$linha->projeto->id}->{tempo} = DateTime::Duration->new;
      }
      if($linha->data->clone->truncate(to => 'day') != $linha->logout->clone->truncate(to => 'day')){
         my $data    = $linha->data  ->clone->truncate(to => 'day');
         my $dataf   = $data         ->clone->add(days => 1)->subtract(seconds => 1);
         my $logout  = $linha->logout->clone;
         my %data_atual = (inicio => $data->clone, fim => $dataf);
         until($data_atual{inicio} > $logout){
            unless(exists $dias{$data_atual{inicio}->day}->{$linha->projeto->id}->{tempo}){
               $dias{$data_atual{inicio}->day}->{$linha->projeto->id}->{tempo} = DateTime::Duration->new;
            }
            $dias{$data_atual{inicio}->day}->{$linha->projeto->id}->{tempo}
               += $linha->tempo(%data_atual);
            $data_atual{inicio}->add(days => 1);
            $data_atual{fim}   ->add(days => 1);
         }
      } else {
         $dias{$linha->data->day}->{$linha->projeto->id}->{tempo} += $linha->tempo;
      }
   }
   \%dias
}

sub tempo_empregado_mes {
   my $self      = shift;
   my %par       = @_;
   my $empregado = $par{empregado};
   my $mes       = $par{mes} || DateTime->now->set_time_zone($self->{timezone})->month;
   my $ano       = $par{ano} || DateTime->now->set_time_zone($self->{timezone})->year;
   my $prim = DateTime->new(day => 1, month => $mes, year => $ano)->set_time_zone($self->{timezone});
   my $ulti = DateTime->last_day_of_month(month => $mes, year => $ano)->add(days => 1)->subtract( seconds => 1 );;
   $ulti = $ulti > DateTime->now ? DateTime->now : $ulti;
   $ulti->set_time_zone($self->{timezone});

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
   my $tempo = $empre_obj->search_related("logins", {data => {'>=' => $prim->ymd, '<=' => $ulti->ymd}});
   my $tempo_total = DateTime::Duration->new;
   for my $log (map {$_->tempo(inicio => $prim, fim => $ulti)} $tempo->all){
      #$tempo_total +=$log->tempo;
      $tempo_total += $log->is_negative ? $log * -1 : $log;
   }
   ($h, $m, $s) = map {sprintf "%02d", $_} $tempo_total->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   "$h:$m:$s"
}

sub tempo_extra_empregado_mes {
   my $self      = shift;
   my %par       = @_;
   my $empregado = $par{empregado};
   my $mes       = $par{mes} || DateTime->now->set_time_zone($self->{timezone})->month;
   my $ano       = $par{ano} || DateTime->now->set_time_zone($self->{timezone})->year;
   my $prim = DateTime->new(day => 1, month => $mes, year => $ano)->set_time_zone($self->{timezone});
   my $ulti = DateTime->last_day_of_month(month => $mes, year => $ano)->add(days => 1)->subtract( seconds => 1 );;
   $ulti = $ulti > DateTime->now ? DateTime->now : $ulti;
   $ulti->set_time_zone($self->{timezone});

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
   my $atual = $prim->clone;
   my $total = DateTime::Duration->new;
   while($atual == $ulti){
      $total += $self->tempo_extra_empregado_dia(DateTime => $atual);
      $atual = $atual->clone->add(days => 1);
   }
   return $total if exists $par{retorno} and $par{retorno} eq "DateTime";
   ($h, $m, $s) = map {sprintf "%02d", $_} $total->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   "$h:$m:$s"
}

sub tempo_extra_empregado_dia {
   my $self      = shift;
   my %par       = @_;
   my $empregado = $par{empregado};
   my $dia       = $par{DateTime};
   unless(defined $dia){
      if(exists $par{dia} and exists $par{mes} and exists $par{ano}){
         $dia = DateTime->new(day => $par{dia}, month => $par{mes}, year => $par{ano})->set_time_zone($self->{timezone});
      } else {
         $dia = DateTime->now->set_time_zone($self->{timezone});
      }
   }
   $dia->truncate(to => 'day');

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
   my $tempo = $empre_obj->search_related("logins", {data => {'>=' => $dia->ymd, '<' => $dia->add(days => 1)->ymd}});
   my $tempo_total = DateTime::Duration->new;
   for my $log (map{$_->tempo}$tempo->all){
         $tempo_total += $log;
   }
   $tempo_total = $tempo_total->hours <= 8 ? DateTime::Duration->new : $tempo_total->subtraction(hours => 8);
   return $tempo_total if exists $par{retorno} and $par{retorno} eq "DateTime";
   ($h, $m, $s) = map {sprintf "%02d", $_} $tempo_total->in_units("hours", "minutes", "seconds");
   $s = sprintf "%02d", $s % 60;
   "$h:$m:$s"
}










42
