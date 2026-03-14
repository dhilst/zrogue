package TML;
use v5.36;
use utf8;

use Carp;
use Exporter qw(import);

use lib ".";
use Event;
use Matrix3;

our @EXPORT_OK = qw(
    App
    Layer
    VBox
    HBox
    BBox
    Rect
    Text
    OnKey
    OnUpdate
);

our @BUILD_STACK;
our $BUILD_APP;

sub _norm_opts(@args) {
    confess "options must be key/value pairs"
        if @args % 2 != 0;

    my %opts;
    while (@args) {
        my ($key, $val, @rest) = @args;
        @args = @rest;
        confess "invalid option key"
            unless defined $key && !ref($key);
        $key =~ s/^-//;
        $opts{$key} = $val;
    }
    return \%opts;
}

sub _resolve($app, $renderer, $node, $value) {
    return $value->($app, $renderer, $node)
        if ref($value) eq 'CODE';
    return $value;
}

sub _resolve_int($app, $renderer, $node, $value, $default = 0) {
    my $v = defined($value)
        ? _resolve($app, $renderer, $node, $value)
        : $default;
    return int($v // 0);
}

sub _current_parent() {
    confess "TML node used outside App{}"
        unless @BUILD_STACK;
    return $BUILD_STACK[-1];
}

sub _append_node($node) {
    push _current_parent()->{children}->@*, $node;
    return $node;
}

sub _build_node($type, $block, @args) {
    my $node = {
        type => $type,
        props => _norm_opts(@args),
        children => [],
    };
    _append_node($node);
    if (defined $block) {
        push @BUILD_STACK, $node;
        $block->();
        pop @BUILD_STACK;
    }
    return $node;
}

sub App :prototype(&;@) {
    my ($block, @args) = @_;
    confess "nested App{} is not supported"
        if defined $BUILD_APP;

    my $opts = _norm_opts(@args);
    my $app = TML::Runtime::App->_new($opts);

    my $root = {
        type => 'Layer',
        props => {},
        children => [],
    };
    $app->{root} = $root;

    local $BUILD_APP = $app;
    local @BUILD_STACK = ($root);
    $block->();

    return $app;
}

sub Layer :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('Layer', $block, @args);
}

sub VBox :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('VBox', $block, @args);
}

sub HBox :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('HBox', $block, @args);
}

sub BBox :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('BBox', $block, @args);
}

sub Rect :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('Rect', $block, @args);
}

sub Text :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('Text', $block, @args);
}

sub OnKey :prototype($$) {
    my ($char, $cb) = @_;
    confess "OnKey used outside App{}"
        unless defined $BUILD_APP;
    confess "OnKey expects a character string"
        unless defined $char && !ref($char);
    confess "OnKey expects a callback coderef"
        unless ref($cb) eq 'CODE';
    push $BUILD_APP->{on_key}->@*, [$char, $cb];
    return;
}

sub OnUpdate :prototype(&) {
    my ($cb) = @_;
    confess "OnUpdate used outside App{}"
        unless defined $BUILD_APP;
    push $BUILD_APP->{on_update}->@*, $cb;
    return;
}

package TML::Runtime::App {
    use v5.36;
    use Carp;
    use Scalar::Util qw(refaddr);

    sub _new($class, $opts) {
        my $state = $opts->{state} // {};
        confess "state must be a hashref"
            unless ref($state) eq 'HASH';

        return bless {
            root => undef,
            state => $state,
            on_key => [],
            on_update => [],
            quit => 0,
            skip_render_once => 0,
            layout_cache => {},
            frame_layout_cache => {},
            layout_tree_sig => undef,
            layout_size_sig => undef,
            layout_dynamic_nodes => {},
        }, $class;
    }

    sub state($self) { $self->{state} }

    sub _cache_node_id($self, $node) {
        return 0 unless defined($node) && ref($node);
        return refaddr($node) // 0;
    }

    sub _cache_key($self, $node, $parent_w, $parent_h, @extra) {
        my @parts = (
            $self->_cache_node_id($node),
            (defined $parent_w ? $parent_w : 'u'),
            (defined $parent_h ? $parent_h : 'u'),
            map { defined $_ ? $_ : 'u' } @extra,
        );
        return join "\x1f", @parts;
    }

    sub _cache_fetch($self, $bucket, $node, $parent_w, $parent_h, @extra) {
        my $key = $self->_cache_key($node, $parent_w, $parent_h, @extra);
        my $frame_bucket = ($self->{frame_layout_cache}{$bucket} //= {});
        if (exists $frame_bucket->{$key}) {
            return $frame_bucket->{$key};
        }

        my $node_id = $self->_cache_node_id($node);
        my $is_dynamic = $self->{layout_dynamic_nodes}{$node_id} // 1;
        return undef if $is_dynamic;

        my $persistent_bucket = ($self->{layout_cache}{$bucket} //= {});
        return undef unless exists $persistent_bucket->{$key};

        my $cached = $persistent_bucket->{$key};
        $frame_bucket->{$key} = $cached;
        return $cached;
    }

    sub _cache_store($self, $bucket, $node, $parent_w, $parent_h, $value, @extra) {
        my $key = $self->_cache_key($node, $parent_w, $parent_h, @extra);
        my $frame_bucket = ($self->{frame_layout_cache}{$bucket} //= {});
        $frame_bucket->{$key} = $value;

        my $node_id = $self->_cache_node_id($node);
        my $is_dynamic = $self->{layout_dynamic_nodes}{$node_id} // 1;
        if (!$is_dynamic) {
            my $persistent_bucket = ($self->{layout_cache}{$bucket} //= {});
            $persistent_bucket->{$key} = $value;
        }

        return $value;
    }

    sub _tree_signature_walk($self, $node, $parts, $dynamic_nodes) {
        my $node_id = $self->_cache_node_id($node);
        my $props = $node->{props} // {};
        my $children = $node->{children} // [];
        my @keys = sort keys $props->%*;

        push @$parts, 'N', ($node->{type} // ''), $node_id, scalar(@keys), scalar($children->@*);

        my $dynamic = 0;
        for my $key (@keys) {
            my $value = $props->{$key};
            if (!defined $value) {
                push @$parts, 'P', $key, 'U';
                next;
            }
            if (!ref($value)) {
                my $text = "$value";
                push @$parts, 'P', $key, 'S' . length($text) . ':' . $text;
                next;
            }

            my $type = ref($value);
            my $addr = refaddr($value) // 0;
            push @$parts, 'P', $key, "R:$type:$addr";
            $dynamic = 1 if $type eq 'CODE';
        }

        for my $child (@$children) {
            $dynamic ||= $self->_tree_signature_walk($child, $parts, $dynamic_nodes);
        }

        $dynamic_nodes->{$node_id} = $dynamic ? 1 : 0;
        return $dynamic;
    }

    sub _refresh_layout_caches($self, $avail_w = undef, $avail_h = undef) {
        my $clear_persistent = 0;

        my $size_sig = join "\x1f",
            (defined $avail_w ? $avail_w : 'u'),
            (defined $avail_h ? $avail_h : 'u');
        if (!defined($self->{layout_size_sig}) || $self->{layout_size_sig} ne $size_sig) {
            $self->{layout_size_sig} = $size_sig;
            $clear_persistent = 1;
        }

        my @parts;
        my %dynamic_nodes;
        if (defined $self->{root}) {
            $self->_tree_signature_walk($self->{root}, \@parts, \%dynamic_nodes);
        }
        my $tree_sig = join "\x1f", @parts;
        if (!defined($self->{layout_tree_sig}) || $self->{layout_tree_sig} ne $tree_sig) {
            $self->{layout_tree_sig} = $tree_sig;
            $clear_persistent = 1;
        }

        if ($clear_persistent) {
            $self->{layout_cache} = {};
        }

        $self->{layout_dynamic_nodes} = \%dynamic_nodes;
        $self->{frame_layout_cache} = {};
        return;
    }

    sub quit($self) {
        $self->{quit} = 1;
        return;
    }

    sub skip_render($self) {
        $self->{skip_render_once} = 1;
        return;
    }

    sub _axis_align($self, $axis, $align, $default = 'start') {
        my $token = lc($align // '');
        return $default if $token eq '';

        if ($token eq 'center') {
            return 'center';
        }

        if ($axis eq 'horizontal') {
            return 'start' if $token eq 'left' || $token eq 'up';
            return 'end' if $token eq 'right' || $token eq 'down';
        } else {
            return 'start' if $token eq 'up' || $token eq 'left';
            return 'end' if $token eq 'down' || $token eq 'right';
        }

        confess "invalid align '$align' for $axis axis";
    }

    sub _align_offset($self, $outer, $inner, $axis, $align, $default = 'start') {
        my $mode = $self->_axis_align($axis, $align, $default);
        return 0 if $mode eq 'start';
        return int(($outer - $inner) / 2) if $mode eq 'center';
        return $outer - $inner;
    }

    sub _children_extent($self, $renderer, $node, $children, $parent_w = undef, $parent_h = undef) {
        my $cached = $self->_cache_fetch(
            'children_extent', $node, $parent_w, $parent_h
        );
        return $cached->@* if defined $cached;

        my $max_col = 0;
        my $max_row = 0;

        for my $child (@$children) {
            my $props = $child->{props};
            my $cx = TML::_resolve_int($self, $renderer, $child, $props->{x}, 0);
            my $cy = TML::_resolve_int($self, $renderer, $child, $props->{y}, 0);
            my ($cw, $ch) = $self->_node_dimensions($renderer, $child, $parent_w, $parent_h);

            my $col_end = $cx + $cw;
            my $row_end = (-$cy) + $ch;
            $max_col = $col_end if $col_end > $max_col;
            $max_row = $row_end if $row_end > $max_row;
        }

        my $result = [$max_col, $max_row];
        $self->_cache_store('children_extent', $node, $parent_w, $parent_h, $result);
        return $result->@*;
    }

    sub _resolve_length($self, $renderer, $node, $value, $parent_len, $label, $default = undef) {
        my $resolved = defined($value)
            ? TML::_resolve($self, $renderer, $node, $value)
            : $default;
        return undef unless defined $resolved;

        if (!ref($resolved) && $resolved =~ /^\s*([+-]?\d+(?:\.\d+)?)%\s*$/) {
            confess "$label percentage requires parent size"
                unless defined $parent_len;
            my $pct = 0 + $1;
            my $len = int($parent_len * $pct / 100);
            $len = 0 if $len < 0;
            return $len;
        }

        if (!ref($resolved) && $resolved =~ /^\s*[+-]?\d+(?:\.\d+)?\s*$/) {
            return int($resolved);
        }

        confess "$label must be numeric or percentage string";
    }

    sub _container_layout($self, $renderer, $node, $type, $parent_w = undef, $parent_h = undef) {
        my $cached = $self->_cache_fetch(
            'container_layout', $node, $parent_w, $parent_h, $type
        );
        return $cached->@* if defined $cached;

        my $props = $node->{props};
        my $gap = TML::_resolve_int($self, $renderer, $node, $props->{gap}, 0);
        $gap = 0 if $gap < 0;

        my $box_w = exists $props->{width}
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width')
            : undef;
        my $box_h = exists $props->{height}
            ? $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height')
            : undef;

        my $child_parent_w = defined($box_w) ? $box_w : $parent_w;
        my $child_parent_h = defined($box_h) ? $box_h : $parent_h;

        my @children = $node->{children}->@*;
        my @child_dims = map {
            [ $self->_node_dimensions($renderer, $_, $child_parent_w, $child_parent_h) ]
        } @children;

        my ($natural_w, $natural_h) = (0, 0);
        if ($type eq 'VBox') {
            for my $dim (@child_dims) {
                $natural_w = $dim->[0] if $dim->[0] > $natural_w;
                $natural_h += $dim->[1];
            }
            $natural_h += $gap * (@child_dims - 1) if @child_dims > 1;
        } else {
            for my $dim (@child_dims) {
                $natural_h = $dim->[1] if $dim->[1] > $natural_h;
                $natural_w += $dim->[0];
            }
            $natural_w += $gap * (@child_dims - 1) if @child_dims > 1;
        }

        $box_w = $natural_w unless defined $box_w;
        $box_h = $natural_h unless defined $box_h;
        $box_w = 0 if $box_w < 0;
        $box_h = 0 if $box_h < 0;

        my $align = TML::_resolve($self, $renderer, $node, $props->{align});
        my $main_align = TML::_resolve($self, $renderer, $node,
            exists($props->{main_align}) ? $props->{main_align} : $align);
        my $cross_align = TML::_resolve($self, $renderer, $node,
            exists($props->{cross_align}) ? $props->{cross_align} : $align);

        my ($main_axis, $cross_axis, $default_main, $default_cross) =
            $type eq 'VBox'
            ? ('vertical', 'horizontal', 'start', 'start')
            : ('horizontal', 'vertical', 'start', 'start');

        my $outer_main = $type eq 'VBox' ? $box_h : $box_w;
        my $inner_main = $type eq 'VBox' ? $natural_h : $natural_w;
        my $outer_cross = $type eq 'VBox' ? $box_w : $box_h;

        my $cursor = $self->_align_offset(
            $outer_main,
            $inner_main,
            $main_axis,
            $main_align,
            $default_main,
        );

        my @placements;
        for my $idx (0 .. $#children) {
            my $child = $children[$idx];
            my ($cw, $ch) = $child_dims[$idx]->@*;
            my $cross = $self->_align_offset(
                $outer_cross,
                $type eq 'VBox' ? $cw : $ch,
                $cross_axis,
                $cross_align,
                $default_cross,
            );

            if ($type eq 'VBox') {
                push @placements, { child => $child, x => $cross, y => $cursor };
                $cursor += $ch + $gap;
            } else {
                push @placements, { child => $child, x => $cursor, y => $cross };
                $cursor += $cw + $gap;
            }
        }

        my $result = [\@placements, $box_w, $box_h];
        $self->_cache_store(
            'container_layout', $node, $parent_w, $parent_h, $result, $type
        );
        return $result->@*;
    }

    sub _bbox_layout($self, $renderer, $node, $parent_w = undef, $parent_h = undef) {
        my $cached = $self->_cache_fetch(
            'bbox_layout', $node, $parent_w, $parent_h
        );
        return $cached->@* if defined $cached;

        my $props = $node->{props};
        my $box_w = exists $props->{width}
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width')
            : undef;
        my $box_h = exists $props->{height}
            ? $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height')
            : undef;

        my $inner_hint_w = defined($box_w) ? ($box_w - 2) : (defined($parent_w) ? ($parent_w - 2) : undef);
        my $inner_hint_h = defined($box_h) ? ($box_h - 2) : (defined($parent_h) ? ($parent_h - 2) : undef);
        $inner_hint_w = 0 if defined($inner_hint_w) && $inner_hint_w < 0;
        $inner_hint_h = 0 if defined($inner_hint_h) && $inner_hint_h < 0;

        my ($content_w, $content_h) = $self->_children_extent(
            $renderer,
            $node,
            $node->{children},
            $inner_hint_w,
            $inner_hint_h,
        );

        $box_w = $content_w + 2 unless defined $box_w;
        $box_h = $content_h + 2 unless defined $box_h;

        $box_w = 2 if $box_w < 2;
        $box_h = 2 if $box_h < 2;

        my $inner_w = $box_w - 2;
        my $inner_h = $box_h - 2;

        my $align = TML::_resolve($self, $renderer, $node, $props->{align});
        my $h_align = TML::_resolve($self, $renderer, $node,
            exists($props->{h_align}) ? $props->{h_align} : $align);
        my $v_align = TML::_resolve($self, $renderer, $node,
            exists($props->{v_align}) ? $props->{v_align} : $align);

        my $content_x = 1 + $self->_align_offset(
            $inner_w, $content_w, 'horizontal', $h_align, 'start'
        );
        my $content_y = 1 + $self->_align_offset(
            $inner_h, $content_h, 'vertical', $v_align, 'start'
        );

        my $result = [$box_w, $box_h, $content_x, $content_y];
        $self->_cache_store('bbox_layout', $node, $parent_w, $parent_h, $result);
        return $result->@*;
    }

    sub _node_dimensions($self, $renderer, $node, $parent_w = undef, $parent_h = undef) {
        my $cached = $self->_cache_fetch(
            'node_dimensions', $node, $parent_w, $parent_h
        );
        return $cached->@* if defined $cached;

        my $props = $node->{props};
        my $type = $node->{type};

        if ($type eq 'Rect') {
            my $w = $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width', 0);
            my $h = $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height', 0);
            $w = 0 if $w < 0;
            $h = 0 if $h < 0;
            my $result = [$w, $h];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'Text') {
            my $text = TML::_resolve($self, $renderer, $node, $props->{text} // '');
            my $w = length("$text");
            my $result = [$w, 1];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'VBox' || $type eq 'HBox') {
            my ($placements, $w, $h) = $self->_container_layout(
                $renderer, $node, $type, $parent_w, $parent_h
            );
            my $result = [$w, $h];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'BBox') {
            my ($w, $h, $content_x, $content_y) = $self->_bbox_layout(
                $renderer, $node, $parent_w, $parent_h
            );
            my $result = [$w, $h];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        my ($natural_w, $natural_h) = $self->_children_extent(
            $renderer,
            $node,
            $node->{children},
            $parent_w,
            $parent_h,
        );
        my $w = exists $props->{width}
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width', $natural_w)
            : $natural_w;
        my $h = exists $props->{height}
            ? $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height', $natural_h)
            : $natural_h;
        $w = 0 if $w < 0;
        $h = 0 if $h < 0;
        my $result = [$w, $h];
        $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
        return $result->@*;
    }

    sub _render_rect($self, $renderer, $node, $local, $parent_w = undef, $parent_h = undef) {
        my $props = $node->{props};
        my $w = $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width', 0);
        my $h = $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height', 0);
        return if $w <= 0 || $h <= 0;

        my $material = TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
        $renderer->render_rect($local, $w, $h, -material => $material);
    }

    sub _render_bbox($self, $renderer, $node, $local, $parent_w = undef, $parent_h = undef) {
        my $props = $node->{props};
        my ($w, $h, $content_x, $content_y) = $self->_bbox_layout(
            $renderer, $node, $parent_w, $parent_h
        );
        return if $w <= 0 || $h <= 0;

        my $material = TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
        my $border_material = TML::_resolve($self, $renderer, $node, $props->{border_material} // 'DEFAULT');

        if ($w > 2 && $h > 2) {
            my $inner_origin = $local + Matrix3::Vec::from_xy(1, -1);
            $renderer->render_rect($inner_origin, $w - 2, $h - 2, -material => $material);
        }
        $renderer->render_border($local, $w, $h, -border_material => $border_material);

        my $content_base = $local + Matrix3::Vec::from_xy($content_x, -$content_y);
        my $inner_w = $w - 2;
        my $inner_h = $h - 2;
        for my $child ($node->{children}->@*) {
            $self->_render_node($renderer, $child, $content_base, $inner_w, $inner_h);
        }
    }

    sub _render_node($self, $renderer, $node, $base, $parent_w = undef, $parent_h = undef) {
        my $props = $node->{props};
        my $x = TML::_resolve_int($self, $renderer, $node, $props->{x}, 0);
        my $y = TML::_resolve_int($self, $renderer, $node, $props->{y}, 0);
        my $local = $base + Matrix3::Vec::from_xy($x, $y);

        if ($node->{type} eq 'Rect') {
            $self->_render_rect($renderer, $node, $local, $parent_w, $parent_h);
        } elsif ($node->{type} eq 'Text') {
            my $text = TML::_resolve($self, $renderer, $node, $props->{text} // '');
            my $material = TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
            my $justify = TML::_resolve($self, $renderer, $node, $props->{justify});
            my %opts = (-material => $material);
            $opts{-justify} = $justify if defined $justify;
            $renderer->render_text($local, "$text", %opts);
        } elsif ($node->{type} eq 'VBox' || $node->{type} eq 'HBox') {
            my ($placements, $w, $h) = $self->_container_layout(
                $renderer, $node, $node->{type}, $parent_w, $parent_h
            );
            for my $placement (@$placements) {
                my $child_pos = $local + Matrix3::Vec::from_xy($placement->{x}, -$placement->{y});
                $self->_render_node($renderer, $placement->{child}, $child_pos, $w, $h);
            }
            return;
        } elsif ($node->{type} eq 'BBox') {
            $self->_render_bbox($renderer, $node, $local, $parent_w, $parent_h);
            return;
        }

        my $child_parent_w = $parent_w;
        my $child_parent_h = $parent_h;
        if (exists $props->{width}) {
            $child_parent_w = $self->_resolve_length(
                $renderer, $node, $props->{width}, $parent_w, 'width', $child_parent_w
            );
        }
        if (exists $props->{height}) {
            $child_parent_h = $self->_resolve_length(
                $renderer, $node, $props->{height}, $parent_h, 'height', $child_parent_h
            );
        }

        for my $child ($node->{children}->@*) {
            $self->_render_node($renderer, $child, $local, $child_parent_w, $child_parent_h);
        }
    }

    sub update($self, $delta_time, @events) {
        for my $cb ($self->{on_update}->@*) {
            $cb->($self, $delta_time, @events);
        }

        for my $event (@events) {
            next unless $event->type eq Event::Type::KEY_PRESS;
            my $ch = $event->payload->char;
            for my $handler ($self->{on_key}->@*) {
                my ($want, $cb) = $handler->@*;
                next unless $ch eq $want;
                $cb->($self, $event);
            }
        }

        return 0 if $self->{quit};
        if ($self->{skip_render_once}) {
            $self->{skip_render_once} = 0;
            return -1;
        }
        return 1;
    }

    sub render($self, $renderer) {
        my $origin = Matrix3::Vec::from_xy(0, 0);
        my $avail_w = $renderer->can('width') ? $renderer->width : undef;
        my $avail_h = $renderer->can('height') ? $renderer->height : undef;
        $self->_refresh_layout_caches($avail_w, $avail_h);
        for my $child ($self->{root}->{children}->@*) {
            $self->_render_node($renderer, $child, $origin, $avail_w, $avail_h);
        }
    }
}

1;

__END__

=head1 NAME

TML - Block-based Perl EDSL for terminal widget trees

=head1 SYNOPSIS

    use TML qw(App Layer VBox HBox BBox Rect Text OnKey OnUpdate);

    my $ui = App {
        OnKey 'q' => sub ($app, $event) { $app->quit; };

        BBox {
            HBox {
                Text {} -text => 'Left',   -material => 'ACCENT';
                Text {} -text => 'Center', -material => 'ACCENT';
                Text {} -text => 'Right',  -material => 'ACCENT';
            } -gap => 2, -align => 'center';
        } -x => -10, -y => 4,
          -border_material => 'FRAME',
          -material => 'ACCENT';
    } -state => {};

=head1 DESCRIPTION

TML builds a widget tree directly from Perl blocks and returns a runtime app
object compatible with C<GameLoop> (C<update($dt,@events)> and
C<render($renderer)>).

There is no string parsing or compile step. Widgets are declared using Perl
function calls (C<App>, C<VBox>, C<Text>, etc.) and options passed as key/value
pairs.

=head1 REQUIREMENTS

TML currently assumes the following runtime contracts:

=over 4

=item *

The app object returned by C<App> must provide C<update($dt, @events)> and
C<render($renderer)> so it can be driven by L<GameLoop>.

=item *

TML should be style agnostic. Node styling should follow from a semantic
C<material> string property, not from terminal-specific style fields on nodes.

=item *

TML should not import or depend directly on mapper or style classes; semantic
material resolution belongs later in the rendering pipeline.

=item *

The renderer passed to C<render> must support the drawing methods used by the
node walker, including C<render_text>, C<render_rect>, C<render_border>, and
when applicable C<width> and C<height> for percentage-based layout.

=item *

Node trees are built from plain Perl data structures and are expected to remain
well-formed: each node has a C<type>, a C<props> hashref, and a C<children>
arrayref.

=back

=head1 EXPORTS

All functions are exported on demand via C<@EXPORT_OK>:

    App Layer VBox HBox BBox Rect Text OnKey OnUpdate

=head1 APP

=head2 App BLOCK, %opts

Root builder. Returns a C<TML::Runtime::App> object.

Supported app options:

=over 4

=item * C<-state> (hashref, default C<{}>)

Mutable state bag exposed as C<$app->state>.

=back

=head1 EVENTS

=head2 OnKey CHAR, CODEREF

Registers a key handler:

    OnKey 'q' => sub ($app, $event) { ... };

Called for C<Event::Type::KEY_PRESS> events whose character matches C<CHAR>.

=head2 OnUpdate BLOCK

Registers a per-frame update callback:

    OnUpdate { my ($app, $dt, @events) = @_; ... };

=head1 NODES

Each node accepts an optional child block and option pairs.
Common positional options:

=over 4

=item * C<-x> (default 0)

=item * C<-y> (default 0)

=back

Values may be plain scalars or coderefs. For most properties, coderef signature
is:

    sub ($app, $renderer, $node) { ... }

Length properties such as C<-width> and C<-height> accept:

=over 4

=item * Numeric values (cell units), e.g. C<24>

=item * Percentage strings, e.g. C<'60%'> (relative to parent available size)

=back

=head2 Layer

Container/group node. Does not draw anything, only offsets children by C<-x/-y>.

=head2 Text

Renders one text run.

Options:

=over 4

=item * C<-text> (string or coderef)

=item * C<-material> (semantic material key, default C<DEFAULT>)

=item * C<-justify> (passed to renderer; e.g. C<left>, C<center>, C<right>)

=back

=head2 Rect

Renders a filled rectangle using space glyphs with style.

Options:

=over 4

=item * C<-width>, C<-height>

=item * C<-fg>, C<-bg>, C<-attrs>

=back

=head2 VBox and HBox

Auto-layout containers.

Options:

=over 4

=item * C<-gap> (default 0)

Spacing between adjacent child nodes.

=item * C<-width>, C<-height> (optional)

Container box size. If omitted, natural content size is used.

=item * C<-align>

Convenience alignment applied to main and cross axes.

=item * C<-main_align>, C<-cross_align>

Axis-specific alignment override.

=back

Accepted alignment keywords:

    left up right down center

Keyword mapping is axis-aware:

=over 4

=item * Horizontal axis: C<left/up> => start, C<right/down> => end

=item * Vertical axis: C<up/left> => start, C<down/right> => end

=item * C<center> => centered

=back

=head2 BBox

Bordered container. Draws a border and renders children inside a one-cell inset.

Options:

=over 4

=item * C<-material> (fill material key, default C<DEFAULT>)

=item * C<-border_material> (border material key, default C<DEFAULT>)

=item * C<-width>, C<-height>

Optional outer size, minimum 2x2.

=item * C<-align>, C<-h_align>, C<-v_align>

Content alignment inside the inner area (after subtracting border thickness).

=back

=head1 RUNTIME OBJECT

C<App { ... }> returns C<TML::Runtime::App> with:

=over 4

=item * C<state>

Returns mutable state hashref.

=item * C<quit>

Marks app for exit; C<update> returns false on following tick.

=item * C<skip_render>

Marks the next C<update> result as C<-1>, meaning this widget should skip
rendering for one frame.

=item * C<update($dt, @events)> and C<render($renderer)>

The widget lifecycle expected by C<GameLoop>. Return semantics for
C<update>: C<0> stop loop, C<-1> skip render for this widget this frame,
truthy values render normally.

=back

=head1 SEE ALSO

L<GameLoop>, L<Renderers>, L<Theme>, L<TerminalBorderStyle>

=cut
