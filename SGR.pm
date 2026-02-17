package SGR;
use v5.36;
use Exporter 'import';

use constant {
    ATTR_BOLD      => 1 << 0,
    ATTR_CONCEALED => 1 << 1,
    ATTR_DARK      => 1 << 2,
    ATTR_ITALIC    => 1 << 3,
    ATTR_REVERSE   => 1 << 4,
    ATTR_UNDERLINE => 1 << 5,
};


# Define what is available for export
our @EXPORT_OK = qw(
    ATTR_BOLD
    ATTR_CONCEALED
    ATTR_DARK
    ATTR_ITALIC
    ATTR_REVERSE
    ATTR_UNDERLINE
);

our %EXPORT_TAGS = ( attrs => \@EXPORT_OK );

sub fg($int) {
    sprintf "r%dg%db%d", 
        $int >> 16,
        $int >> 8 & 0xff,
        $int & 0xff;
}

sub bg($int) {
    sprintf "on_r%dg%db%d", 
        $int >> 16,
        $int >> 8 & 0xff,
        $int & 0xff;
}

sub attrs($attrs) {
    my @attrs;
    push @attrs, "bold" if $attrs & ATTR_BOLD;
    push @attrs, "concealed" if $attrs & ATTR_CONCEALED;
    push @attrs, "dark" if $attrs & ATTR_DARK;
    push @attrs, "italic" if $attrs & ATTR_ITALIC;
    push @attrs, "reverse" if $attrs & ATTR_REVERSE;
    push @attrs, "underline" if $attrs & ATTR_UNDERLINE;
    @attrs;
}

1;

__END__

=head1 NAME

SGR

=head1 SYNOPSIS

    use SGR qw(:attrs);
    my $fg = SGR::fg(0xff0000);
    my $bg = SGR::bg(0x000000);
    my @attrs = SGR::attrs(ATTR_BOLD | ATTR_UNDERLINE);

=head1 DESCRIPTION

SGR provides helpers for ANSI color and attribute strings compatible
with Term::ANSIColor. It also defines attribute bitmasks.

=head1 FUNCTIONS

=over 4

=item fg($rgb24)

Returns a Term::ANSIColor 24-bit foreground string.

=item bg($rgb24)

Returns a Term::ANSIColor 24-bit background string.

=item attrs($mask)

Expands a bitmask into a list of attribute strings.

=back
