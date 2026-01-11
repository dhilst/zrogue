package Utils;
use v5.36;

use Exporter qw(import);

our @EXPORT_OK = qw(
    aref
    getters
);

sub aref { \@_ };

sub getters(@fields) {
    no strict 'refs';
    my $pkg = caller;
    for my $field (@fields) {
        *{"${pkg}::$field"} = sub {
            shift->{$field};
        }
    }
}

1;
