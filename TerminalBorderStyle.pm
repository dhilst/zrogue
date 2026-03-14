package TerminalBorderStyle;

use v5.36;
use utf8;
use Carp qw(confess);

my @STYLE_KEYS = qw(-fg -bg -attrs -border);

sub new(%args) {
    for my $key (keys %args) {
        confess "Invalid key $key"
            unless grep { $_ eq $key } @STYLE_KEYS;
    }

    confess "-fg must be -1 or in range 0x000000..0xFFFFFF"
        if exists($args{'-fg'}) && !_valid_color($args{'-fg'});
    confess "-bg must be -1 or in range 0x000000..0xFFFFFF"
        if exists($args{'-bg'}) && !_valid_color($args{'-bg'});
    confess "-attrs must be an integer"
        if exists($args{'-attrs'}) && !_valid_integer($args{'-attrs'});

    my $border = exists($args{'-border'})
        ? _normalize_border($args{'-border'})
        : ['+', '-', '+', '|', ' ', '|', '+', '-', '+'];

    my $self = {
        fg => exists($args{'-fg'}) ? $args{'-fg'} : 0xffffff,
        bg => exists($args{'-bg'}) ? $args{'-bg'} : 0x000000,
        attrs => exists($args{'-attrs'}) ? $args{'-attrs'} : 0,
        border => $border,
    };
    bless $self, __PACKAGE__;
}

sub fg($self) {
    return $self->{fg};
}

sub bg($self) {
    return $self->{bg};
}

sub attrs($self) {
    return $self->{attrs};
}

sub border($self) {
    return [ $self->{border}->@* ];
}

sub _normalize_border($border) {
    confess "-border must be an arrayref" unless ref($border) eq 'ARRAY';
    confess "-border must contain exactly 9 entries" unless $border->@* == 9;
    return [ map { defined($_) ? "$_" : '' } $border->@* ];
}

sub _valid_integer($value) {
    return defined($value) && int($value) == $value;
}

sub _valid_color($value) {
    return 0 unless _valid_integer($value);
    return $value == -1 || ($value >= 0 && $value <= 0xFFFFFF);
}

1;

__END__

=head1 NAME

TerminalBorderStyle

=head1 SYNOPSIS

    use TerminalBorderStyle;

    my $style = TerminalBorderStyle::new(
        -fg => 0xffffff,
        -bg => 0x000000,
        -attrs => 0,
        -border => ['+', '-', '+', '|', ' ', '|', '+', '-', '+'],
    );

=head1 DESCRIPTION

TerminalBorderStyle formalizes the border style shape used by border rendering.
It contains terminal colors and attributes along with a 3x3 border glyph layout.

=head1 METHODS

=over 4

=item new(%opts)

Constructs a border style object. Valid keys are C<-fg>, C<-bg>, C<-attrs>, and
C<-border>. Missing values are filled with defaults.

=item fg

=item bg

=item attrs

=item border

Accessors for the normalized border style fields. C<border> returns a fresh
9-entry arrayref.

=back

=cut
