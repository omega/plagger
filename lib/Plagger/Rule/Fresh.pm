package Plagger::Rule::Fresh;
use strict;
use base qw( Plagger::Rule );

sub init {
    my $self = shift;

    if (my $config = $self->{mtime}) {
        my $path = $config->{path};

        # If autoupdate is set, automatically touch the file
        my $now   = time;
        my $mtime = (stat($path))[9];

        if ($config->{autoupdate}) {
            if ($mtime) {
                utime $now, $now, $path or Plagger->context->error("$path: $!");
            } else {
                open my $fh, ">", $path or Plagger->context->error("$path: $!");
            }
        } else {
            $mtime or Plagger->context->error("$path: $!")
        }
        $self->{timestamp} = $mtime || 0;
    } else {
        eval {
            $self->{duration}   = $self->init_duration();
            $self->{timestamp}  = time - $self->{duration};
        };
        if ($@) {
            Plagger->context->error("Parse duration error: $@");
        }
    }

    $self->{compare_dt} = Plagger::Date->from_epoch(epoch => $self->{timestamp});
}

sub init_duration {
    my $self = shift;

    my $duration = $self->{duration} || 120; # minutes

    if ($duration =~ /^\d+$/) {
        # if it's all digit, the unit is minutes
        return $duration * 60;
    }

    eval { require Time::Duration::Parse };
    if ($@) {
        Plagger->context->error("You need to install Time::Duration::Parse to use human readable timespec");
    }

    Time::Duration::Parse::parse_duration($self->{duration});
}

sub id {
    my $self = shift;
    return "fresh:$self->{duration}sec";
}

sub as_title {
    my $self = shift;

    my $duration = $self->{duration}
        ? "within " . $self->duration_friendly
        : "since "  . $self->{compare_dt}->strftime('%Y/%m/%d %H:%M');

    return "updated " . $duration;
}

sub duration_friendly {
    my $self = shift;
    eval { require Time::Duration };
    return $@ ? "$self->{duration} seconds"
              : Time::Duration::duration($self->{duration});
}

sub dispatch {
    my($self, $args) = @_;

    my $date;
    if ($args->{entry}) {
        $date = $args->{entry}->date;
    } elsif ($args->{feed}) {
        $date = $args->{feed}->updated;
    } else {
        Plagger->context->error("No entry nor feed object in this plugin phase");
    }

    # no date field ... should be Fresh, ugh.
    $date ? $date >= $self->{compare_dt} : 1;
}

1;

__END__

=head1 NAME

Plagger::Rule::Fresh - Rule to find 'fresh' entries or feeds

=head1 SYNOPSIS

  # entries updated within 120 minutes
  - module: SmartFeed
    config:
      id: fresh-entries
    rule:
      module: Fresh
      duration: 120

  # remove entries older than mtime of /tmp/foo.tmp
  - module: Filter::Rule
    rule:
      module: Fresh
      mtime:
        path: /tmp/foo.tmp
        autoupdate: 1

=head1 DESCRIPTION

This rule finds fresh entries or feeds, which means updated date is
within C<duration> minutes. It defaults to 2 hours, but you'd better
configure the value with your cronjob interval.

=head1 CONFIG

=over 4

=item C<duration>

  duration: 5

This rule matches with entries posted within 5 minutes. When you
invoke C<plagger> script in cronjob, you'd better specify the
same C<duration> variable with the job interval.

If the supplied value contains only digit, it's parsed as minutes. You
can write in a human readable format like:

  duration: 4 hours

and this module DWIMs. It defaults to I<120>, which means 2 hours.

=item C<mtime>

  mtime:
    path: /path/to/mtime.file
    autoupdate: 1

This rule matches with entries newer than mtime of
C</path/to/mtime.file>. If C<autoupdate> option is set (default is
off), this plugin automatically creates and updates the file in plugin
registration phase.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa

Thanks to youpy, who originally wrote Plagger::Plugin::Filter::Fresh
at L<http://subtech.g.hatena.ne.jp/youpy/20060224/p1>

=head1 SEE ALSO

L<Plagger>, L<Time::Duration>

=cut
