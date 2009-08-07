use utf8;

use Gtk2::TrayIcon;
use Gtk2::Notify -init, "Temporizador";
use strict;
use warnings;

package temporizador::OnOffIcon;

use temporizador;
use temporizador::Menu;

#use base "Gtk2::TrayIcon";

use Glib::Object::Subclass
    Gtk2::TrayIcon::, signals => {
                                    'clicked_bt1' => {},
                                    'clicked_bt2' => {},
                                    'clicked_bt3' => {},
                                    'on'          => {},
                                    'off'         => {},
                                 }
    ;

sub new {
   my $class = shift;
   my %pars  = @_;
   my $self = Glib::Object::new (__PACKAGE__);
   $self->{on_png}  = $pars{on_icon};
   $self->{off_png} = $pars{off_icon};
   $self->{event}   = Gtk2::EventBox->new;
   $self->{on_img}  = Gtk2::Image->new_from_pixbuf(
                       Gtk2::Gdk::Pixbuf->new_from_file($self->{on_png}) );
   $self->{off_img} = Gtk2::Image->new_from_pixbuf(
                       Gtk2::Gdk::Pixbuf->new_from_file($self->{off_png}) );
   $self->add($self->{event});
   $self->{tooltip} = Gtk2::Tooltips->new;
   $self->{event}->signal_connect( 'button_release_event', sub { $self->clicked(@_) } );
   $self;
}

sub set_tooltip {
   my $self = shift;
   my $proj = shift;
   my $time = shift;
   $time = defined $time ? $time : "desativado";
   
   $self->{tooltip}->set_tip($self, "$proj ($time)");
}

sub clicked {
   my $self     = shift;
   my $eventbox = shift;
   my $evento   = shift;

   $self->signal_emit("clicked_bt" . $evento->button);
}

sub on {
    my $self = shift;
    $self->{event}->remove($self->{atual_img}) if $self->{atual_img};
    $self->{atual_img} = $self->{on_img};
    $self->{event}->add($self->{atual_img});
    $self->{state} = 1;
    my $ret = $self->show_all;
    $self->signal_emit("on");
    $ret
}

sub off {
    my $self = shift;
    $self->{event}->remove($self->{atual_img}) if $self->{atual_img};
    $self->{atual_img} = $self->{off_img};
    $self->{event}->add($self->{atual_img});
    $self->{state} = 0;
    my $ret = $self->show_all;
    $self->signal_emit("off");
    $ret
}

sub get_status {
   my $self = shift;
   $self->{status};
}


42
