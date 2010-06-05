package Exocortex::Collector::Twitter;

use Moose;
with 'Exocortex::Collector';

use AnyEvent::Twitter;

has 'bot'             => ( is => 'rw' );
has 'username'        => ( is => 'rw', isa => 'Str', required => 1 );
has 'password'        => ( is => 'rw', isa => 'Str', required => 1 );
has 'status_type'     => ( is => 'rw', isa => 'Str', required => 1 );
has 'on_msg_received' => ( is => 'ro', isa => 'CodeRef', required => 1 );

sub BUILD {
    my $self = shift;

    $self->stats_init;

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

                $self->log( 0,
                    __PACKAGE__ . " (" . $self->id . "): Error: $error" );
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
                        type       => 'tweet',
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

                $self->log( 0,
                    __PACKAGE__ . " (" . $self->id . "): Error: $error" );
                $self->stats_data->{errors}{to_print}{total}++;
                $self->stats_data->{errors}{$error}++;
            },
            statuses_friends => sub {
                my ( $twitter_bot, @statuses ) = @_;

                while ( my $s = pop @statuses ) {
                    my ( $pp_status, $raw_status ) = @$s;
                    $self->stats_data->{tweets}{to_print}{received}++;
                    my $tweet_date = $pp_status->{timestamp};

                    #TODO: Make it configurable!
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

    $self->bot->start;
    $self->log( 3, __PACKAGE__ . " (" . $self->id . "): Got created" );
}

__PACKAGE__->meta->make_immutable;
no Moose;

42;
