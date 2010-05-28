package Exocortex::Messaging;

use common::sense;

sub new {
    my $class = shift;
    my %params = @_;

    # Check mandatory parameters

    my $messaging_service = $params{messaging_service};
    die __PACKAGE__ . ": Missing required param: messaging_service\n"
          unless $messaging_service;

    if ($messaging_service eq 'RabbitMQ') {
	use Exocortex::Messaging::RabbitMQ;
	my $messaging = Exocortex::Messaging::RabbitMQ->new(@_);
	return $messaging;
    }
    else {
        die __PACKAGE__.": I don't know how to instantiate a messaging component for the \"$messaging_service\" service\n";
    }
}

42;
