package Exocortex::Log;

use common::sense;

use base 'Mojo::Base';

__PACKAGE__->attr( 'DEBUG' => 0 );

sub log {
    my ( $self, $level, $string ) = @_;

    if ( $level <= $self->DEBUG ) {
        print STDERR "$string\n";
    }
}

42;
