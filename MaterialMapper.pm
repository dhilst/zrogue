package MaterialMapper;

use v5.36;
use utf8;
no autovivification;
use Carp;
use overload '&{}' => \&as_coderef, fallback => 1;

use lib ".";
use Utils qw(getters);

getters qw(mapper);

my @STYLE_KEYS = qw(-fg -bg -attrs);

sub from_callback($mapper) {
    confess "missing mapper" unless defined $mapper;
    confess "mapper must be a coderef" unless ref($mapper) eq 'CODE';
    bless {
        mapper => $mapper,
    }, __PACKAGE__;
}

sub style($self, $material) {
    my $style = $self->{mapper}->($material);
    confess "Invalid material $material" if !defined $style;
    confess "style must be a hashref" unless ref($style) eq 'HASH';
    for my $key (keys %$style) {
        confess "Invalid key $key"
            unless grep { $_ eq $key } @STYLE_KEYS;
    }
    return $style;
}

sub map($self, $material) {
    $self->style($material);
}

sub as_coderef($self, $other = undef, $swap = undef) {
    sub ($material) { $self->style($material) };
}

1;

__END__

=head1 NAME

MaterialMapper

=head1 SYNOPSIS

    use lib ".";
    use SGR qw(:attrs):
    use MaterialMapper;

    my $mat = MaterialMapper::from_callback(sub ($material) {
        return { -fg => 0xff00ff } if $material eq 'MAGENTA';
        return { -bg => 0x000000, -attrs => ATTR_BOLD } if $material eq 'HIGHLIGHT';
    });

    my $style = $mat->style('MAGENTA');

=head1 DESCRIPTION

MaterialMapper wraps a user-provided callback into a mapping from MATERIAL to STYLE.
STYLE is a hashref that may contain C<-fg>, C<-bg>, and C<-attrs> keys; any of
them may be absent. Unknown keys and undefined materials cause an error.

=head1 METHODS

=over 4

=item from_callback($callback)

Creates a MaterialMapper mapping. The callback is invoked as C<$callback->($material)>
and must return a style hashref or C<undef>.

=item style($material)

Returns a style hashref for the given material. If the callback returns
C<undef>, the method throws an error.

=item map($material)

Alias for C<style>.

=back

=head1 OVERLOADS

=over 4

=item &{}

Instances can be called like a coderef: C<$mat->($material)>.

=back
