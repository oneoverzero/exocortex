package Exocortex::Collector;

use base 'Mojo::Base';
use base 'Exocortex::Log';
use base 'Exocortex::Stats';

use common::sense;

# Local stuff
__PACKAGE__->attr( 'DEBUG' => 0 );

sub start {
    die "You must overide the 'start' method in your collector";
}

sub set_debug {
    my $self = shift;
    my $debug = shift;

    $self->DEBUG($debug);
}

42;
