package Exocortex::Collector::Server;

use common::sense;

use base 'Mojo::Base';
use base 'Exocortex::Log';
use base 'Exocortex::Goodies';
use base 'Exocortex::Stats';

use Exocortex::Comms::CLI;
use Exocortex::Messaging;

use AnyEvent;
use Data::Dumper;

# Local stuff
__PACKAGE__->attr( 'DEBUG' => 0 );
__PACKAGE__->attr('main_loop');
__PACKAGE__->attr('stats_report_interval');
__PACKAGE__->attr('instance');
__PACKAGE__->attr('signal_watchers');

# Command Line Interface stuff
__PACKAGE__->attr('cli_port');
__PACKAGE__->attr('cli_host');
__PACKAGE__->attr('cli_bot');

# Collectors
__PACKAGE__->attr('collectors');

# Messaging
__PACKAGE__->attr('messaging');
__PACKAGE__->attr('messaging_service');

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless $self, $class;

    # Check mandatory parameters
    die __PACKAGE__ . ": Missing required param: instance\n"
      unless $self->instance;
    die __PACKAGE__ . ": Missing required param: cli_port\n"
      unless $self->cli_port;
    die __PACKAGE__ . ": Missing required param: stats_report_interval\n"
      unless $self->stats_report_interval;
    die __PACKAGE__ . ": Missing required param: messaging_service\n"
      unless $self->messaging_service;

    $self->cli_bot(
        Exocortex::Comms::CLI->new(
            DEBUG                 => $self->DEBUG,
            stats_report_interval => 0,
            host                  => $self->cli_host,
            port                  => $self->cli_port,
            instance              => $self->instance,
            on_msg_received       => sub {
                $self->deal_with_command(@_);
            },
        ),
    );

    $self->messaging(
        Exocortex::Messaging->new(
	    DEBUG => $self->DEBUG,
            stats_report_interval => 0,
            messaging_service => $self->messaging_service,
	    component_id => 'Exocortex::Collector::Server',
	),
    );

    $self->signal_watchers(
        (
            AnyEvent->signal(
                signal => "INT",
                cb     => sub { $self->main_loop->broadcast; }
            ),
            AnyEvent->signal(
                signal => "KILL",
                cb     => sub { $self->main_loop->broadcast; }
            ),
            AnyEvent->signal(
                signal => "TERM",
                cb     => sub { $self->main_loop->broadcast; }
            ),
        ),
    );

    foreach my $col ( @{ $self->collectors } ) {
        if ( $col->{type} eq 'twitter' ) {
            $self->log( 2,
                    __PACKAGE__
                  . ": Creating a Twitter collector of type "
                  . $col->{status_type}
                  . " for user "
                  . $col->{username}
                  . " with ID \""
                  . $col->{id}
                  . "\"" );
            use Exocortex::Collector::Twitter;
            $col->{bot} = Exocortex::Collector::Twitter->new(
                DEBUG                 => $self->DEBUG,
                id                    => $col->{id},
                username              => $col->{username},
                password              => $col->{password},
                status_type           => $col->{status_type},
                stats_report_interval => 0,
                on_msg_received       => sub {
                    $self->deal_with_message(@_);
                }
            );
        }
        elsif ( $col->{type} eq 'gmail' ) {
            $self->log( 2,
                    __PACKAGE__
                  . ": Creating a Gmail collector for user "
                  . $col->{username}
                  . " with ID \""
                  . $col->{id}
                  . "\"" );
            use Exocortex::Collector::Mail::Gmail;
            $col->{bot} = Exocortex::Collector::Mail::Gmail->new(
                DEBUG                 => $self->DEBUG,
                id                    => $col->{id},
                username              => $col->{username},
                password              => $col->{password},
                stats_report_interval => 0,
                on_msg_received       => sub {
                    $self->deal_with_message(@_);
                }
            );
        }
        else {
            $self->log( 2,
                    __PACKAGE__
                  . ": Sorry, I don't know how to deal with a collector of type "
                  . $col->{type} );
        }
    }

    return $self;
}

sub start {
    my $self = shift;

    $self->log( 1, __PACKAGE__ . ": Starting run" );
    $self->log( 3, __PACKAGE__ . ": Parameters:\n" . Dumper($self) );
    if ( $self->DEBUG > 1 ) {
        AnyEvent::post_detect {
            $self->log( 1,
                __PACKAGE__ . ": Event model is \"$AnyEvent::MODEL\"" );
        }
    }

    # Setup recurrent stats reporting
    if ( $self->stats_report_interval && ( $self->stats_report_interval > 0 ) )
    {
        $self->stats_report_callback(
            sub {
                $self->dump_all_stats_to_log;
            }
        );
    }

    # Setup and initialize other bits and pieces
    $self->up_since(time);
    $self->stats_setup;
    my $loop = AnyEvent->condvar;
    $self->main_loop($loop);
    $self->cli_bot->start;
    $self->messaging->start;
    foreach my $col ( @{ $self->collectors } ) {
        if ( $col->{bot} ) {
            $self->log( 2,
                    __PACKAGE__
                  . ": Starting up a "
                  . $col->{type}
                  . " collector" );
            $col->{bot}->start;
        }
        else {
            $self->log( 2,
                    __PACKAGE__
                  . ": Ignoring un-initialized "
                  . $col->{type}
                  . " collector" );
        }
    }
    $self->main_loop->wait;

    $self->dump_all_stats_to_log;
    $self->log( 0, __PACKAGE__ . ": Taking my leave now, have a nice day!" );
}

sub deal_with_command {
    my $self = shift;

    my $command = shift;

    $self->log( 2, __PACKAGE__ . ": Got command \"$command\"" );
    $self->stats_data->{commands}{to_print}{total}++;

    if ( $command eq 'die' ) {
        $self->main_loop->broadcast;
        return ("Bailing out, good-bye");
    }
    elsif ( $command =~ /^echo (.+)$/ ) {
        $self->stats_data->{commands}{echo}++;
        return "Echoing $1";
    }
    elsif ( $command eq 'stats' ) {
        $self->stats_data->{commands}{stats}++;
        return $self->all_stats_to_string;
    }
    elsif ( $command eq 'dump stats' ) {
        $self->stats_data->{commands}{'dump stats'}++;
        $self->dump_all_stats_to_log;
        return "Stats dumped to the logfile:\n" . $self->all_stats_to_string;
    }
    elsif ( $command =~ /^debug (\d+)$/ ) {
        $self->stats_data->{commands}{debug}++;
        $self->set_debug($1);
        return "Debug level set to $1";
    }
    else {
        $self->stats_data->{commands}{unknown}++;
        return
"The commands I know about are: 'stats', 'dump stats', 'debug <num>', 'echo <stuff>', 'die'";
    }
}

sub deal_with_message {
    my $self = shift;

    my %args = @_;

    $self->stats_data->{messages}{to_print}{total}++;

    $self->log( 1,
        __PACKAGE__ . ": Got a new message of type \"" . $args{type} . "\"" );
    $self->log( 3,
            __PACKAGE__
          . ": Parameters received for the message: "
          . Dumper \%args );
    # TODO: Actually do something with the freaking message!
    $self->messaging->send_message('Type: '.$args{type});
}

sub all_stats_to_string {
    my $self = shift;

    my $stats = "Server uptime: " . $self->_uptime( $self->up_since ) . "\n";
    my $server_stats = $self->stats_to_string;
    if ($server_stats) {
        $stats .= "server $server_stats\n";
    }
    my $cli_stats = $self->cli_bot->stats_to_string;
    if ($cli_stats) {
        $stats .= "cli: $cli_stats\n";
    }
    my $messaging_stats = $self->messaging->stats_to_string;
    if ($messaging_stats) {
        $stats .= "messaging: $messaging_stats\n";
    }
    foreach my $col ( @{ $self->collectors } ) {
        if ( $col->{bot} ) {
            my $col_stats = $col->{bot}->stats_to_string;
            if ($col_stats) {
                $stats .= $col->{type} . ": $col_stats\n";
            }
        }
    }

    return $stats;
}

sub dump_all_stats_to_log {
    my $self = shift;

    $self->log( 0, __PACKAGE__ . ": Uptime: " . $self->_uptime );
    $self->log( 0, __PACKAGE__ . ": Server stats:" );
    $self->stats_dump_to_log;
    $self->log( 0, __PACKAGE__ . ": cli bot stats:" );
    $self->cli_bot->stats_dump_to_log;
    $self->log( 0, __PACKAGE__ . ": messaging stats:" );
    $self->messaging->stats_dump_to_log;
    foreach my $col ( @{ $self->collectors } ) {
        if ( $col->{bot} ) {
            $self->log( 0,
                __PACKAGE__ . ": " . $col->{type} . " collector stats:" );
            my $col_stats = $col->{bot}->stats_dump_to_log;
        }
    }
}

sub set_debug {
    my $self  = shift;
    my $debug = shift;

    $self->log( 0, __PACKAGE__ . ": Setting global debug mode to $debug" );
    $self->DEBUG($debug);
    $self->cli_bot->set_debug($debug);

    foreach my $col ( @{ $self->collectors } ) {
        if ( $col->{bot} ) {
            $col->{bot}->set_debug($debug);
        }
    }
}

42;

