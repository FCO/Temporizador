use utf8;

use Gtk2::TrayIcon;
use Gtk2::Notify -init, "Temporizador";
use strict;
use warnings;

package temporizador::Menu;

use temporizador;

#use base "Gtk2::Menu";
use Glib::Object::Subclass
    Gtk2::Menu::, signals => {'selected_project' => {param_types => [qw/Glib::Scalar/]}};

sub new {
    my $class = shift;
    my %pars  = @_;
    my $self = Glib::Object::new (__PACKAGE__);
    #my $self  = bless $class->SUPER::new({%pars}), $class;
    
    my $menu_tempo =
      Gtk2::SeparatorMenuItem->new_with_label("Tempo Hoje: " . $pars{tempo_projeto_dia});
    $self->add($menu_tempo);

    my $menu_atual = Gtk2::SeparatorMenuItem->new_with_label(
        "Projeto Atual: " . $pars{proj_atual_nome} );
    $self->add($menu_atual);

    my $menu_sep = Gtk2::SeparatorMenuItem->new();
    $self->add($menu_sep) if keys %{ $pars{projetos} } > 1;

    for my $proj ( sort keys %{ $pars{projetos} } ) {
        next if $pars{proj_atual_id} == $pars{projetos}->{$proj};
        my $menu_proj = Gtk2::MenuItem->new_with_label( $proj );
        $menu_proj->signal_connect(
            activate => sub { $self->signal_emit( "selected_project", $pars{projetos}->{$proj} ) } );
        $self->add($menu_proj);
    }

    $menu_sep = Gtk2::SeparatorMenuItem->new();
    $self->add($menu_sep);

    my $menu_config = Gtk2::MenuItem->new_with_label("Configuração");
    my $base = $pars{base};
    $menu_config->signal_connect( activate => sub { `${base}/configurador.pl` }
    );
    $self->add($menu_config);

    my $menu_quit = Gtk2::MenuItem->new_with_label("sair");
    $menu_quit->signal_connect( activate => sub { exit } );
    $self->add($menu_quit);
    $self
}

42
