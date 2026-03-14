package TerminalStyle;

use v5.36;
use utf8;
use Carp;
use overload '%{}' => \&as_hashref, fallback => 1;

my @STYLE_KEYS = qw(-fg -bg -attrs);

sub new(%args) {
    for my $key (keys %args) {
        confess "Invalid key $key"
            unless grep { $_ eq $key } @STYLE_KEYS;
    }

    _assert_color('-fg', $args{'-fg'}) if exists $args{'-fg'};
    _assert_color('-bg', $args{'-bg'}) if exists $args{'-bg'};
    _assert_integer('-attrs', $args{'-attrs'}) if exists $args{'-attrs'};

    my $self = {
        fg => exists($args{'-fg'}) ? $args{'-fg'} : undef,
        bg => exists($args{'-bg'}) ? $args{'-bg'} : undef,
        attrs => exists($args{'-attrs'}) ? $args{'-attrs'} : undef,
    };
    bless $self, __PACKAGE__;
}

sub from_hashref($style) {
    confess "style must be a hashref" unless ref($style) eq 'HASH';
    TerminalStyle::new($style->%*);
}

sub fg($self) {
    no overloading '%{}';
    return $self->{fg};
}

sub bg($self) {
    no overloading '%{}';
    return $self->{bg};
}

sub attrs($self) {
    no overloading '%{}';
    return $self->{attrs};
}

sub as_hashref($self, @ignored) {
    no overloading '%{}';
    my %style;
    $style{'-fg'} = $self->{fg} if defined $self->{fg};
    $style{'-bg'} = $self->{bg} if defined $self->{bg};
    $style{'-attrs'} = $self->{attrs} if defined $self->{attrs};
    return \%style;
}

sub _assert_integer($name, $value) {
    confess "$name must be an integer"
        unless defined($value) && int($value) == $value;
}

sub _assert_color($name, $value) {
    _assert_integer($name, $value);
    confess "$name must be -1 or in range 0x000000..0xFFFFFF"
        unless $value == -1 || ($value >= 0 && $value <= 0xFFFFFF);
}

1;

__END__

=head1 NAME

TerminalStyle

=head1 SYNOPSIS

    use TerminalStyle;

    my $style = TerminalStyle::new(
        -fg => 0xffffff,
        -bg => 0x10222c,
        -attrs => 0,
    );

    my $hash = $style->as_hashref;

=head1 DESCRIPTION

TerminalStyle formalizes the terminal style hash shape used throughout the
renderer stack. A style may contain C<-fg>, C<-bg>, and C<-attrs>.

Foreground and background colors use 24-bit RGB integers in the form
C<0xRRGGBB>. The sentinel value C<-1> is allowed to mean "leave terminal
default unchanged". Attributes are stored as an integer bitmask compatible
with L<SGR>.

=head1 METHODS

=over 4

=item new(%opts)

Constructs a style object from any combination of C<-fg>, C<-bg>, and
C<-attrs>. Unknown keys are rejected.

=item from_hashref($hashref)

Builds a style object from an existing style hashref.

=item fg

=item bg

=item attrs

Accessors for the normalized style fields.

=item as_hashref

Returns a new hashref containing only the defined style keys.

=back

=cut
