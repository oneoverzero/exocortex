package Exocortex::Stats;

use Moose::Role;
with 'Exocortex::Log';

use Data::Dumper;

has 'stats_up_since' => (
    is            => 'rw',
    isa           => 'Int',
    documentation => 'Number of seconds this service has been up for',
);

has 'stats_data' => (
    is  => 'rw',
    isa => 'HashRef',
);

has 'stats_report_interval' => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
    documentation =>
'Number of seconds between each dump of the current stats. Set to 0 for no automatic recurrent stats dump.',
);

has 'stats_report_callback' => (
    is            => 'rw',
    Isa           => 'CodeRef',
    documentation => 'Code to call when we need to report the stats',
);

has 'stats_report_timer' => ( is => 'rw', );

has 'stats_do_regular_report' => ( is => 'rw', isa => 'Bool' );

sub stats_init {
    my $self = shift;

    # Checking required params
    if ( $self->stats_report_interval > 0 ) {
        $self->stats_do_regular_report(1);
    }
    else {
        $self->stats_do_regular_report(0);
    }

    $self->log( 2,
            __PACKAGE__
          . ": Settings: stats_report_interval: \""
          . $self->stats_report_interval . "\"; "
          . "stats_do_regular_report: \""
          . $self->stats_do_regular_report
          . "\"" );

    $self->stats_data( {} );
    $self->_reset_stats_report_timer;
}

sub stats_to_string {
    my $self = shift;

    my $stats = $self->stats_data;

    my $str;
    foreach my $topic ( keys(%$stats) ) {
        if ( exists( $stats->{$topic}{to_print} ) ) {
            foreach my $subtopic ( keys( %{ $stats->{$topic}{to_print} } ) ) {
                $str .= "$topic/$subtopic: "
                  . $stats->{$topic}{to_print}{$subtopic} . "; ";
            }
        }
    }
    return $str;
}

sub stats_dump_to_log {
    my $self = shift;

    $self->log( 0, Dumper( $self->stats_data ) );
}

sub _reset_stats_report_timer {
    my $self = shift;

    $self->log( 2, __PACKAGE__ . ": Reseting the stats report timer" );
    return unless $self->stats_do_regular_report;

    $self->stats_report_timer(
        AnyEvent->timer(
            after => $self->stats_report_interval,
            cb    => sub {
                $self->stats_report_callback->();
                $self->_reset_stats_report_timer;
            }
        )
    );
}

no Moose::Role;

42;
