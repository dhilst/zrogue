package Buffer2D;

use v5.36;
use Carp;
use FindBin qw($Bin);
use lib "$Bin";
use Utils qw(getters);

getters qw(
    H
    W
    bsize
    buf
    defaults
    opts
    packstr
    size
    stride
    zeroed
);

sub new($packstr, $H, $W, $defaults, %opts) {
    my $stride = length(pack($packstr));
    my $size = $W * $H;
    my $bsize = $size * $stride;
    my $buf = pack($packstr, $defaults->@*) x $size;
    my $zeroed = $buf;
    $opts{-autoclip} //= 0;
    bless {
        H => $H,
        W => $W,
        _updated_rows => {},
        bsize => $bsize,
        buf => $buf,
        defaults => $defaults,
        opts => \%opts,
        packstr => $packstr,
        size => $size,
        stride => $stride,
        zeroed => $zeroed,
    }, __PACKAGE__;
}

sub from_other($other) {
    # This 
    my $self = { $other->%* };
    $self->{defaults} = [ $other->defaults->@* ];
    $self->{_updated_rows} = {};
    return bless $self, __PACKAGE__;

    # Instead of this;
    return bless {
        H => $other->H,                     # int
        W => $other->W,                     # int
        _updated_rows => {},
        bsize => $other->bsize,             # int
        buf => $other->buf,                 # string (Cow)
        defaults => [$other->defaults->@*], # array ref
        packstr => $other->packstr,         # string (CoW)
        opts => { $other->opts->%* },
        size => $other->size,               # int
        stride => $other->stride,           # int
        zeroed => $other->zeroed,
    }, __PACKAGE__;
}

sub copy($self) {
    Buffer2D::from_other($self);
}

sub valid($self, $col, $row, $length = 1) {
    my $colend = $col + $length - 1;
    0 <= $col && $col < $self->W
        && $col <= $colend && $colend < $self->W
        && 0 <= $row && $row < $self->H;
}

sub clip($self, $col, $row, $length) {
    use List::Util qw(min max);

    my $newcol = max(min($col, $self->W - 1), 0);
    my $newrow = max(min($row, $self->H - 1), 0);
    return ($newcol, $newrow, 0) if $length <= 0;
    return ($newcol, $newrow, 0)
        if $row < 0 || $row >= $self->H;

    my $start = max($col, 0);
    my $end = min($col + $length - 1, $self->W - 1);
    my $newlength = $end - $start + 1;
    return ($newcol, $newrow, 0) if $newlength <= 0;

    ($start, $row, $newlength);
}

sub index_unchecked($self, $col, $row) {
    (($row * $self->W) + $col) * $self->stride;
}

sub index($self, $col, $row, $length) {
    if ($self->opts->{-autoclip}) {
        my ($ccol, $crow, $clength) = $self->clip($col, $row, $length);
        return (undef, 0, 0) if $clength <= 0;
        my $skip = $ccol - $col;
        return ($self->index_unchecked($ccol, $crow), $clength * $self->stride, $skip);
    } else {
        confess "invalid access" 
            unless $self->valid($col, $row, $length);
        return ($self->index_unchecked($col, $row), $length * $self->stride, 0);
    }
}

sub getp($self, $col, $row) {
    my ($idx, $length) = $self->index($col, $row, 1);
    return undef if !$length;
    substr($self->buf, $idx, $length);
}

sub getp_unchecked($self, $col, $row) {
    my $idx = $self->index_unchecked($col, $row);
    substr($self->buf, $idx, $self->stride);
}

sub get($self, $col, $row) {
    my ($idx, $length) = $self->index($col, $row, 1);
    return if !$length;
    unpack($self->packstr, substr($self->buf, $idx, $length));
}

sub setp($self, $col, $row, $payload) {
    my ($idx, $length) = $self->index($col, $row, 1);
    return if !$length;
    $self->{_updated_rows}->{$row}++;
    substr($self->{buf}, $idx, $length) = $payload;
    $self->{_updated_rows}->{$row}++;
}


sub set($self, $col, $row, $values) {
    my ($idx, $length) = $self->index($col, $row, 1);
    return if !$length;
    substr($self->{buf}, $idx, $length) = pack($self->packstr, $values->@*);
    $self->{_updated_rows}->{$row}++;
}

sub update($self, $col, $row, $values) {
    $self->update_multi($col, $row, $values);
}

sub get_multi($self, $col, $row, $n) {
    my $stride = $self->stride;
    my ($idx, $length) = $self->index($col, $row, $n);
    return if !$length;
    my $count = $length / $stride;
    my $payloads = substr($self->{buf}, $idx, $length);
    my @values;
    for (0 .. $count - 1) {
        my $payload = substr($payloads, $_ * $stride);
        push @values, [ unpack($self->packstr, $payload) ];
    }

    @values;
}

sub get_multi_unchecked($self, $col, $row, $n) {
    my $stride = $self->stride;
    my $idx = $self->index_unchecked($col, $row);
    my $length = $n * $stride;
    my $payloads = substr($self->{buf}, $idx, $length);
    my @values;
    for (0 .. $n - 1) {
        my $payload = substr($payloads, $_ * $stride);
        push @values, [ unpack($self->packstr, $payload) ];
    }

    @values;
}

sub set_multi($self, $col, $row, @values) {
    my $stride = $self->stride;
    my ($idx, $length, $skip) = $self->index($col, $row, scalar @values);
    return if !$length;
    my $count = $length / $stride;
    my @clipped = @values[$skip .. $skip + $count - 1];
    confess "undef in payload" if
        grep { !defined } map { $_->@* } @clipped;
    my $payload = pack(sprintf("(%s)*", $self->packstr), map { $_->@* } @clipped);
    substr($self->{buf}, $idx, $length) = $payload;
    $self->{_updated_rows}->{$row}++;
}

sub set_multi_unchecked($self, $col, $row, @values) {
    my $stride = $self->stride;
    my $idx = $self->index_unchecked($col, $row);
    my $length = scalar(@values) * $stride;
    confess "undef in payload" if
        grep { !defined } map { $_->@* } @values;
    my $payload = pack(sprintf("(%s)*", $self->packstr), map { $_->@* } @values);
    substr($self->{buf}, $idx, $length) = $payload;
    $self->{_updated_rows}->{$row}++;
}

sub _merge_payload($payload, $values, $offset, $count) {
    for (my $i = 0; $i < $count; $i++) {
        my $src = $values->[$offset + $i];
        for (my $j = 0; $j < $src->@*; $j++) {
            $payload->[$i][$j] = $src->[$j]
                if defined $src->[$j];
        }
    }
}

sub update_multi($self, $col, $row, @values) {
    my $n = scalar @values;
    return if $n <= 0;
    my $valid = $self->valid($col, $row, $n);
    if ($valid) {
        my @payload = $self->get_multi_unchecked($col, $row, $n);
        _merge_payload(\@payload, \@values, 0, $n);
        $self->set_multi_unchecked($col, $row, @payload);
        return;
    }

    confess "invalid access" if $self->opts->{-autoclip} == 0;

    my $stride = $self->stride;
    my ($idx, $length, $skip) = $self->index($col, $row, $n);
    return if !$length;
    my $count = $length / $stride;
    my @payload = $self->get_multi($col + $skip, $row, $count);
    _merge_payload(\@payload, \@values, $skip, $count);
    $self->set_multi($col + $skip, $row, @payload);
}

sub xor_inplace($self, $other) {
    $self->{buf} ^.= $other->buf;
}

sub diff($self, $other) {
    my $delta = $self->copy;
    $delta->xor_inplace($other);
    my @indexes;
    my $zero = "\0" x $delta->stride;
    my $stride = $self->stride;
    my $row_stride = $self->{W} * $stride;
    my $pack_template = sprintf("(%s)*", $self->packstr);
    for my $row (sort { $a <=> $b } keys $self->{_updated_rows}->%*) {
        next if $row < 0 || $row >= $self->{H};
        my $row_base = $row * $row_stride;
        my $col = 0;
        while ($col < $self->{W}) {
            my $idx = $row_base + $col * $stride;
            my $pack = substr($delta->{buf}, $idx, $stride);
            if ($pack eq $zero) {
                $col++;
                next;
            }

            my $start = $col;
            $col++;
            while ($col < $self->{W}) {
                $idx = $row_base + $col * $stride;
                $pack = substr($delta->{buf}, $idx, $stride);
                last if $pack eq $zero;
                $col++;
            }
            my $size = $col - $start;
            my $payload_bytes = substr($self->{buf}, $row_base + $start * $stride, $size * $stride);
            my @payload = unpack($pack_template, $payload_bytes);
            push @indexes, {
                col => $start,
                row => $row,
                payload => \@payload,
                size => $size,
            };
        }
    }
    $self->{_updated_rows} = {};
    @indexes;
}

sub sync($self, $other) {
    $self->{buf} = $other->buf;
}

sub to_string($self, @ignored) {
    my @lines;
    for my $row (0 .. $self->H - 1) {
        push @lines, unpack("H*", 
                substr($self->buf,
                    $row * $self->W * $self->stride,
                    $self->stride * $self->W));

    }
    join "\n", @lines;
}

sub reset($self) {
    $self->{buf} = $self->zeroed;
}

1;

__END__

=head1 NAME

Buffer2D

=head1 SYNOPSIS

    use Buffer2D;
    my $buf = Buffer2D::new("l4", $H, $W, \@defaults, -autoclip => 1);
    $buf->set($col, $row, [@values]);
    my @cell = $buf->get($col, $row);

=head1 DESCRIPTION

Buffer2D is a 2D packed buffer for per-cell payloads. It stores a grid
of fixed-size packed records and provides helpers for indexed reads,
writes, and batched updates. Optional autoclip protects out-of-bounds
accesses by clipping writes and reads.

=head1 METHODS

=over 4

=item new($packstr, $H, $W, $defaults, %opts)

Creates a buffer with pack template C<$packstr> and default payload.
If C<-autoclip> is true, out-of-range writes are clipped instead of
throwing.

=item get / set / update

Read or write a single cell at C<($col, $row)>.

=item get_multi / set_multi / update_multi

Batch operations for a horizontal run of cells. Update merges defined
fields into existing payloads.

=item diff($other)

Returns a list of changed spans between buffers.

=item sync($other)

Copies the raw buffer from another instance.

=item reset

Resets the buffer to the default payloads.

=back
