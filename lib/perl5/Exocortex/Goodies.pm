package Exocortex::Goodies;

use common::sense;
use Moose::Role;

sub _uptime {
    my $self = shift;

    my $up_since = shift;

    my $delta  = time - $self->stats_up_since;
    my $years  = int( $delta / ( 60 * 60 * 24 * 365 ) );
    my $remain = $delta % ( 60 * 60 * 24 * 365 );
    my $months = int( $remain / ( 60 * 60 * 24 * 30 ) );
    $remain = $remain % ( 60 * 60 * 24 * 30 );
    my $days = int( $remain / ( 60 * 60 * 24 ) );
    $remain = $remain % ( 60 * 60 * 24 );
    my $hours = int( $remain / ( 60 * 60 ) );
    $remain = $remain % ( 60 * 60 );
    my $mins = int( $remain / 60 );
    $remain = $remain % 60;
    my $secs = $remain;

    # Adjust the output to something actually useful
    if ($years) {
        return
          sprintf( "%i years, %i months, %i days", $years, $months, $days );
    }
    elsif ($months) {
        return sprintf( "%i months, %i days", $months, $days );
    }
    elsif ($days) {
        return sprintf( "%i days, %i hours", $days, $hours );
    }
    elsif ($hours) {
        return sprintf( "%i hours, %i minutes", $hours, $mins );
    }
    else {
        return sprintf( "%i minutes, %i seconds", $mins, $secs );
    }
}

no Moose::Role;
42;
