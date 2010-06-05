package Exocortex::Comms::CLI;

use common::sense;
use Moose;

with 'Exocortex::Log', 'Exocortex::Stats';

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

has 'server'          => ( is => 'rw' );
has 'host'            => ( is => 'ro', isa => 'Str', required => 1 );
has 'port'            => ( is => 'ro', isa => 'Str', required => 1 );
has 'instance'        => ( is => 'ro', isa => 'Str', required => 1 );
has 'on_msg_received' => ( is => 'ro', isa => 'CodeRef', required => 1 );
has 'connections'     => ( is => 'rw', isa => 'Int', default => 0 );

sub BUILD {
    my $self = shift;

    $self->log( 1, __PACKAGE__ . ": Starting up\n" );
    $self->log( 1,
        __PACKAGE__ . ": Settings: " . "port: \"" . $self->port . "\"\n" );

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

    $self->stats_init;
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
    my $reply = $self->on_msg_received->($request);
    $handle->push_write("$reply\n");
}

sub set_debug {
    my $self  = shift;
    my $debug = shift;

    $self->DEBUG($debug);
}

__PACKAGE__->meta->make_immutable;
no Moose;

42;
