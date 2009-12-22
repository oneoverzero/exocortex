package Exocortex::Collector::Twitter;

use common::sense;

use base 'Mojo::Base';
use base 'Exocortex::Collector';

use AnyEvent::Twitter;

# Local stuff
__PACKAGE__->attr('bot');
__PACKAGE__->attr('username');
__PACKAGE__->attr('password');
__PACKAGE__->attr('status_type');
__PACKAGE__->attr('on_msg_received');

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless $self, $class;

    # Check mandatory parameters

    die __PACKAGE__ . ": Missing required param: username\n"
      unless $self->username;
    die __PACKAGE__ . ": Missing required param: password\n"
      unless $self->password;
    die __PACKAGE__ . ": Missing required param: status_type\n"
      unless $self->status_type;
    die __PACKAGE__ . ": Missing required param: on_msg_received\n"
      unless ( $self->on_msg_received
        && ( ref( $self->on_msg_received ) eq 'CODE' ) );

    $self->bot(
        AnyEvent::Twitter->new(
            DEBUG    => $self->DEBUG,
            username => $self->username,
            password => $self->password,
        )
    );

    if ( $self->status_type eq 'mentions' ) {
        $self->bot->reg_cb(
            error => sub {
                my ( $twitter_bot, $error ) = @_;

                $self->log( 0, __PACKAGE__ . ": Error: $error" );
                $self->stats_data->{errors}{to_print}{total}++;
                $self->stats_data->{errors}{$error}++;
            },
            statuses_mentions => sub {
                my ( $twitter_bot, @statuses ) = @_;

                while ( my $s = pop @statuses ) {
                    my ( $pp_status, $raw_status ) = @$s;
                    $self->stats_data->{tweets}{to_print}{received}++;
                    my $tweet_date = $pp_status->{timestamp};

                    #TODO: Make it configurable?
                    if ( time - $tweet_date > 6 * 3600 ) {
                        $self->stats_data->{tweets}{to_print}{ignored}++;
                        next;
                    }
                    $self->on_msg_received->(
                        message    => $pp_status->{text},
                        date       => $tweet_date,
                        type       => 'twitter',
                        extra_data => $raw_status
                    );
                }
            },
        );
        $self->bot->receive_statuses_mentions(0);
    }
    elsif ( $self->status_type eq 'friends' ) {
        $self->bot->reg_cb(
            error => sub {
                my ( $twitter_bot, $error ) = @_;

                $self->log( 0, __PACKAGE__ . ": Error: $error" );
                $self->stats_data->{errors}{to_print}{total}++;
                $self->stats_data->{errors}{$error}++;
            },
            statuses_friends => sub {
                my ( $twitter_bot, @statuses ) = @_;

                while ( my $s = pop @statuses ) {
                    my ( $pp_status, $raw_status ) = @$s;
                    $self->stats_data->{tweets}{to_print}{received}++;
                    my $tweet_date = $pp_status->{timestamp};

                    #TODO: Make it configurable?
                    if ( time - $tweet_date > 6 * 3600 ) {
                        $self->stats_data->{tweets}{to_print}{ignored}++;
                        next;
                    }
                    $self->on_msg_received->(
                        message    => $pp_status->{text},
                        date       => $tweet_date,
                        type       => 'twitter',
                        extra_data => $raw_status
                    );
                }
            },
        );
        $self->bot->receive_statuses_friends(0);
    }

    return $self;
}

sub start {
    my $self = shift;

    $self->stats_setup;
    $self->bot->start;
}

42;
