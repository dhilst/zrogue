package Utils;
use v5.36;

use Exporter qw(import);
use List::Util;

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

package Utils::Array {
    sub index_of($element, @array) {
        (List::Util::first { $array[$_] eq $element } 0 .. $#array) // -1;
    }
}

1;
