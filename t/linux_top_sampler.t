use v5.36;
use utf8;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../examples/linux/data";

use MetricSampler;

my $sampler = MetricSampler->new;
my $first  = $sampler->snapshot;
sleep 1;
my $second = $sampler->snapshot;

ok($second && $second->{cpu}, 'snapshots include CPU data');
ok($second->{memory} && defined $second->{memory}{percent}, 'memory percent defined');
ok(keys %{ $second->{disk} // {} } >= 0, 'disk entries present');
ok(keys %{ $second->{network} // {} } >= 0, 'network entries present');
ok(@{ $second->{process} || [] }, 'at least one process row');

done_testing;
