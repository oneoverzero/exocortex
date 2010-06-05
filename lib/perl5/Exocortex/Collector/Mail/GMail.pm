package Exocortex::Collector::Mail::GMail;

use Moose;
with 'Exocortex::Collector';

use AnyEvent::Gmail::Feed;

has 'bot'             => ( is => 'rw' );
has 'username'        => ( is => 'rw', isa => 'Str', required => 1 );
has 'password'        => ( is => 'rw', isa => 'Str', required => 1 );
has 'on_msg_received' => ( is => 'ro', isa => 'CodeRef', required => 1 );

sub BUILD {
    my $self = shift;

    $self->stats_init;

    $self->bot(
        AnyEvent::Gmail::Feed->new(
            DEBUG        => $self->DEBUG,
            username     => $self->username,
            password     => $self->password,
            on_new_entry => sub {
                my $message = shift;

                $self->stats_data->{gmail}{to_print}{received}++;
                $self->on_msg_received->(
                    message    => $message->title,
                    type       => 'gmail',
                    date       => $message->issued,
                    extra_data => $message,
                  ),
                  ;
            }
        )
    );

    $self->log( 3, __PACKAGE__ . " (" . $self->id . "): Got created" );

}

__PACKAGE__->meta->make_immutable;
no Moose;

42;
