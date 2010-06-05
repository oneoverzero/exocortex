package Exocortex::Messaging;

use Moose::Role;

with 'Exocortex::Log', 'Exocortex::Stats';

requires 'send_message';

has 'component_id' => (
    is       => 'ro',
    required => 1,
);

no Moose::Role;

42;
