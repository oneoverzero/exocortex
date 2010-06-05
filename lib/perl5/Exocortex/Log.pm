package Exocortex::Log;

use Moose::Role;

has 'DEBUG' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

sub set_debug {
    my $self  = shift;
    my $debug = shift;

    $self->log( 0, __PACKAGE__ . ": Setting debug to $debug" );
    $self->DEBUG($debug);
}

sub log {
    my ( $self, $level, $string ) = @_;

    if ( $level <= $self->DEBUG ) {
        print STDERR "$string\n";
    }
}

no Moose::Role;

42;
