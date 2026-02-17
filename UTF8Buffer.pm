package UTF8Buffer;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);

getters qw(buf);

sub new() {
    bless {
        buf => '',
    }, __PACKAGE__;
}

sub clear($self) {
    $self->{buf} = '';
}

sub push_bytes($self, $bytes) {
    return () unless defined $bytes && length($bytes) > 0;
    $self->{buf} .= $bytes;
    $self->_drain;
}

sub drain($self) {
    $self->_drain;
}

sub _drain($self) {
    use bytes;
    my @chars;
    my $buf = $self->{buf};
    while (length $buf) {
        if ($buf =~ /\A([\x00-\x7F]+)/) {
            my $seq = $1;
            $buf = substr($buf, length($seq));
            push @chars, split(//, $seq);
            next;
        }
        if ($buf =~ /\A([\xC2-\xDF][\x80-\xBF])/) {
            my $seq = $1;
            $buf = substr($buf, length($seq));
            my $char = $seq;
            utf8::decode($char);
            push @chars, $char;
            next;
        }
        if ($buf =~ /\A([\xE0-\xEF][\x80-\xBF]{2})/) {
            my $seq = $1;
            $buf = substr($buf, length($seq));
            my $char = $seq;
            utf8::decode($char);
            push @chars, $char;
            next;
        }
        if ($buf =~ /\A([\xF0-\xF4][\x80-\xBF]{3})/) {
            my $seq = $1;
            $buf = substr($buf, length($seq));
            my $char = $seq;
            utf8::decode($char);
            push @chars, $char;
            next;
        }
        # Incomplete or invalid sequence: keep for next poll if incomplete,
        # otherwise drop one byte to avoid stalling.
        if ($buf =~ /\A[\xC2-\xF4]/) {
            last;
        }
        $buf = substr($buf, 1);
    }
    $self->{buf} = $buf;
    @chars;
}

1;
