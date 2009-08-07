use utf8;

use Gtk2::Notify -init, "Temporizador";
use strict;
use warnings;

package temporizador::TempGtk2;

use temporizador;

#use base "Gtk2::TrayIcon";

use base "temporizador";

use Glib::Object::Subclass
    Gtk2::Object::, signals => {
                                  'change_tooltip' => {param_types => [qw/Glib::Scalar Glib::Scalar/]},
                                  'notify_timer'   => {param_types => [qw/Glib::Scalar Glib::Scalar/]},
                                  'login'          => {param_types => [qw/Glib::Scalar/]},
                                  'logout'         => {param_types => [qw/Glib::Scalar Glib::Scalar/]},
                                  'change_project' => {param_types => [qw/Glib::Scalar Glib::Scalar Glib::Scalar/]},
                               }
    ;

sub new {
   my $class   = shift;
   my $connect = shift;
   my $dbstr   = shift;
   my $dbpass  = shift;
   my %pars  = @_;
   my $lod = delete $pars{logout_on_destroy};
   my $self = Glib::Object::new (__PACKAGE__);
   my $temp_obj = temporizador->new($connect, $dbstr, $dbpass, %pars, logout_on_destroy => 0);
   for my $key(keys %$temp_obj){
      $self->{$key} = $temp_obj->{$key};
   }
   $self->{logout_on_destroy} = $lod;
   $self->{tooltip_timer} = Glib::Timeout->add( 1000, sub{
                                                         $self->signal_emit(
                                                            "change_tooltip",
                                                            $self->get_projeto->nome,
                                                            $self->is_logged_in ? $self->get_log->tempof : undef,
                                                         ); 1000 } );
   $self->{notify_time} = $pars{tempo_alerta};
   $self->signal_connect("login", sub{ $self->set_timer($_[1]) }) if $self->{notify_time};
   $self->signal_connect("logout", sub{ Glib::Source->remove($self->{notify_timer})
      if $self->{notify_time} and exists $self->{notify_timer} });
   if($self->is_logged_in){
      $self->signal_emit("login", $self->get_projeto->nome);
   }
   $self;
}

sub set_timer {
   my $self      = shift;
   my $proj_name = shift;
   $self->{notify_timer} = Glib::Timeout->add( $self->{notify_time} * 1000 * 60,
                                                      sub{
                                                         $self->signal_emit(
                                                            "notify_timer",
                                                            $self->get_projeto->nome,
                                                            $self->get_log->tempof,
                                                         ); $self->is_logged_in } );
}

sub login {
   my $self = shift;
   $self->signal_emit("login", $self->get_projeto->nome);
   $self->SUPER::login(@_);
}

sub logout {
   my $self = shift;
   $self->signal_emit("logout", $self->get_projeto->nome, $self->get_log->tempof);
   $self->SUPER::logout(@_);
}

42
