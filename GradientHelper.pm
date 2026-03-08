package GradientHelper {
    use v5.36;

    use Carp;
    use Scalar::Util qw(looks_like_number);

    use constant PI => 4 * atan2(1, 1);

    sub new(%args) {
        confess "missing angle_deg" unless exists $args{angle_deg};
        confess "missing start_color" unless exists $args{start_color};
        confess "missing end_color" unless exists $args{end_color};

        _assert_number("angle_deg", $args{angle_deg});
        _assert_color("start_color", $args{start_color});
        _assert_color("end_color", $args{end_color});

        my $shift = $args{shift} // 0;
        my $phase = $args{phase} // 0;
        _assert_number("shift", $shift);
        _assert_number("phase", $phase);

        my ($dir_x, $dir_y) = _deg_to_dir($args{angle_deg});
        my ($sr, $sg, $sb) = _unpack_rgb($args{start_color});
        my ($er, $eg, $eb) = _unpack_rgb($args{end_color});

        bless {
            angle_deg => $args{angle_deg},
            start_color => $args{start_color},
            end_color => $args{end_color},
            shift => $shift,
            phase => _wrap01($phase),
            dir_x => $dir_x,
            dir_y => $dir_y,
            _cache_w => undef,
            _cache_h => undef,
            _cx => 0,
            _cy => 0,
            _inv_span => 0,
            _pmin => 0,
            _sr => $sr,
            _sg => $sg,
            _sb => $sb,
            _dr => $er - $sr,
            _dg => $eg - $sg,
            _db => $eb - $sb,
        }, __PACKAGE__;
    }

    sub phase($self) {
        $self->{phase};
    }

    sub advance($self, $dt) {
        _assert_number("dt", $dt);
        $self->{phase} = _wrap01($self->{phase} + $self->{shift} * $dt);
        return $self;
    }

    sub color_at_local($self, $x, $y, $w, $h) {
        confess "w must be > 0" unless $w > 0;
        confess "h must be > 0" unless $h > 0;

        if (!defined($self->{_cache_w})
            || $self->{_cache_w} != $w
            || $self->{_cache_h} != $h) {
            _rebuild_geometry_cache($self, $w, $h);
        }

        my $lx = $x - $self->{_cx};
        my $ly = $self->{_cy} - $y;
        my $t = ($lx * $self->{dir_x} + $ly * $self->{dir_y} - $self->{_pmin})
            * $self->{_inv_span};
        $t = _clamp01($t);
        $t = _wrap01_closed($t + $self->{phase});

        my $r = int($self->{_sr} + $self->{_dr} * $t + 0.5);
        my $g = int($self->{_sg} + $self->{_dg} * $t + 0.5);
        my $b = int($self->{_sb} + $self->{_db} * $t + 0.5);
        $r = 0 if $r < 0;
        $r = 255 if $r > 255;
        $g = 0 if $g < 0;
        $g = 255 if $g > 255;
        $b = 0 if $b < 0;
        $b = 255 if $b > 255;
        return ($r << 16) | ($g << 8) | $b;
    }

    sub _rebuild_geometry_cache($self, $w, $h) {
        my $cx = ($w - 1) / 2;
        my $cy = ($h - 1) / 2;
        my $dx = $self->{dir_x};
        my $dy = $self->{dir_y};

        my $p00 = (0 - $cx) * $dx + ($cy - 0) * $dy;
        my $p10 = (($w - 1) - $cx) * $dx + ($cy - 0) * $dy;
        my $p01 = (0 - $cx) * $dx + ($cy - ($h - 1)) * $dy;
        my $p11 = (($w - 1) - $cx) * $dx + ($cy - ($h - 1)) * $dy;

        my $pmin = $p00;
        my $pmax = $p00;
        $pmin = $p10 if $p10 < $pmin;
        $pmin = $p01 if $p01 < $pmin;
        $pmin = $p11 if $p11 < $pmin;
        $pmax = $p10 if $p10 > $pmax;
        $pmax = $p01 if $p01 > $pmax;
        $pmax = $p11 if $p11 > $pmax;

        my $span = $pmax - $pmin;
        my $inv_span = abs($span) > 1e-12 ? (1 / $span) : 0;

        $self->{_cache_w} = $w;
        $self->{_cache_h} = $h;
        $self->{_cx} = $cx;
        $self->{_cy} = $cy;
        $self->{_pmin} = $pmin;
        $self->{_inv_span} = $inv_span;
    }

    sub _deg_to_dir($angle_deg) {
        my $rad = $angle_deg * PI / 180;
        return (cos($rad), sin($rad));
    }

    sub _unpack_rgb($color) {
        return (
            ($color >> 16) & 0xff,
            ($color >> 8) & 0xff,
            $color & 0xff,
        );
    }

    sub _clamp01($t) {
        return 0 if $t < 0;
        return 1 if $t > 1;
        return $t;
    }

    sub _wrap01($t) {
        $t = $t - int($t);
        $t += 1 if $t < 0;
        $t -= 1 if $t >= 1;
        return $t;
    }

    sub _wrap01_closed($t) {
        return $t if $t >= 0 && $t <= 1;
        if ($t > 1) {
            my $ti = int($t);
            return 1 if $t == $ti;
            return $t - $ti;
        }

        my $ti = int($t);
        $t = $t - $ti;
        $t += 1 if $t < 0;
        return $t;
    }

    sub _assert_number($name, $value) {
        confess "$name must be numeric"
            unless defined($value) && looks_like_number($value);
    }

    sub _assert_integer($name, $value) {
        _assert_number($name, $value);
        confess "$name must be an integer"
            unless int($value) == $value;
    }

    sub _assert_color($name, $value) {
        _assert_integer($name, $value);
        confess "$name must be in range 0x000000..0xFFFFFF"
            unless $value >= 0 && $value <= 0xFFFFFF;
    }
}

1;

__END__

=head1 NAME

GradientHelper

=head1 SYNOPSIS

    use GradientHelper;

    my $gradient = GradientHelper::new(
        angle_deg   => 45,
        start_color => 0x1d3557,
        end_color   => 0xe63946,
        shift       => 0.25,
    );

    $gradient->advance($dt);
    my $rgb = $gradient->color_at_local($x, $y, $w, $h);

=head1 DESCRIPTION

GradientHelper computes animated linear gradient colors in local widget
coordinates.

The gradient direction is controlled by C<angle_deg> where C<0> degrees
points left-to-right and C<90> degrees points bottom-to-top.

The C<shift> value controls animation speed in cycles per second and is
applied in C<advance($dt)> as C<phase += shift * dt>.

=head1 METHODS

=over 4

=item new(%args)

Creates a gradient helper.

Required keys:

=over 4

=item * C<angle_deg>

=item * C<start_color> (C<0xRRGGBB>)

=item * C<end_color> (C<0xRRGGBB>)

=back

Optional keys:

=over 4

=item * C<shift> (default C<0>)

=item * C<phase> (default C<0>, wrapped to C<[0,1)>)

=back

=item phase

Returns current phase in C<[0,1)>.

=item advance($dt)

Advances internal phase by C<shift * dt>. This method mutates the object
and returns C<$self>.

=item color_at_local($x, $y, $w, $h)

Returns the interpolated C<0xRRGGBB> color for local position C<($x,$y)>
within a rectangle of width C<$w> and height C<$h>.

=back
