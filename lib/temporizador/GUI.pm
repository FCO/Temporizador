use utf8;

use Gtk2::TrayIcon;
use Gtk2::Notify -init, "Temporizador";
use strict;
use warnings;

package temporizador::GUI;

use temporizador::TempGtk2;
use temporizador::Menu;
use temporizador::OnOffIcon;

use Glib::Object::Subclass
    Gtk2::Object::;
    
sub new {
   my $class = shift;
   my %pars  = @_;
   #my $self = bless {}, $class;
   my $self = Glib::Object::new (__PACKAGE__);

   $self->{conf} = $pars{conf};
   my $connect_string = "dbi:" . $self->{conf}->config("banco") . ":dbname=" . $self->{conf}->config("dbname");
   $self->{temp} = $pars{temp} || temporizador::TempGtk2->new(
                                                    $connect_string,
                                                    $self->{conf}->config("dbuser"),
                                                    $self->{conf}->config("dbpass"),
                                                    logout_on_destroy => $pars{logout_on_destroy} || 0,
                                                    tempo_alerta      => $self->{conf}->config("tempo_alerta") || 30,
                                                   );
   die "conf é obrigatorio" unless $self->{conf} and ref $self->{conf} eq "temporizador::Config";
   $self->{on_png}  = $self->{conf}->config("icone_on")  || "imgs/on.png";
   $self->{off_png} = $self->{conf}->config("icone_off") || "imgs/off.png";
   $self->{icon} = temporizador::OnOffIcon->new(
                      is_logged_in => $self->{temp}->is_logged_in,
                      on_icon      => $self->{on_png},
                      off_icon     => $self->{off_png},
                   );
   if($self->{temp}->is_logged_in){
      $self->{icon}->on;
   } else {
      $self->{icon}->off;
   }
   $self->{icon}->signal_connect("clicked_bt1" => sub {$self->login_or_logout});
   $self->{icon}->signal_connect("clicked_bt3" => sub {$self->menu});
   $self->{temp}->signal_connect("change_tooltip" => sub {$self->{icon}->set_tooltip(@_[1, 2])});
   #$self->{temp}->signal_connect("notify_timer" => sub { print "SINAL!!! (@_)$/" });
   $self->{temp}->signal_connect("notify_timer" => sub {
         shift;
         my $projeto = shift;
         my $tempo   = shift;
         Gtk2::Notify->new(
                            $projeto,
                            $/ . "Até agora:$/$tempo",
                            25,
                            $self->{icon}
                          )->show;
      }
   );
   $self;
}

sub login_or_logout {
   my $self = shift;

   my ($msg, $type);
   if($self->{temp}->is_logged_in){
      $type = "Logout";
      if(my $tempo = $self->{temp}->logout) {
         $self->{icon}->off;
         my $tempo_hj = $self->{temp}->tempo_empregado_dia;
         my $tempophj = $self->{temp}->tempo_projeto_dia;
         $msg  = qq#Tempo: $tempo$/#;
         $msg .= qq#Tempo hoje no projeto: $tempophj$/#;
         $msg .= qq#Tempo total de hoje: $tempo_hj$/#;

      }
   } else {
      $type = "Login";
      if(my $hora_atual = $self->{temp}->login) {
         $self->{icon}->on;
         $msg = "Hora atual: $hora_atual";
      }
   }
   Gtk2::Notify->new(
                      "$type no projeto: " . $self->{temp}->get_projeto->nome,
                      $/ . $msg,
                      25,
                      $self->{icon}
                    )->show;
}

sub show_all {
   my $self = shift;
   $self->{icon}->show_all;
}

sub menu {
    my $self = shift;
    my $menu = temporizador::Menu->new(conf => $self->{conf}, temp => $self->{temp});
    $menu->signal_connect("selected_project" => sub { shift; $self->muda_projeto( shift ) } );
    $menu->show_all;
    no warnings;
    $menu->popup( undef, undef, undef, 3, undef, undef );
}

sub muda_projeto {
   my $self     = shift;
   my $new_proj = shift;
   my $old_proj = $self->{temp}->get_projeto->nome;
   my $retorno = $self->{temp}->logout if $self->{temp}->is_logged_in;
   $self->{temp}->set_projeto( id => $new_proj );
   if($self->{temp}->is_logged_in){
      $self->{icon}->on;
   } else {
      $self->{icon}->off;
   }
   Gtk2::Notify->new(
                      "Novo Projeto: " . $self->{temp}->get_projeto->nome,
                      "Tempo do projeto anterior ($old_proj):$/" . ($retorno || "00:00:00"),
                      25,
                      $self->{icon}
                    )->show;
   1
}

42
