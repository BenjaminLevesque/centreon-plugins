#
# Copyright 2020 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package apps::dynatrace::restapi::mode::problem;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use List::MoreUtils qw(uniq);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_status_output { 
    my ($self, %options) = @_;

    my $msg = '';
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{status} = $options{new_datas}->{$self->{instance} . '_status'};
    $self->{result_values}->{impactLevel} = $options{new_datas}->{$self->{instance} . '_impactLevel'};
    $self->{result_values}->{severityLevel} = $options{new_datas}->{$self->{instance} . '_severityLevel'};
    $self->{result_values}->{entityName} = $options{new_datas}->{$self->{instance} . '_entityName'};
    $self->{result_values}->{eventType} = $options{new_datas}->{$self->{instance} . '_eventType'};
    $self->{result_values}->{entityId} = $options{new_datas}->{$self->{instance} . '_entityId'};
    $self->{result_values}->{startTime} = $options{new_datas}->{$self->{instance} . '_startTime'};
    $self->{result_values}->{endTime} = $options{new_datas}->{$self->{instance} . '_endTime'};
    $self->{result_values}->{commentCount} = $options{new_datas}->{$self->{instance} . '_commentCount'};
    return 0;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'problem', type => 1, cb_prefix_output => 'prefix_service_output', message_multiple => 'No problem' }
    ];

    $self->{maps_counters}->{problem} = [
        { label => 'status', threshold => 0, set => {
                key_values => [ { name => 'status' }, { name => 'impactLevel' }, { name => 'severityLevel' }, { name => 'entityName' }, { name => 'eventType' }, { name => 'entityId' }, { name => 'startTime' }, { name => 'endTime' }, { name => 'commentCount' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}

sub prefix_service_output {
    my ($self, %options) = @_;

    return "Problem '" . $options{instance_value}->{displayName} ."'";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $self->{version} = '1.0';
    $options{options}->add_options(arguments => {
        "relative-time:s"  => { name => 'relative_time', default => 'min' },
        "unknown-status:s"  => { name => 'unknown_status', default => '' },
        "warning-status:s"  => { name => 'warning_status', default => '' },
        "critical-status:s" => { name => 'critical_status', default => '%{status} eq "OPEN"' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => [
        'warning_status', 'critical_status', 'unknown_status',
    ]);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $problem = $options{custom}->api_problem(relative_time => $options{options}->{relative_time});
    $self->{problem} = {};
    foreach my $item (@{$problem}) {
        $self->{problem}->{$item->{displayName}} = {
            displayName => $item->{displayName},
            status => $item->{status},
            impactLevel => $item->{impactLevel},
            severityLevel => $item->{severityLevel},
            entityName => join(",", uniq map { "$_->{entityName}" } @{$item->{rankedImpacts}}),
            eventType => join(",", uniq map { "$_->{eventType}" } @{$item->{rankedImpacts}}),
            entityId => join(",", uniq map { "$_->{entityId}" } @{$item->{rankedImpacts}}),
            startTime => $item->{startTime} / 1000,
            endTime => $item->{endTime} > -1 ? $item->{endTime} / 1000 : -1,
            commentCount => $item->{commentCount},
        };
    }
}

1;

__END__

=head1 MODE

Check problem

=over 8

=item B<--relative-time>

Set request relative time (Default: 'min').
Can use: min, 5mins, 10mins, 15mins, 30mins, hour, 2hours, 6hours, day, 3days, week, month.


=item B<--unknown-status>

Set unknown threshold for status.
Can use special variables like: %{status}, %{impactLevel}, %{severityLevel}, %{entityName}, %{eventType}, %{entityId}, %{startTime}, %{endTime}, %{commentCount}

=item B<--warning-status>

Set warning threshold for status.
Can use special variables like: %{status}, %{impactLevel}, %{severityLevel}, %{entityName}, %{eventType}, %{entityId}, %{startTime}, %{endTime}, %{commentCount}

=item B<--critical-status>

Set critical threshold for status (Default: '%{status} eq "OPEN"').
Can use special variables like: %{status}, %{impactLevel}, %{severityLevel}, %{entityName}, %{eventType}, %{entityId}, %{startTime}, %{endTime}, %{commentCount}

=back

=cut
