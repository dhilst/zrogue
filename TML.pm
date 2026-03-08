package TML;
use v5.36;
use utf8;

use Carp;
use Exporter qw(import);

use lib ".";
use BorderMapper;
use Event;
use MaterialMapper;
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

sub _style_opts($app, $renderer, $node, $props) {
    my %style;
    for my $k (qw(fg bg attrs justify)) {
        my $v = _resolve($app, $renderer, $node, $props->{$k});
        $style{"-$k"} = $v if defined $v;
    }
    return %style;
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

    sub _new($class, $opts) {
        my $state = $opts->{state} // {};
        confess "state must be a hashref"
            unless ref($state) eq 'HASH';

        my $default_fg = exists $opts->{default_fg} ? $opts->{default_fg} : -1;
        my $default_bg = exists $opts->{default_bg} ? $opts->{default_bg} : -1;
        my $default_attrs = exists $opts->{default_attrs} ? $opts->{default_attrs} : -1;

        my $mapper = $opts->{material_mapper} // $opts->{mapper};
        if (!defined $mapper) {
            my $default_style = {
                -fg => $default_fg,
                -bg => $default_bg,
                -attrs => $default_attrs,
            };
            $mapper = MaterialMapper::from_callback(sub ($material) {
                return $default_style;
            });
        }
        confess "material_mapper must support style()"
            unless ref($mapper) && $mapper->can('style');

        my $border_mapper = $opts->{border_mapper};
        if (!defined $border_mapper) {
            $border_mapper = BorderMapper::from_callback(sub ($material) {
                state %styles = (
                    ASCII  => "+-+\n| |\n+-+",
                    SINGLE => "┌─┐\n│ │\n└─┘",
                );
                return $styles{$material} // $styles{SINGLE};
            });
        }
        confess "border_mapper must support style()"
            unless ref($border_mapper) && $border_mapper->can('style');

        return bless {
            mapper => $mapper,
            border_mapper => $border_mapper,
            root => undef,
            state => $state,
            on_key => [],
            on_update => [],
            quit => 0,
        }, $class;
    }

    sub mapper($self) { $self->{mapper} }
    sub border_mapper($self) { $self->{border_mapper} }
    sub state($self) { $self->{state} }

    sub quit($self) {
        $self->{quit} = 1;
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

    sub _children_extent($self, $renderer, $children) {
        my $max_col = 0;
        my $max_row = 0;

        for my $child (@$children) {
            my $props = $child->{props};
            my $cx = TML::_resolve_int($self, $renderer, $child, $props->{x}, 0);
            my $cy = TML::_resolve_int($self, $renderer, $child, $props->{y}, 0);
            my ($cw, $ch) = $self->_node_dimensions($renderer, $child);

            my $col_end = $cx + $cw;
            my $row_end = (-$cy) + $ch;
            $max_col = $col_end if $col_end > $max_col;
            $max_row = $row_end if $row_end > $max_row;
        }

        return ($max_col, $max_row);
    }

    sub _container_layout($self, $renderer, $node, $type) {
        my $props = $node->{props};
        my $gap = TML::_resolve_int($self, $renderer, $node, $props->{gap}, 0);
        $gap = 0 if $gap < 0;

        my @children = $node->{children}->@*;
        my @child_dims = map { [ $self->_node_dimensions($renderer, $_) ] } @children;

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

        my $box_w = exists $props->{width}
            ? TML::_resolve_int($self, $renderer, $node, $props->{width}, $natural_w)
            : $natural_w;
        my $box_h = exists $props->{height}
            ? TML::_resolve_int($self, $renderer, $node, $props->{height}, $natural_h)
            : $natural_h;
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

        return (\@placements, $box_w, $box_h);
    }

    sub _bbox_layout($self, $renderer, $node) {
        my $props = $node->{props};
        my ($content_w, $content_h) = $self->_children_extent($renderer, $node->{children});

        my $box_w = exists $props->{width}
            ? TML::_resolve_int($self, $renderer, $node, $props->{width}, $content_w + 2)
            : ($content_w + 2);
        my $box_h = exists $props->{height}
            ? TML::_resolve_int($self, $renderer, $node, $props->{height}, $content_h + 2)
            : ($content_h + 2);

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

        return ($box_w, $box_h, $content_x, $content_y);
    }

    sub _node_dimensions($self, $renderer, $node) {
        my $props = $node->{props};
        my $type = $node->{type};

        if ($type eq 'Rect') {
            my $w = TML::_resolve_int($self, $renderer, $node, $props->{width}, 0);
            my $h = TML::_resolve_int($self, $renderer, $node, $props->{height}, 0);
            $w = 0 if $w < 0;
            $h = 0 if $h < 0;
            return ($w, $h);
        }

        if ($type eq 'Text') {
            my $text = TML::_resolve($self, $renderer, $node, $props->{text} // '');
            my $w = length("$text");
            return ($w, 1);
        }

        if ($type eq 'VBox' || $type eq 'HBox') {
            my ($placements, $w, $h) = $self->_container_layout($renderer, $node, $type);
            return ($w, $h);
        }

        if ($type eq 'BBox') {
            my ($w, $h, $content_x, $content_y) = $self->_bbox_layout($renderer, $node);
            return ($w, $h);
        }

        my ($natural_w, $natural_h) = $self->_children_extent($renderer, $node->{children});
        my $w = exists $props->{width}
            ? TML::_resolve_int($self, $renderer, $node, $props->{width}, $natural_w)
            : $natural_w;
        my $h = exists $props->{height}
            ? TML::_resolve_int($self, $renderer, $node, $props->{height}, $natural_h)
            : $natural_h;
        $w = 0 if $w < 0;
        $h = 0 if $h < 0;
        return ($w, $h);
    }

    sub _render_rect($self, $renderer, $node, $local) {
        my $props = $node->{props};
        my $w = TML::_resolve_int($self, $renderer, $node, $props->{width}, 0);
        my $h = TML::_resolve_int($self, $renderer, $node, $props->{height}, 0);
        return if $w <= 0 || $h <= 0;

        my %style_props = (
            fg => $props->{fg},
            bg => $props->{bg},
            attrs => $props->{attrs},
        );
        my %is_cellwise = map {
            $_ => (ref($style_props{$_}) eq 'CODE' ? 1 : 0)
        } keys %style_props;
        my $cellwise = $is_cellwise{fg} || $is_cellwise{bg} || $is_cellwise{attrs};

        if (!$cellwise) {
            my %style;
            for my $k (qw(fg bg attrs)) {
                my $v = TML::_resolve($self, $renderer, $node, $style_props{$k});
                $style{"-$k"} = $v if defined $v;
            }
            for my $row (0 .. $h - 1) {
                my $row_pos = $local + Matrix3::Vec::from_xy(0, -$row);
                $renderer->render_text($row_pos, ' ' x $w, %style);
            }
            return;
        }

        my %const;
        for my $k (qw(fg bg attrs)) {
            next if $is_cellwise{$k};
            $const{$k} = TML::_resolve($self, $renderer, $node, $style_props{$k});
        }

        for my $row (0 .. $h - 1) {
            for my $col (0 .. $w - 1) {
                my %style;
                for my $k (qw(fg bg attrs)) {
                    my $v = $is_cellwise{$k}
                        ? $style_props{$k}->($self, $renderer, $node, $col, $row, $w, $h)
                        : $const{$k};
                    $style{"-$k"} = $v if defined $v;
                }
                my $cell_pos = $local + Matrix3::Vec::from_xy($col, -$row);
                $renderer->render_text($cell_pos, ' ', %style);
            }
        }
    }

    sub _render_bbox($self, $renderer, $node, $local) {
        my $props = $node->{props};
        my ($w, $h, $content_x, $content_y) = $self->_bbox_layout($renderer, $node);
        return if $w <= 0 || $h <= 0;

        my $border_name = TML::_resolve($self, $renderer, $node, $props->{border} // 'SINGLE');
        my $chars = $self->{border_mapper}->style($border_name);
        my ($tl, $tc, $tr) = $chars->[0]->@*;
        my ($ml, $mc, $mr) = $chars->[1]->@*;
        my ($bl, $bc, $br) = $chars->[2]->@*;

        my $material = TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
        my %style = $self->{mapper}->style($material)->%*;
        for my $k (qw(fg bg attrs)) {
            my $v = TML::_resolve($self, $renderer, $node, $props->{$k});
            $style{"-$k"} = $v if defined $v;
        }

        my $middle_len = $w > 2 ? ($w - 2) : 0;
        my $top = $tl . ($tc x $middle_len) . $tr;
        my $bottom = $bl . ($bc x $middle_len) . $br;
        $renderer->render_text($local, $top, %style);
        for my $row (1 .. $h - 2) {
            my $mid = $ml . ($mc x $middle_len) . $mr;
            my $mid_pos = $local + Matrix3::Vec::from_xy(0, -$row);
            $renderer->render_text($mid_pos, $mid, %style);
        }
        if ($h > 1) {
            my $bottom_pos = $local + Matrix3::Vec::from_xy(0, -($h - 1));
            $renderer->render_text($bottom_pos, $bottom, %style);
        }

        my $content_base = $local + Matrix3::Vec::from_xy($content_x, -$content_y);
        for my $child ($node->{children}->@*) {
            $self->_render_node($renderer, $child, $content_base);
        }
    }

    sub _render_node($self, $renderer, $node, $base) {
        my $props = $node->{props};
        my $x = TML::_resolve_int($self, $renderer, $node, $props->{x}, 0);
        my $y = TML::_resolve_int($self, $renderer, $node, $props->{y}, 0);
        my $local = $base + Matrix3::Vec::from_xy($x, $y);

        if ($node->{type} eq 'Rect') {
            $self->_render_rect($renderer, $node, $local);
        } elsif ($node->{type} eq 'Text') {
            my $text = TML::_resolve($self, $renderer, $node, $props->{text} // '');
            my %style = TML::_style_opts($self, $renderer, $node, $props);
            $renderer->render_text($local, "$text", %style);
        } elsif ($node->{type} eq 'VBox' || $node->{type} eq 'HBox') {
            my ($placements, $w, $h) = $self->_container_layout($renderer, $node, $node->{type});
            for my $placement (@$placements) {
                my $child_pos = $local + Matrix3::Vec::from_xy($placement->{x}, -$placement->{y});
                $self->_render_node($renderer, $placement->{child}, $child_pos);
            }
            return;
        } elsif ($node->{type} eq 'BBox') {
            $self->_render_bbox($renderer, $node, $local);
            return;
        }

        for my $child ($node->{children}->@*) {
            $self->_render_node($renderer, $child, $local);
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

        return $self->{quit} ? 0 : 1;
    }

    sub render($self, $renderer) {
        my $origin = Matrix3::Vec::from_xy(0, 0);
        for my $child ($self->{root}->{children}->@*) {
            $self->_render_node($renderer, $child, $origin);
        }
    }
}

1;
