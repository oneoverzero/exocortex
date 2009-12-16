package Exocortex::Comms::CLI;

use common::sense;

use base 'Mojo::Base';
use base 'Exocortex::Log';
use base 'Exocortex::Stats';

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

__PACKAGE__->attr('DEBUG');
__PACKAGE__->attr('server');
__PACKAGE__->attr('host');
__PACKAGE__->attr('port');
__PACKAGE__->attr('instance');
__PACKAGE__->attr('on_msg_received');
__PACKAGE__->attr( 'connections' => 0 );

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless $self, $class;

    # Check required params
    die __PACKAGE__ . ": Missing required param: host\n"
      unless $self->host;
    die __PACKAGE__ . ": Missing required param: port\n"
      unless $self->port;
    die __PACKAGE__ . ": Missing required param: instance\n"
      unless $self->instance;
    die __PACKAGE__ . ": Missing required param: on_msg_received\n"
      unless ( $self->on_msg_received
        && ( ref( $self->on_msg_received ) eq 'CODE' ) );

    return $self;
}

sub start {
    my $self = shift;

    $self->log( 1, __PACKAGE__ . ": Starting up\n" );
    $self->log( 1,
        __PACKAGE__ . ": Settings: " . "port: \"" . $self->port . "\"\n" );

    # Initialize stuff
    $self->stats_setup;

    my $server = tcp_server $self->host, $self->port, sub {
        my ( $fh, $host, $port ) = @_;

        die __PACKAGE__ . ": Unable to connect: $!" unless $fh;
        $self->log( 1,
            __PACKAGE__ . ": Got a new client connection from $host:$port" );
        $self->connections( $self->connections + 1 );
        $self->stats_data->{connections}{to_print}{total}++;

        my $handle;    # avoid direct assignment so on_eof has it in scope.
        $handle = new AnyEvent::Handle
          fh       => $fh,
          on_error => sub {
            $self->log( 1,
                __PACKAGE__
                  . ": Lost client connection to $host:$port ($_[2])" );
            $_[0]->destroy;
            $self->connections( $self->connections - 1 );
          },
          on_eof => sub {
            $handle->destroy;    # destroy handle
            $self->connections( $self->connections - 1 );
            $self->log( 1, __PACKAGE__ . ": done." );
          };

        $handle->push_read(
            line => sub {
                $self->_setup_read_handle(@_);
            }
        );
    };

    $self->server($server);
}

sub connected {
    my $self = shift;

    return $self->connections > 0;
}

sub _setup_read_handle {
    my $self = shift;
    my ( $handle, $line ) = @_;

    $self->_deal_with_request(@_);

    $handle->push_read(
        line => sub {
            $self->_setup_read_handle(@_);
        }
    );
    return;
}

sub _deal_with_request {
    my ( $self, $handle, $request ) = @_;

    $self->log( 1, __PACKAGE__ . ": got request: \"$request\"" );
    $self->stats_data->{commands}{to_print}{received}++;
    my $reply = $self->on_msg_received->( $request );
    $handle->push_write("$reply\n");
}

sub set_debug {
    my $self = shift;
    my $debug = shift;

    $self->DEBUG($debug);
}

42;
