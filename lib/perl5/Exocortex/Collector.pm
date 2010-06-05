package Exocortex::Collector;

use Moose::Role;
with 'Exocortex::Log', 'Exocortex::Stats';

has 'id' => ( is => 'rw', isa => 'Str', required => 1 );

no Moose::Role;

42;
