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
    use Carp;
    use Data::Dumper;

    sub index_of($element, @array) {
        (List::Util::first { $array[$_] eq $element } 0 .. $#array) // -1;
    }

    sub for_batch :prototype(&$$) {
        my ($block, $siz, $array) = @_;
        confess "missing arguments"
            unless defined $siz && defined $array;

        my $max = scalar $array->@*;
        my @out;
        for (my $offset = 0; $offset < $max; $offset += $siz) {

            my @slice = $array->@[$offset .. $offset + $siz - 1];
            my $result = $block->(@slice);
            # # do not push to array if we're in void context, this saves memory
            push @out, $result if defined wantarray;
        }
        @out;
    }

sub flatten(@values) {
    map { $_->@* } @values;
}
}

1;

__END__

=head1 NAME

Utils

=head1 SYNOPSIS

    use Utils qw(aref getters);

=head1 DESCRIPTION

Utils provides small helper functions used across the codebase. It also
defines C<Utils::Array> helpers for array batching and flattening.

=head1 FUNCTIONS

=over 4

=item aref(@values)

Returns a reference to the argument list.

=item getters(@fields)

Defines simple accessors in the caller package.

=back

=head1 Utils::Array

=over 4

=item index_of($value, @array)

Returns the index of the first matching element or -1.

=item for_batch { ... } $size, \@array

Iterates the array in fixed-size slices.

=item flatten(@values)

Flattens an array of arrayrefs.

=back
