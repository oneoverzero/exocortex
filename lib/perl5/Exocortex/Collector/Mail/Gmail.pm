package Exocortex::Collector::Mail::Gmail;

use common::sense;

use base 'Mojo::Base';
use base 'Exocortex::Collector';

use AnyEvent::Gmail::Feed;

# Local stuff
__PACKAGE__->attr('bot');
__PACKAGE__->attr('id');
__PACKAGE__->attr('username');
__PACKAGE__->attr('password');
__PACKAGE__->attr('on_msg_received');

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless $self, $class;

    # Check mandatory parameters

    die __PACKAGE__ . ": Missing required param: username\n"
      unless $self->username;
    die __PACKAGE__ . ": Missing required param: id\n"
      unless $self->id;
    die __PACKAGE__ . ": Missing required param: password\n"
      unless $self->password;
    die __PACKAGE__ . ": Missing required param: on_msg_received\n"
      unless ( $self->on_msg_received
        && ( ref( $self->on_msg_received ) eq 'CODE' ) );

    $self->stats_setup;

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

    return $self;
}

sub start {
    my $self = shift;

    # This bot auto-starts when it is created
    $self->log( 3,
            __PACKAGE__ . " ("
          . $self->id
          . "): Got the start-up command, but I was already up and running" );

    return;
}

42;
