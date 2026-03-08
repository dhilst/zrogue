use v5.36;
use utf8;
use Test::More;
use Test::Exception;

use lib '.';
use BorderMapper;

subtest 'constructor validation' => sub {
    dies_ok { BorderMapper::from_callback() } 'missing callback dies';
    dies_ok { BorderMapper::from_callback({}) } 'non-coderef callback dies';
};

subtest 'string style normalizes to 3x3 chars' => sub {
    my $mapper = BorderMapper::from_callback(sub ($material) {
        return "+-+\n| |\n+-+" if $material eq 'ASCII';
        return undef;
    });

    is_deeply(
        $mapper->style('ASCII'),
        [
            ['+', '-', '+'],
            ['|', ' ', '|'],
            ['+', '-', '+'],
        ],
        'style parsed from multiline string'
    );
};

subtest 'array style normalizes to 3x3 chars' => sub {
    my $mapper = BorderMapper::from_callback(sub ($material) {
        return ['┌─┐', '│ │', '└─┘'];
    });

    is_deeply(
        $mapper->style('SINGLE'),
        [
            ['┌', '─', '┐'],
            ['│', ' ', '│'],
            ['└', '─', '┘'],
        ],
        'style parsed from array rows'
    );
};

subtest 'invalid styles are rejected' => sub {
    my $bad_rows = BorderMapper::from_callback(sub ($material) {
        return "+-+\n| |";
    });
    dies_ok { $bad_rows->style('X') } 'less than 3 rows dies';

    my $bad_cols = BorderMapper::from_callback(sub ($material) {
        return ['+-+', '||', '+-+'];
    });
    dies_ok { $bad_cols->style('X') } 'row without 3 chars dies';

    my $bad_ref = BorderMapper::from_callback(sub ($material) {
        return {};
    });
    dies_ok { $bad_ref->style('X') } 'invalid type dies';
};

done_testing;
