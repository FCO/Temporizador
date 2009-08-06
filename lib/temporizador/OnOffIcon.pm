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
    Gtk2::TrayIcon::;

sub new {
   my $class = shift;
   my %pars  = @_;
   my $self = Glib::Object::new (__PACKAGE__);
   #my $self  = bless $class->SUPER::new({%pars}), $class;
   
   $self->{conf} = $pars{conf};

   my $dbtype = $self->{conf}->config("banco");
   my $dbname = $self->{conf}->config("dbname");
   (my $root   = $0) =~ s|/.*?$|/|;
   die qq|Tipo de banco não configurado (${root}config.pl set_banco TIPO_DO_BANCO (padrão: SQLite))$/| unless $dbtype;
   die qq|Caminho para o banco não encontrado (${root}config.pl set_dbname CAMINHO (padrão: ${root}temporizador.sql))$/|
      unless $dbname;

   my $connect_string = "dbi:" . $self->{conf}->config("banco") . ":dbname=" . $self->{conf}->config("dbname");
   $self->{temp} = $pars{temp} || temporizador->new(
                                                    $connect_string,
                                                    $self->{conf}->config("dbuser"),
                                                    $self->{conf}->config("dbpass"),
                                                   );
   die "conf é obrigatorio" unless $self->{conf} and ref $self->{conf} eq "temporizador::Config";
   $self->{on_png}  = $self->{conf}->config("icone_on")  || "imgs/on.png";
   $self->{off_png} = $self->{conf}->config("icone_off") || "imgs/off.png";
   $self->{event}   = Gtk2::EventBox->new;
   $self->{on_img}  = Gtk2::Image->new_from_pixbuf(
                       Gtk2::Gdk::Pixbuf->new_from_file($self->{conf}->config("root") . "/" . $self->{on_png}) );
   $self->{off_img} = Gtk2::Image->new_from_pixbuf(
                       Gtk2::Gdk::Pixbuf->new_from_file($self->{conf}->config("root") . "/" . $self->{off_png}) );
   $self->{event}->add($self->{temp}->is_logged_in ? $self->{on_img} : $self->{off_img});
   $self->add($self->{event});
   $self->tooltip_timer();
   $self->{event}->signal_connect( 'button_release_event', sub { $self->click(@_) } );
   $self;
}

sub muda_tooltip {
    my $self = shift;
    $self->{tooltip_timer} = Glib::Timeout->add( 1000, sub { $self->tooltip_timer(@_) } );
    my $projeto = $self->{temp}->get_projeto;
    return unless defined $projeto;
    my $nome_projeto = $projeto->nome;

    my $tempo = 'desativado';
    if ( my $log = $self->{temp}->get_log ) {
        $tempo = $log->tempof;
    }

    $self->{event}->set_tooltip_text( ' ' . $nome_projeto . ' (' . $tempo . ') ' );
}

sub tooltip_timer {
    my $self = shift;
    $self->muda_tooltip();
}

sub timer {
    my $self = shift;
    my $event = $self->{event};
    if ( my $log = $self->{temp}->get_log ) {
        my $retorno = $log->tempof;
        Gtk2::Notify->new( "Temporizador", $retorno, 25, $event )->show;
    }
    42;
}

sub click {
    my $self     = shift;
    my $eventbox = shift;
    my $evento   = shift;

    $self->loginout($eventbox) if $evento->button == 1;
    $self->menu($eventbox)     if $evento->button == 3;
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
    my $self  = shift;
    my $proj  = shift;
    my $event = $self->{event};

    eval { $event->remove( $self->{off_img} ) };
    eval { $event->remove( $self->{on_img}  ) };
    my $old_proj = $self->{temp}->get_projeto->nome;
    my $retorno = $self->logout() if $self->{temp}->is_logged_in;
    $retorno .= $/ x 2;
    $self->{temp}->set_projeto( id => $proj );

    $retorno .= "Projeto atual: " . $self->{temp}->get_projeto->nome;
    Gtk2::Notify->new( $self->{temp}->get_projeto->nome, $retorno, 25, $event )->show;
    $event->add( $self->{temp}->is_logged_in ? $self->{on_img} : $self->{off_img} );
    $self->show_all;
}

sub loginout {
    my $self  = shift;
    my $event = shift;

    my $retorno;
    if ( $self->{temp}->is_logged_in ) {
        $retorno = $self->logout();
        Glib::Source->remove($self->{timer}) if defined $self->{timer};
    }
    else {
        $retorno = "Hora Atual: " . $self->{temp}->login;
        $self->{timer} = Glib::Timeout->add( 1000 * 60 * $self->{conf}->config("tempo_alerta"), sub { $self->timer(@_) } )
          if $self->{conf}->config("tempo_alerta");
    }

    Gtk2::Notify->new( $self->{temp}->get_projeto->nome, $retorno, 25, $event )->show;

    $event->remove( $self->{temp}->is_logged_in ? $self->{off_img} : $self->{on_img}  );
    $event->add( $self->{temp}->is_logged_in    ? $self->{on_img}  : $self->{off_img} );
    $self->show_all;
}

sub logout {
    my $self = shift;

    my $ult_proj = $self->{temp}->get_projeto->nome;
    my $tempo_hj = $self->{temp}->tempo_empregado_dia;
    my $tempophj = $self->{temp}->tempo_projeto_dia;
    my $tempo    = $self->{temp}->logout;
    my $return;
    $return .= qq#$ult_proj deslogado:$/$/#;
    $return .= qq#TEMPO: $tempo$/#;
    $return .= qq#Tempo hoje $ult_proj: $tempophj$/#;
    $return .= qq#Tempo hoje total: $tempo_hj$/#;

    $return;
}

42
