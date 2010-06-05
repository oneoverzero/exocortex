package Exocortex::Messaging::RabbitMQ;

use Moose;

with 'Exocortex::Messaging';

use Net::RabbitMQ;

sub BUILD {
    my $self = shift;

    $self->stats_init;
    $self->log( 3, __PACKAGE__ . ": Starting up" );
}

sub send_message {
    my $self    = shift;
    my $message = shift;

    $self->stats_data->{messages}{to_print}{sent}++;
    $self->log( 1,
        __PACKAGE__
          . ": I'd send the message \"$message\" via the RabbitMQ cloud if I knew how to"
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
42;
