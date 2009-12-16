package Exocortex::Stats;

use common::sense;

use base 'Mojo::Base';
use base 'Exocortex::Log';

use Data::Dumper;

__PACKAGE__->attr( 'DEBUG' => 0 );
__PACKAGE__->attr('up_since');
__PACKAGE__->attr('stats_data');
__PACKAGE__->attr('stats_report_interval');
__PACKAGE__->attr('stats_report_timer');
__PACKAGE__->attr('stats_report_callback');
__PACKAGE__->attr('do_stats_regular_report');

sub stats_setup {
    my $self = shift;

    # Checking required params
    die __PACKAGE__
      . ": Missing required param: stats_report_interval (use 0 for no automated report)\n"
      unless defined $self->stats_report_interval;
    if ( $self->stats_report_callback
        && ( ref( $self->stats_report_callback ) ne 'CODE' ) )
    {
        die __PACKAGE__
          . ": Optional parameter 'stats_report_callback' must be a code ref\n";
    }
    if ( $self->stats_report_interval && ( $self->stats_report_interval > 0 ) )
    {
        $self->do_stats_regular_report(1);
    }
    else {
        $self->do_stats_regular_report(0);
    }

    $self->log( 1,
            __PACKAGE__
          . ": Starting with debug level = \""
          . $self->DEBUG
          . "\"" );
    $self->log( 2,
            __PACKAGE__
          . ": Settings: stats_report_interval: \""
          . $self->stats_report_interval . "\"; "
          . "do_stats_regular_report: \""
          . $self->do_stats_regular_report
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
    return unless $self->do_stats_regular_report;

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

42;
