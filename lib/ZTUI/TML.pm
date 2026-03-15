package ZTUI::TML;
use v5.36;
use utf8;

use Carp;
use Exporter qw(import);

use ZTUI::Event;
use ZTUI::Matrix3;

our @EXPORT_OK = qw(
    App
    Layer
    VBox
    HBox
    BBox
    Rect
    Text
    InputRoot
    FocusScope
    Button
    Toggle
    TextField
    List
    FieldList
    TextViewport
    ButtonRow
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
    my $app = ZTUI::TML::Runtime::App->_new($opts);

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

sub InputRoot :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('InputRoot', $block, @args);
}

sub FocusScope :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('FocusScope', $block, @args);
}

sub Button :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('Button', $block, @args);
}

sub Toggle :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('Toggle', $block, @args);
}

sub TextField :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('TextField', $block, @args);
}

sub List :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('List', $block, @args);
}

sub FieldList :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('FieldList', $block, @args);
}

sub TextViewport :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('TextViewport', $block, @args);
}

sub ButtonRow :prototype(&;@) {
    my ($block, @args) = @_;
    _build_node('ButtonRow', $block, @args);
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

package ZTUI::TML::Runtime::App {
    use v5.36;
    use Carp;
    use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
    use POSIX qw(WNOHANG _exit);
    use Scalar::Util qw(refaddr);
    use Storable qw(nfreeze thaw);
    use Time::HiRes qw(time);

    sub _new($class, $opts) {
        my $state = $opts->{state} // {};
        confess "state must be a hashref"
            unless ref($state) eq 'HASH';

        my $setup_cb = $opts->{setup};
        confess "setup must be a coderef"
            if defined($setup_cb) && ref($setup_cb) ne 'CODE';

        my $action_cb = $opts->{action};
        confess "action must be a coderef"
            if defined($action_cb) && ref($action_cb) ne 'CODE';

        my $exit_cb = $opts->{exit};
        confess "exit must be a coderef"
            if defined($exit_cb) && ref($exit_cb) ne 'CODE';

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
            interactive_state => {
                focused_node_id => undef,
                active_root_id => undef,
            },
            lifecycle => {
                setup_cb => $setup_cb,
                action_cb => $action_cb,
                exit_cb => $exit_cb,
                setup_done => 0,
                exit_done => 0,
                runtime_info => undef,
                exit_result => undef,
                action => {
                    phase => 'idle',
                    requested_args => [],
                    started_at => undef,
                    finished_at => undef,
                    latest_progress => undef,
                    progress_log => [],
                    result => undef,
                    stdout => '',
                    stderr => '',
                    exit_code => undef,
                    pending_exit_code => undef,
                    runtime => undef,
                },
            },
        }, $class;
    }

    sub state($self) { $self->{state} }

    sub runtime_info($self) { $self->{lifecycle}{runtime_info} }

    sub action_phase($self) { $self->{lifecycle}{action}{phase} }

    sub action_is_running($self) { $self->action_phase eq 'running' ? 1 : 0 }

    sub action_latest_progress($self) { $self->{lifecycle}{action}{latest_progress} }

    sub action_progress_log($self) { $self->{lifecycle}{action}{progress_log} }

    sub action_result($self) { $self->{lifecycle}{action}{result} }

    sub action_stdout($self) { $self->{lifecycle}{action}{stdout} }

    sub action_stderr($self) { $self->{lifecycle}{action}{stderr} }

    sub action_exit_code($self) { $self->{lifecycle}{action}{exit_code} }

    sub _run_setup_callback($self, $runtime_info) {
        return $self->runtime_info if $self->{lifecycle}{setup_done};

        $runtime_info //= {};
        confess "runtime info must be a hashref"
            unless ref($runtime_info) eq 'HASH';

        $self->{lifecycle}{runtime_info} = $runtime_info;
        my $setup_cb = $self->{lifecycle}{setup_cb};
        $setup_cb->($self, $runtime_info) if defined $setup_cb;
        $self->{lifecycle}{setup_done} = 1;
        return $runtime_info;
    }

    sub _normalize_action_progress($self, $payload) {
        return { message => '' } unless defined $payload;
        return { message => "$payload" } unless ref($payload);
        confess "action progress payload must be a hashref or scalar"
            unless ref($payload) eq 'HASH';
        return { $payload->%* };
    }

    sub _set_nonblocking($self, $fh) {
        my $flags = fcntl($fh, F_GETFL, 0);
        confess "failed to read filehandle flags"
            unless defined $flags;
        confess "failed to set nonblocking mode"
            unless fcntl($fh, F_SETFL, $flags | O_NONBLOCK);
        return;
    }

    sub _write_action_message($self, $fh, $message) {
        my $payload = nfreeze($message);
        my $frame = pack('N', length($payload)) . $payload;
        my $offset = 0;
        while ($offset < length($frame)) {
            my $written = syswrite($fh, $frame, length($frame) - $offset, $offset);
            confess "failed to write action message"
                unless defined $written;
            $offset += $written;
        }
        return;
    }

    sub _slurp_nonblocking($self, $fh) {
        my $buffer = '';
        while (1) {
            my $read = sysread($fh, my $chunk, 4096);
            last unless defined $read;
            last if $read == 0;
            $buffer .= $chunk;
        }
        return $buffer;
    }

    sub _drain_action_messages($self, $runtime) {
        return [] unless defined $runtime;
        my $chunk = $self->_slurp_nonblocking($runtime->{control_read});
        $runtime->{control_buffer} .= $chunk if length $chunk;

        my $messages = [];
        while (length($runtime->{control_buffer}) >= 4) {
            my $len = unpack('N', substr($runtime->{control_buffer}, 0, 4));
            last if length($runtime->{control_buffer}) < 4 + $len;
            my $payload = substr($runtime->{control_buffer}, 4, $len);
            substr($runtime->{control_buffer}, 0, 4 + $len, '');
            push @$messages, thaw($payload);
        }

        return $messages;
    }

    sub _apply_action_message($self, $message) {
        return unless defined $message && ref($message) eq 'HASH';
        my $action = $self->{lifecycle}{action};
        my $type = $message->{type} // '';

        if ($type eq 'progress') {
            my $payload = $self->_normalize_action_progress($message->{payload});
            $action->{latest_progress} = $payload;
            push $action->{progress_log}->@*, $payload;
            return;
        }

        if ($type eq 'result') {
            $action->{result} = $message->{payload};
            return;
        }

        if ($type eq 'complete') {
            $action->{pending_exit_code} = $message->{exit_code};
            return;
        }

        return;
    }

    sub _finalize_action_runtime($self, $exit_code) {
        my $action = $self->{lifecycle}{action};
        my $runtime = delete $action->{runtime};
        return unless defined $runtime;

        $action->{exit_code} = $exit_code;
        $action->{finished_at} = time;
        $action->{phase} = $exit_code == 0 ? 'completed' : 'failed';

        if (!defined($action->{latest_progress}) && $action->{phase} eq 'completed') {
            $action->{latest_progress} = { message => 'action completed' };
        }

        $self->quit;
        return;
    }

    sub _pump_action_runtime($self) {
        my $action = $self->{lifecycle}{action};
        my $runtime = $action->{runtime};
        return unless defined $runtime;

        for my $message ($self->_drain_action_messages($runtime)->@*) {
            $self->_apply_action_message($message);
        }

        $action->{stdout} .= $self->_slurp_nonblocking($runtime->{stdout_read});
        $action->{stderr} .= $self->_slurp_nonblocking($runtime->{stderr_read});

        my $pid = $runtime->{pid};
        my $wait = waitpid($pid, WNOHANG);
        return if $wait == 0 && !defined $action->{pending_exit_code};

        my $exit_code = defined($action->{pending_exit_code})
            ? $action->{pending_exit_code}
            : ($wait > 0 ? ($? >> 8) : 255);
        $self->_finalize_action_runtime($exit_code);
        return;
    }

    sub start_action($self, @args) {
        my $action_cb = $self->{lifecycle}{action_cb};
        confess "start_action requires an -action callback"
            unless defined $action_cb;
        return 0 if $self->action_is_running;

        pipe(my $control_read, my $control_write)
            or confess "failed to create action control pipe";
        pipe(my $stdout_read, my $stdout_write)
            or confess "failed to create action stdout pipe";
        pipe(my $stderr_read, my $stderr_write)
            or confess "failed to create action stderr pipe";

        my $pid = fork();
        confess "failed to fork action worker"
            unless defined $pid;

        if ($pid == 0) {
            close $control_read;
            close $stdout_read;
            close $stderr_read;

            open(STDOUT, '>&', $stdout_write)
                or confess "failed to redirect action stdout";
            open(STDERR, '>&', $stderr_write)
                or confess "failed to redirect action stderr";

            my $report = sub ($payload) {
                my $normalized = $self->_normalize_action_progress($payload);
                $self->_write_action_message($control_write, {
                    type => 'progress',
                    payload => $normalized,
                });
                return;
            };

            my $result = $action_cb->($self, $report, @args);
            $self->_write_action_message($control_write, {
                type => 'result',
                payload => $result,
            });
            $self->_write_action_message($control_write, {
                type => 'complete',
                exit_code => 0,
            });
            close $control_write;
            close $stdout_write;
            close $stderr_write;
            _exit(0);
        }

        close $control_write;
        close $stdout_write;
        close $stderr_write;

        $self->_set_nonblocking($control_read);
        $self->_set_nonblocking($stdout_read);
        $self->_set_nonblocking($stderr_read);

        $self->{lifecycle}{action} = {
            phase => 'running',
            requested_args => [@args],
            started_at => time,
            finished_at => undef,
            latest_progress => { message => 'action started' },
            progress_log => [{ message => 'action started' }],
            result => undef,
            stdout => '',
            stderr => '',
            exit_code => undef,
            pending_exit_code => undef,
            runtime => {
                pid => $pid,
                control_read => $control_read,
                stdout_read => $stdout_read,
                stderr_read => $stderr_read,
                control_buffer => '',
            },
        };

        return 1;
    }

    sub _abort_running_action($self) {
        my $runtime = $self->{lifecycle}{action}{runtime};
        return unless defined $runtime;
        kill 'TERM', $runtime->{pid};
        waitpid($runtime->{pid}, 0);
        $self->_finalize_action_runtime(143);
        $self->{lifecycle}{action}{phase} = 'aborted';
        return;
    }

    sub _run_exit_callback($self) {
        return $self->{lifecycle}{exit_result} if $self->{lifecycle}{exit_done};

        my $exit_cb = $self->{lifecycle}{exit_cb};
        my $result = {
            action_phase => $self->action_phase,
            action_result => $self->action_result,
            action_stdout => $self->action_stdout,
            action_stderr => $self->action_stderr,
            action_exit_code => $self->action_exit_code,
            runtime_info => $self->runtime_info,
            state => $self->state,
        };

        $self->{lifecycle}{exit_result} = defined($exit_cb)
            ? $exit_cb->($self, $result)
            : $result;
        $self->{lifecycle}{exit_done} = 1;
        return $self->{lifecycle}{exit_result};
    }

    sub run($self, $theme) {
        confess "run requires a theme"
            unless defined $theme;

        require ZTUI::GameLoop;
        my $loop = ZTUI::GameLoop::new($theme, $self);
        my $runtime_info = {
            theme => $theme,
            cols => $loop->{term}->cols,
            rows => $loop->{term}->rows,
            frame_interval => $loop->{frame_interval},
        };
        $self->_run_setup_callback($runtime_info);
        $loop->run();
        $self->_abort_running_action if $self->action_is_running;
        $loop->shutdown();
        return $self->_run_exit_callback();
    }

    sub _interactive_node_id($self, $node) {
        return $self->_cache_node_id($node);
    }

    sub _interactive_root_nodes($self, $node = undef, $roots = undef) {
        $node //= $self->{root};
        $roots //= [];
        return $roots unless defined $node;

        if (($node->{type} // '') eq 'InputRoot') {
            push @$roots, $node;
        }

        for my $child ($node->{children}->@*) {
            $self->_interactive_root_nodes($child, $roots);
        }

        return $roots;
    }

    sub _is_focusable_node($self, $node) {
        my $type = $node->{type} // '';
        return 1 if $type eq 'Button';
        return 1 if $type eq 'Toggle';
        return 1 if $type eq 'TextField';
        return 1 if $type eq 'List';
        return 1 if $type eq 'FieldList';
        return 1 if $type eq 'TextViewport';
        return 0;
    }

    sub _is_disabled_node($self, $node) {
        my $disabled = ZTUI::TML::_resolve($self, undef, $node, $node->{props}{disabled} // 0);
        return $disabled ? 1 : 0;
    }

    sub _collect_focusable_nodes($self, $node, $accum = undef) {
        $accum //= [];
        return $accum unless defined $node;

        if ($self->_is_focusable_node($node) && !$self->_is_disabled_node($node)) {
            push @$accum, $node;
        }

        for my $child ($node->{children}->@*) {
            $self->_collect_focusable_nodes($child, $accum);
        }

        return $accum;
    }

    sub _interactive_context($self) {
        my $roots = $self->_interactive_root_nodes();
        return undef unless @$roots;

        my $state = $self->{interactive_state};
        my $root = $roots->[0];
        my $root_id = $self->_interactive_node_id($root);
        my $focusables = $self->_collect_focusable_nodes($root);
        my %focusable_by_id = map { ($self->_interactive_node_id($_) => $_) } @$focusables;
        my (%node_by_id, %parent_by_id, %children_by_id);
        $self->_interactive_tree_walk($root, undef, \%node_by_id, \%parent_by_id, \%children_by_id);

        my $focused_id = $state->{focused_node_id};
        if (!defined($focused_id) || !exists($focusable_by_id{$focused_id})) {
            $focused_id = @$focusables ? $self->_interactive_node_id($focusables->[0]) : undef;
            $state->{focused_node_id} = $focused_id;
        }

        $state->{active_root_id} = $root_id;
        my $focused = defined($focused_id) ? $focusable_by_id{$focused_id} : undef;

        return {
            root => $root,
            root_id => $root_id,
            focusables => $focusables,
            focusable_by_id => \%focusable_by_id,
            focused => $focused,
            focused_id => $focused_id,
            node_by_id => \%node_by_id,
            parent_by_id => \%parent_by_id,
            children_by_id => \%children_by_id,
        };
    }

    sub _interactive_tree_walk($self, $node, $parent, $node_by_id, $parent_by_id, $children_by_id) {
        return unless defined $node;
        my $node_id = $self->_interactive_node_id($node);
        $node_by_id->{$node_id} = $node;
        $parent_by_id->{$node_id} = defined($parent) ? $self->_interactive_node_id($parent) : undef;
        $children_by_id->{$node_id} = [ $node->{children}->@* ];
        for my $child ($node->{children}->@*) {
            $self->_interactive_tree_walk($child, $node, $node_by_id, $parent_by_id, $children_by_id);
        }
        return;
    }

    sub _is_navigation_container($self, $node) {
        return 0 unless defined $node;
        my $type = $node->{type} // '';
        return 1 if $type eq 'InputRoot';
        return 1 if $type eq 'FocusScope';
        return 1 if $type eq 'VBox';
        return 1 if $type eq 'HBox';
        return 1 if $type eq 'ButtonRow';
        return 1 if $type eq 'BBox';
        return 1 if $type eq 'Layer';
        return 0;
    }

    sub _is_composite_focus_widget($self, $node) {
        return 0 unless defined $node;
        my $type = $node->{type} // '';
        return 1 if $type eq 'List';
        return 1 if $type eq 'FieldList';
        return 1 if $type eq 'TextViewport';
        return 0;
    }

    sub _interactive_parent($self, $ctx, $node) {
        return undef unless defined $ctx && defined $node;
        my $node_id = $self->_interactive_node_id($node);
        my $parent_id = $ctx->{parent_by_id}{$node_id};
        return undef unless defined $parent_id;
        return $ctx->{node_by_id}{$parent_id};
    }

    sub _node_is_descendant_of($self, $ctx, $node, $ancestor) {
        return 0 unless defined $ctx && defined $node && defined $ancestor;
        my $cursor = $node;
        while (defined $cursor) {
            return 1 if $self->_interactive_node_id($cursor) == $self->_interactive_node_id($ancestor);
            $cursor = $self->_interactive_parent($ctx, $cursor);
        }
        return 0;
    }

    sub _first_focusable_descendant($self, $ctx, $node) {
        return undef unless defined $ctx && defined $node;
        return $node if $self->_is_focusable_node($node) && !$self->_is_disabled_node($node);
        for my $child ($ctx->{children_by_id}{ $self->_interactive_node_id($node) }->@*) {
            my $found = $self->_first_focusable_descendant($ctx, $child);
            return $found if defined $found;
        }
        return undef;
    }

    sub _container_focus_branches($self, $ctx, $container) {
        return [] unless defined $ctx && defined $container;
        my $branches = [];
        for my $child ($ctx->{children_by_id}{ $self->_interactive_node_id($container) }->@*) {
            my $target = $self->_first_focusable_descendant($ctx, $child);
            next unless defined $target;
            push @$branches, {
                child => $child,
                target => $target,
            };
        }
        return $branches;
    }

    sub _nearest_branch_container($self, $ctx, $node) {
        return undef unless defined $ctx && defined $node;
        my $cursor = $self->_interactive_parent($ctx, $node);
        while (defined $cursor) {
            if ($self->_is_navigation_container($cursor)) {
                my $branches = $self->_container_focus_branches($ctx, $cursor);
                if (@$branches > 1) {
                    for my $branch (@$branches) {
                        return $cursor
                            if $self->_node_is_descendant_of($ctx, $node, $branch->{child});
                    }
                }
            }
            $cursor = $self->_interactive_parent($ctx, $cursor);
        }
        return undef;
    }

    sub _navigation_owner_for_focus($self, $ctx, $node) {
        return undef unless defined $ctx && defined $node;
        my $container = $self->_nearest_branch_container($ctx, $node);
        return $container if $self->_container_has_exit_branch($ctx, $container);
        return $node if $self->_is_composite_focus_widget($node);
        return $container;
    }

    sub _container_has_exit_branch($self, $ctx, $container) {
        return 0 unless defined $ctx && defined $container;
        my $parent = $self->_interactive_parent($ctx, $container);
        while (defined $parent && !$self->_is_navigation_container($parent)) {
            $parent = $self->_interactive_parent($ctx, $parent);
        }
        return 0 unless defined $parent;

        my $branches = $self->_container_focus_branches($ctx, $parent);
        return 0 unless @$branches > 1;

        for my $branch (@$branches) {
            return 1 if $self->_node_is_descendant_of($ctx, $container, $branch->{child});
        }

        return 0;
    }

    sub _move_focus_within_container($self, $ctx, $container, $current_node, $direction) {
        return 0 unless defined $ctx && defined $container && defined $current_node;
        my $branches = $self->_container_focus_branches($ctx, $container);
        return 0 unless @$branches > 1;

        my $current_idx;
        for my $idx (0 .. $#$branches) {
            if ($self->_node_is_descendant_of($ctx, $current_node, $branches->[$idx]{child})) {
                $current_idx = $idx;
                last;
            }
        }
        return 0 unless defined $current_idx;

        my $next_idx = $current_idx + $direction;
        $next_idx = $#$branches if $next_idx < 0;
        $next_idx = 0 if $next_idx > $#$branches;
        my $target = $branches->[$next_idx]{target};
        return 0 unless defined $target;

        $self->{interactive_state}{focused_node_id} = $self->_interactive_node_id($target);
        return 1;
    }

    sub _jump_focus_out_of_container($self, $ctx, $current_container, $direction) {
        return 0 unless defined $ctx && defined $current_container;
        my $parent = $self->_interactive_parent($ctx, $current_container);
        while (defined $parent && !$self->_is_navigation_container($parent)) {
            $parent = $self->_interactive_parent($ctx, $parent);
        }
        return 0 unless defined $parent;

        my $branches = $self->_container_focus_branches($ctx, $parent);
        return 0 unless @$branches > 1;

        my $current_idx;
        for my $idx (0 .. $#$branches) {
            if ($self->_node_is_descendant_of($ctx, $current_container, $branches->[$idx]{child})) {
                $current_idx = $idx;
                last;
            }
        }
        return 0 unless defined $current_idx;

        my $next_idx = $current_idx + $direction;
        $next_idx = $#$branches if $next_idx < 0;
        $next_idx = 0 if $next_idx > $#$branches;
        my $target = $branches->[$next_idx]{target};
        return 0 unless defined $target;

        $self->{interactive_state}{focused_node_id} = $self->_interactive_node_id($target);
        return 1;
    }

    sub _focus_keymap_defaults($self) {
        return {
            next => ['j'],
            prev => ['k'],
            exit_next => ['J'],
            exit_prev => ['K'],
        };
    }

    sub _keymap_tokens($self, $value, $label) {
        if (!defined $value) {
            return [];
        }
        if (!ref($value)) {
            return [$value];
        }
        confess "$label keymap entry must be a string or array ref"
            unless ref($value) eq 'ARRAY';
        for my $token ($value->@*) {
            confess "$label keymap token must be a string"
                if !defined($token) || ref($token);
        }
        return [ $value->@* ];
    }

    sub _focus_keymap_for($self, $ctx, $container) {
        my $defaults = $self->_focus_keymap_defaults();
        my %map = map { ($_ => [ $defaults->{$_}->@* ]) } keys $defaults->%*;

        my @sources;
        push @sources, $ctx->{root} if defined $ctx && defined $ctx->{root};
        push @sources, $container if defined $container;

        for my $source (@sources) {
            next unless defined $source;
            my $keymap = $source->{props}{keymap};
            next unless defined $keymap;
            confess "keymap must be a hashref"
                unless ref($keymap) eq 'HASH';
            for my $action (keys $keymap->%*) {
                next unless exists $map{$action};
                $map{$action} = $self->_keymap_tokens($keymap->{$action}, $action);
            }
        }

        return \%map;
    }

    sub _char_matches_action($self, $ctx, $container, $char, $action) {
        my $keymap = $self->_focus_keymap_for($ctx, $container);
        return scalar grep { $_ eq $char } $keymap->{$action}->@*;
    }

    sub _dispatch_navigation_action($self, $ctx, $focused, $char) {
        return 0 unless defined $ctx && defined $focused;

        my $container = $self->_nearest_branch_container($ctx, $focused);
        if (defined $container) {
            return $self->_move_focus_within_container($ctx, $container, $focused, 1)
                if $self->_char_matches_action($ctx, $container, $char, 'next');
            return $self->_move_focus_within_container($ctx, $container, $focused, -1)
                if $self->_char_matches_action($ctx, $container, $char, 'prev');
        }

        my $owner = $self->_navigation_owner_for_focus($ctx, $focused);
        if (defined $owner) {
            return $self->_jump_focus_out_of_container($ctx, $owner, 1)
                if $self->_char_matches_action($ctx, $owner, $char, 'exit_next');
            return $self->_jump_focus_out_of_container($ctx, $owner, -1)
                if $self->_char_matches_action($ctx, $owner, $char, 'exit_prev');
        }

        return 0;
    }

    sub _widget_label($self, $renderer, $node, $default = '') {
        return ZTUI::TML::_resolve($self, $renderer, $node, $node->{props}{label} // $default);
    }

    sub _arrayref_prop($self, $node, $prop_name, $label) {
        my $value = $node->{props}{$prop_name};
        confess "$label requires -$prop_name array ref"
            unless defined($value) && ref($value) eq 'ARRAY';
        return $value;
    }

    sub _scalarref_prop($self, $node, $prop_name, $label) {
        my $value = $node->{props}{$prop_name};
        confess "$label requires -$prop_name scalar ref"
            unless defined($value) && ref($value) eq 'SCALAR';
        return $value;
    }

    sub _button_text($self, $renderer, $node) {
        my $label = $self->_widget_label($renderer, $node, '');
        return '[' . $label . ']';
    }

    sub _toggle_value_ref($self, $node) {
        my $value_ref = $node->{props}{value_ref};
        confess "Toggle requires -value_ref scalar ref"
            unless defined($value_ref) && ref($value_ref) eq 'SCALAR';
        return $value_ref;
    }

    sub _textfield_value_ref($self, $node) {
        my $value_ref = $node->{props}{value_ref};
        confess "TextField requires -value_ref scalar ref"
            unless defined($value_ref) && ref($value_ref) eq 'SCALAR';
        return $value_ref;
    }

    sub _toggle_text($self, $renderer, $node) {
        my $value_ref = $self->_toggle_value_ref($node);
        my $label = $self->_widget_label($renderer, $node, '');
        my $mark = $$value_ref ? 'x' : ' ';
        return '[' . $mark . '] ' . $label;
    }

    sub _textfield_inner_width($self, $renderer, $node, $parent_w = undef) {
        my $props = $node->{props};
        my $text = $self->_textfield_display_value($node);
        my $natural = length($text);
        $natural = 1 if $natural < 1;

        my $width = exists($props->{width})
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width')
            : $natural;
        $width = 1 if !defined($width) || $width < 1;
        return $width;
    }

    sub _textfield_active_ref($self, $node) {
        my $state_key = '_textfield_active_ref';
        $node->{props}{$state_key} = \($node->{props}{_textfield_active_value} //= 0)
            unless exists $node->{props}{$state_key};
        my $active_ref = $node->{props}{$state_key};
        confess "TextField internal active state must be a scalar ref"
            unless ref($active_ref) eq 'SCALAR';
        return $active_ref;
    }

    sub _textfield_buffer_ref($self, $node) {
        my $state_key = '_textfield_buffer_ref';
        $node->{props}{$state_key} = \($node->{props}{_textfield_buffer_value} //= '')
            unless exists $node->{props}{$state_key};
        my $buffer_ref = $node->{props}{$state_key};
        confess "TextField internal buffer state must be a scalar ref"
            unless ref($buffer_ref) eq 'SCALAR';
        return $buffer_ref;
    }

    sub _textfield_validate($self, $node) {
        my $validator = $node->{props}{validate};
        return undef unless defined $validator;
        my $type = ref($validator);
        confess "TextField -validate must be a coderef or regex"
            unless $type eq 'CODE' || $type eq 'Regexp';
        return $validator;
    }

    sub _textfield_is_valid($self, $node, $candidate) {
        my $validator = $self->_textfield_validate($node);
        return 1 unless defined $validator;

        return $validator->($self, undef, $node, $candidate)
            if ref($validator) eq 'CODE';
        return $candidate =~ $validator ? 1 : 0;
    }

    sub _textfield_invalid($self, $node, $candidate) {
        my $cb = $node->{props}{on_invalid};
        return unless defined $cb;
        confess "TextField -on_invalid must be a coderef"
            unless ref($cb) eq 'CODE';
        $cb->($self, $node, $candidate);
        return;
    }

    sub _textfield_is_active($self, $node) {
        my $active_ref = $self->_textfield_active_ref($node);
        return $$active_ref ? 1 : 0;
    }

    sub _textfield_display_value($self, $node) {
        if ($self->_textfield_is_active($node)) {
            my $buffer_ref = $self->_textfield_buffer_ref($node);
            return defined($$buffer_ref) ? "$$buffer_ref" : '';
        }

        my $value_ref = $self->_textfield_value_ref($node);
        return defined($$value_ref) ? "$$value_ref" : '';
    }

    sub _textfield_begin_edit($self, $node) {
        $self->_textfield_validate($node);
        my $active_ref = $self->_textfield_active_ref($node);
        my $buffer_ref = $self->_textfield_buffer_ref($node);
        my $value_ref = $self->_textfield_value_ref($node);
        $$buffer_ref = defined($$value_ref) ? "$$value_ref" : '';
        $$active_ref = 1;
        return 1;
    }

    sub _textfield_commit($self, $node) {
        my $active_ref = $self->_textfield_active_ref($node);
        my $buffer_ref = $self->_textfield_buffer_ref($node);
        my $value_ref = $self->_textfield_value_ref($node);
        $$value_ref = defined($$buffer_ref) ? "$$buffer_ref" : '';
        $$active_ref = 0;

        my $change_cb = $node->{props}{on_change};
        if (defined $change_cb) {
            confess "TextField -on_change must be a coderef"
                unless ref($change_cb) eq 'CODE';
            $change_cb->($self, $node, $$value_ref);
        }

        my $submit_cb = $node->{props}{on_submit};
        if (defined $submit_cb) {
            confess "TextField -on_submit must be a coderef"
                unless ref($submit_cb) eq 'CODE';
            $submit_cb->($self, $node, $$value_ref);
        }

        return 1;
    }

    sub _textfield_cancel($self, $node) {
        my $active_ref = $self->_textfield_active_ref($node);
        my $buffer_ref = $self->_textfield_buffer_ref($node);
        my $value_ref = $self->_textfield_value_ref($node);
        $$buffer_ref = defined($$value_ref) ? "$$value_ref" : '';
        $$active_ref = 0;

        my $cancel_cb = $node->{props}{on_cancel};
        if (defined $cancel_cb) {
            confess "TextField -on_cancel must be a coderef"
                unless ref($cancel_cb) eq 'CODE';
            $cancel_cb->($self, $node, $$value_ref);
        }

        return 1;
    }

    sub _textfield_text($self, $renderer, $node, $parent_w = undef) {
        my $text = $self->_textfield_display_value($node);
        my $width = $self->_textfield_inner_width($renderer, $node, $parent_w);
        my $cursor_pos = length($text);
        $cursor_pos = $width - 1 if $cursor_pos >= $width;
        my $show_cursor = ZTUI::TML::_resolve($self, $renderer, $node, $node->{props}{focused} // 0)
            && $self->_textfield_is_active($node);

        my $visible = substr($text, 0, $width);
        $visible .= ' ' x ($width - length($visible)) if length($visible) < $width;

        if ($show_cursor) {
            substr($visible, $cursor_pos, 1, '_');
        }

        return '[' . $visible . ']';
    }

    sub _list_items($self, $renderer, $node) {
        my $items_ref = $self->_arrayref_prop($node, 'items_ref', 'List');
        my @items = map {
            if (!ref($_)) {
                +{ label => "$_", value => "$_" };
            } elsif (ref($_) eq 'HASH') {
                confess "List item hash requires label"
                    unless exists $_->{label};
                +{
                    label => "$_->{label}",
                    value => exists($_->{value}) ? $_->{value} : "$_->{label}",
                };
            } else {
                confess "List items must be scalars or hashrefs";
            }
        } @$items_ref;
        return \@items;
    }

    sub _list_selected_index_ref($self, $node) {
        return $self->_scalarref_prop($node, 'selected_index_ref', 'List');
    }

    sub _list_window_height($self, $renderer, $node, $parent_h = undef) {
        my $props = $node->{props};
        my $height = exists($props->{height})
            ? $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height')
            : 1;
        $height = 1 if !defined($height) || $height < 1;
        return $height;
    }

    sub _list_width($self, $renderer, $node, $parent_w = undef) {
        my $items = $self->_list_items($renderer, $node);
        my $natural = 0;
        for my $item (@$items) {
            my $w = 2 + length($item->{label});
            $natural = $w if $w > $natural;
        }
        $natural = 2 if $natural < 2;

        my $props = $node->{props};
        my $width = exists($props->{width})
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width')
            : $natural;
        $width = 2 if !defined($width) || $width < 2;
        return $width;
    }

    sub _list_normalize_selection($self, $renderer, $node) {
        my $items = $self->_list_items($renderer, $node);
        my $selected_ref = $self->_list_selected_index_ref($node);
        my $count = scalar @$items;
        $$selected_ref = 0 unless defined $$selected_ref;
        $$selected_ref = 0 if $$selected_ref < 0;
        $$selected_ref = $count - 1 if $count > 0 && $$selected_ref > $count - 1;
        $$selected_ref = 0 if $count == 0;
        return ($items, $selected_ref);
    }

    sub _list_scroll_ref($self, $node) {
        my $scroll_ref = $node->{props}{scroll_ref};
        if (!defined $scroll_ref) {
            my $state_key = '_list_scroll_ref';
            $node->{props}{$state_key} = \($node->{props}{_list_scroll_value} //= 0)
                unless exists $node->{props}{$state_key};
            $scroll_ref = $node->{props}{$state_key};
        }
        confess "List -scroll_ref must be a scalar ref"
            unless ref($scroll_ref) eq 'SCALAR';
        return $scroll_ref;
    }

    sub _list_visible_rows($self, $renderer, $node, $parent_w = undef, $parent_h = undef) {
        my ($items, $selected_ref) = $self->_list_normalize_selection($renderer, $node);
        my $scroll_ref = $self->_list_scroll_ref($node);
        my $height = $self->_list_window_height($renderer, $node, $parent_h);
        my $width = $self->_list_width($renderer, $node, $parent_w);
        my $count = scalar @$items;

        $$scroll_ref = 0 unless defined $$scroll_ref;
        $$scroll_ref = 0 if $$scroll_ref < 0;
        $$scroll_ref = $$selected_ref if $$selected_ref < $$scroll_ref;
        $$scroll_ref = $$selected_ref - $height + 1 if $$selected_ref >= $$scroll_ref + $height;
        my $max_scroll = $count > $height ? $count - $height : 0;
        $$scroll_ref = $max_scroll if $$scroll_ref > $max_scroll;

        my @rows;
        for my $row_idx (0 .. $height - 1) {
            my $item_idx = $$scroll_ref + $row_idx;
            my $text = ' ' x $width;
            my $selected = 0;
            if ($item_idx < $count) {
                my $label = $items->[$item_idx]{label};
                my $prefix = $item_idx == $$selected_ref ? '> ' : '  ';
                $selected = $item_idx == $$selected_ref ? 1 : 0;
                my $line = $prefix . $label;
                $line = substr($line, 0, $width);
                $line .= ' ' x ($width - length($line)) if length($line) < $width;
                $text = $line;
            }
            push @rows, {
                text => $text,
                selected => $selected,
                item_idx => $item_idx,
            };
        }

        return (\@rows, $width, $height);
    }

    sub _viewport_lines($self, $renderer, $node, $parent_w = undef) {
        my $props = $node->{props};
        if (exists $props->{lines_ref}) {
            my $lines_ref = $self->_arrayref_prop($node, 'lines_ref', 'TextViewport');
            return [ map { defined($_) ? "$_" : '' } @$lines_ref ];
        }
        my $text = ZTUI::TML::_resolve($self, $renderer, $node, $props->{text} // '');
        return [ split /\n/, "$text", -1 ];
    }

    sub _viewport_scroll_ref($self, $node) {
        my $scroll_ref = $node->{props}{scroll_ref};
        if (!defined $scroll_ref) {
            my $state_key = '_viewport_scroll_ref';
            $node->{props}{$state_key} = \($node->{props}{_viewport_scroll_value} //= 0)
                unless exists $node->{props}{$state_key};
            $scroll_ref = $node->{props}{$state_key};
        }
        confess "TextViewport -scroll_ref must be a scalar ref"
            unless ref($scroll_ref) eq 'SCALAR';
        return $scroll_ref;
    }

    sub _viewport_width($self, $renderer, $node, $parent_w = undef) {
        my $lines = $self->_viewport_lines($renderer, $node, $parent_w);
        my $natural = 1;
        for my $line (@$lines) {
            my $w = length($line);
            $natural = $w if $w > $natural;
        }
        my $props = $node->{props};
        my $width = exists($props->{width})
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width')
            : $natural;
        $width = 1 if !defined($width) || $width < 1;
        return $width;
    }

    sub _viewport_height($self, $renderer, $node, $parent_h = undef) {
        my $props = $node->{props};
        my $height = exists($props->{height})
            ? $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height')
            : 1;
        $height = 1 if !defined($height) || $height < 1;
        return $height;
    }

    sub _viewport_visible_lines($self, $renderer, $node, $parent_w = undef, $parent_h = undef) {
        my $lines = $self->_viewport_lines($renderer, $node, $parent_w);
        my $scroll_ref = $self->_viewport_scroll_ref($node);
        my $width = $self->_viewport_width($renderer, $node, $parent_w);
        my $height = $self->_viewport_height($renderer, $node, $parent_h);
        my $count = scalar @$lines;

        $$scroll_ref = 0 unless defined $$scroll_ref;
        $$scroll_ref = 0 if $$scroll_ref < 0;
        my $max_scroll = $count > $height ? $count - $height : 0;
        $$scroll_ref = $max_scroll if $$scroll_ref > $max_scroll;

        my @visible;
        for my $idx (0 .. $height - 1) {
            my $line_idx = $$scroll_ref + $idx;
            my $line = $line_idx < $count ? $lines->[$line_idx] : '';
            $line = substr($line, 0, $width);
            $line .= ' ' x ($width - length($line)) if length($line) < $width;
            push @visible, $line;
        }

        return (\@visible, $width, $height);
    }

    sub _fieldlist_specs($self, $node) {
        return $self->_arrayref_prop($node, 'fields', 'FieldList');
    }

    sub _fieldlist_selected_index_ref($self, $node) {
        my $selected_ref = $node->{props}{selected_index_ref};
        if (!defined $selected_ref) {
            my $state_key = '_fieldlist_selected_index_ref';
            $node->{props}{$state_key} = \($node->{props}{_fieldlist_selected_index_value} //= 0)
                unless exists $node->{props}{$state_key};
            $selected_ref = $node->{props}{$state_key};
        }
        confess "FieldList -selected_index_ref must be a scalar ref"
            unless ref($selected_ref) eq 'SCALAR';
        return $selected_ref;
    }

    sub _fieldlist_active_ref($self, $node) {
        my $state_key = '_fieldlist_active_ref';
        $node->{props}{$state_key} = \($node->{props}{_fieldlist_active_value} //= 0)
            unless exists $node->{props}{$state_key};
        my $active_ref = $node->{props}{$state_key};
        confess "FieldList internal active state must be a scalar ref"
            unless ref($active_ref) eq 'SCALAR';
        return $active_ref;
    }

    sub _fieldlist_buffer_ref($self, $node) {
        my $state_key = '_fieldlist_buffer_ref';
        $node->{props}{$state_key} = \($node->{props}{_fieldlist_buffer_value} //= '')
            unless exists $node->{props}{$state_key};
        my $buffer_ref = $node->{props}{$state_key};
        confess "FieldList internal buffer state must be a scalar ref"
            unless ref($buffer_ref) eq 'SCALAR';
        return $buffer_ref;
    }

    sub _fieldlist_is_active($self, $node) {
        my $active_ref = $self->_fieldlist_active_ref($node);
        return $$active_ref ? 1 : 0;
    }

    sub _fieldlist_normalize_selection($self, $node) {
        my $fields = $self->_fieldlist_specs($node);
        my $selected_ref = $self->_fieldlist_selected_index_ref($node);
        my $count = scalar @$fields;
        $$selected_ref = 0 unless defined $$selected_ref;
        $$selected_ref = 0 if $$selected_ref < 0;
        $$selected_ref = $count - 1 if $count > 0 && $$selected_ref > $count - 1;
        $$selected_ref = 0 if $count == 0;
        return ($fields, $selected_ref);
    }

    sub _fieldlist_selected_field($self, $node) {
        my ($fields, $selected_ref) = $self->_fieldlist_normalize_selection($node);
        return undef unless @$fields;
        return $fields->[$$selected_ref];
    }

    sub _fieldlist_begin_edit($self, $node) {
        my $field = $self->_fieldlist_selected_field($node);
        return 0 unless defined $field;
        return 0 unless ($field->{type} // 'text') eq 'text';

        my $value_ref = $field->{value_ref};
        confess "FieldList text field requires -value_ref scalar ref"
            unless defined($value_ref) && ref($value_ref) eq 'SCALAR';

        my $active_ref = $self->_fieldlist_active_ref($node);
        my $buffer_ref = $self->_fieldlist_buffer_ref($node);
        $$buffer_ref = defined($$value_ref) ? "$$value_ref" : '';
        $$active_ref = 1;
        return 1;
    }

    sub _fieldlist_commit($self, $node) {
        my $field = $self->_fieldlist_selected_field($node);
        return 0 unless defined $field;

        my $active_ref = $self->_fieldlist_active_ref($node);
        my $buffer_ref = $self->_fieldlist_buffer_ref($node);
        my $value_ref = $field->{value_ref};
        confess "FieldList text field requires -value_ref scalar ref"
            unless defined($value_ref) && ref($value_ref) eq 'SCALAR';

        $$value_ref = defined($$buffer_ref) ? "$$buffer_ref" : '';
        $$active_ref = 0;
        return 1;
    }

    sub _fieldlist_cancel($self, $node) {
        my $field = $self->_fieldlist_selected_field($node);
        return 0 unless defined $field;

        my $active_ref = $self->_fieldlist_active_ref($node);
        my $buffer_ref = $self->_fieldlist_buffer_ref($node);
        my $value_ref = $field->{value_ref};
        confess "FieldList text field requires -value_ref scalar ref"
            unless defined($value_ref) && ref($value_ref) eq 'SCALAR';

        $$buffer_ref = defined($$value_ref) ? "$$value_ref" : '';
        $$active_ref = 0;
        return 1;
    }

    sub _fieldlist_toggle_selected($self, $node) {
        my $field = $self->_fieldlist_selected_field($node);
        return 0 unless defined $field;
        return 0 unless ($field->{type} // 'text') eq 'toggle';

        my $value_ref = $field->{value_ref};
        confess "FieldList toggle field requires -value_ref scalar ref"
            unless defined($value_ref) && ref($value_ref) eq 'SCALAR';
        $$value_ref = $$value_ref ? 0 : 1;
        return 1;
    }

    sub _fieldlist_row_specs($self, $renderer, $node, $parent_w = undef, $parent_h = undef) {
        my ($fields, $selected_ref) = $self->_fieldlist_normalize_selection($node);
        my $focused = ZTUI::TML::_resolve($self, $renderer, $node, $node->{props}{focused} // 0);
        my $active = $self->_fieldlist_is_active($node);
        my $buffer_ref = $self->_fieldlist_buffer_ref($node);
        my $label_w = 0;
        for my $field (@$fields) {
            confess "FieldList field specs must be hashrefs"
                unless ref($field) eq 'HASH';
            confess "FieldList field spec requires label"
                unless exists $field->{label};
            my $w = length("$field->{label}");
            $label_w = $w if $w > $label_w;
        }

        my @rows;
        my $body_w = 0;
        for my $idx (0 .. $#$fields) {
            my $field = $fields->[$idx];
            my $type = $field->{type} // 'text';
            my $value_ref = $field->{value_ref};
            my $editor;
            my $selected = $idx == $$selected_ref ? 1 : 0;

            if ($type eq 'text') {
                confess "FieldList text field requires -value_ref scalar ref"
                    unless defined($value_ref) && ref($value_ref) eq 'SCALAR';
                my $editor_w = defined($field->{width}) ? int($field->{width}) : 12;
                $editor_w = 1 if $editor_w < 1;
                my $value = $selected && $active
                    ? (defined($$buffer_ref) ? "$$buffer_ref" : '')
                    : (defined($$value_ref) ? "$$value_ref" : '');
                my $visible = substr($value, 0, $editor_w);
                $visible .= ' ' x ($editor_w - length($visible)) if length($visible) < $editor_w;
                if ($selected && $active) {
                    my $cursor_pos = length($value);
                    $cursor_pos = $editor_w - 1 if $cursor_pos >= $editor_w;
                    substr($visible, $cursor_pos, 1, '_');
                }
                $editor = '[' . $visible . ']';
            } elsif ($type eq 'toggle') {
                confess "FieldList toggle field requires -value_ref scalar ref"
                    unless defined($value_ref) && ref($value_ref) eq 'SCALAR';
                my $mark = $$value_ref ? 'x' : ' ';
                $editor = '[' . $mark . ']';
            } else {
                confess "FieldList field type must be text or toggle";
            }

            my $label = "$field->{label}";
            my $prefix = $selected ? '> ' : '  ';
            $prefix = '* ' if $selected && $focused && $active;
            my $line = sprintf("%s%-*s : %s", $prefix, $label_w, $label, $editor);
            $body_w = length($line) if length($line) > $body_w;
            push @rows, {
                text => $line,
                selected => $selected,
                active => ($selected && $active) ? 1 : 0,
            };
        }

        my $props = $node->{props};
        my $width = exists($props->{width})
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width')
            : $body_w;
        $width = $body_w if !defined($width) || $width < $body_w;

        my $height = exists($props->{height})
            ? $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height')
            : scalar(@rows);
        $height = scalar(@rows) if !defined($height) || $height < scalar(@rows);

        for my $row (@rows) {
            my $line = substr($row->{text}, 0, $width);
            $line .= ' ' x ($width - length($line)) if length($line) < $width;
            $row->{text} = $line;
        }

        return (\@rows, $width, $height);
    }

    sub _widget_material($self, $renderer, $node) {
        my $focused = ZTUI::TML::_resolve($self, $renderer, $node, $node->{props}{focused} // 0);
        my $disabled = $self->_is_disabled_node($node);
        my $props = $node->{props};
        return ZTUI::TML::_resolve($self, $renderer, $node, $props->{disabled_material})
            if $disabled && exists $props->{disabled_material};
        return ZTUI::TML::_resolve($self, $renderer, $node, $props->{active_material})
            if ($node->{type} // '') eq 'TextField' && $self->_textfield_is_active($node) && exists $props->{active_material};
        return ZTUI::TML::_resolve($self, $renderer, $node, $props->{focused_material})
            if $focused && exists $props->{focused_material};
        return ZTUI::TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
    }

    sub _widget_focus_overlay($self, $node, $ctx) {
        return 0 unless defined $ctx && defined $ctx->{focused};
        return $self->_interactive_node_id($ctx->{focused}) == $self->_interactive_node_id($node) ? 1 : 0;
    }

    sub _dispatch_button($self, $node) {
        my $cb = $node->{props}{on_press};
        if (defined $cb) {
            confess "Button -on_press must be a coderef"
                unless ref($cb) eq 'CODE';
            $cb->($self, $node);
        }
        return 1;
    }

    sub _dispatch_toggle($self, $node) {
        my $value_ref = $self->_toggle_value_ref($node);
        $$value_ref = $$value_ref ? 0 : 1;
        my $cb = $node->{props}{on_change};
        if (defined $cb) {
            confess "Toggle -on_change must be a coderef"
                unless ref($cb) eq 'CODE';
            $cb->($self, $node, $$value_ref);
        }
        return 1;
    }

    sub _dispatch_textfield($self, $event, $node) {
        my $char = $event->payload->char;
        my $active = $self->_textfield_is_active($node);

        if (!$active) {
            return $self->_textfield_begin_edit($node) if $char eq "\n";
            return 1 if $char eq "\e";
            return 0;
        }

        my $buffer_ref = $self->_textfield_buffer_ref($node);
        $$buffer_ref = '' unless defined $$buffer_ref;

        if ($char eq "\e") {
            return $self->_textfield_cancel($node);
        }
        if ($char eq "\n") {
            if ($self->_textfield_is_valid($node, $$buffer_ref)) {
                return $self->_textfield_commit($node);
            }
            $self->_textfield_invalid($node, $$buffer_ref);
            return 1;
        }
        if ($char eq "\x7f" || $char eq "\b") {
            substr($$buffer_ref, -1, 1, '') if length($$buffer_ref);
        } else {
            my $max_len = $node->{props}{max_length};
            if (defined $max_len) {
                confess "TextField -max_length must be numeric"
                    unless !ref($max_len) && $max_len =~ /^\d+$/;
                return 1 if length($$buffer_ref) >= int($max_len);
            }
            $$buffer_ref .= $char;
        }

        return 1;
    }

    sub _dispatch_fieldlist($self, $event, $focused) {
        my ($fields, $selected_ref) = $self->_fieldlist_normalize_selection($focused);
        my $char = $event->payload->char;
        my $active = $self->_fieldlist_is_active($focused);

        if ($active) {
            my $field = $self->_fieldlist_selected_field($focused);
            return 0 unless defined $field;

            if ($char eq "\n") {
                return $self->_fieldlist_commit($focused);
            }
            if ($char eq "\e") {
                return $self->_fieldlist_cancel($focused);
            }
            if (($field->{type} // 'text') eq 'text') {
                my $buffer_ref = $self->_fieldlist_buffer_ref($focused);
                $$buffer_ref = '' unless defined $$buffer_ref;
                if ($char eq "\x7f" || $char eq "\b") {
                    substr($$buffer_ref, -1, 1, '') if length($$buffer_ref);
                    return 1;
                }
                my $max_len = $field->{width};
                if (defined $max_len) {
                    confess "FieldList text field width must be numeric"
                        unless !ref($max_len) && $max_len =~ /^\d+$/;
                    return 1 if length($$buffer_ref) >= int($max_len);
                }
                $$buffer_ref .= $char;
                return 1;
            }
        }

        if ($char eq 'j') {
            $$selected_ref++ if $$selected_ref < $#$fields;
            return 1;
        }
        if ($char eq 'k') {
            $$selected_ref-- if $$selected_ref > 0;
            return 1;
        }
        if ($char eq "\n") {
            my $field = $self->_fieldlist_selected_field($focused);
            return 0 unless defined $field;
            return $self->_fieldlist_begin_edit($focused)
                if ($field->{type} // 'text') eq 'text';
            return $self->_fieldlist_toggle_selected($focused)
                if ($field->{type} // 'text') eq 'toggle';
        }
        if ($char eq ' ') {
            my $field = $self->_fieldlist_selected_field($focused);
            return 0 unless defined $field;
            return $self->_fieldlist_toggle_selected($focused)
                if ($field->{type} // 'text') eq 'toggle';
            return 0;
        }
        if ($char eq "\e") {
            return 1;
        }

        return 0;
    }

    sub _dispatch_interactive_event($self, $event) {
        return 0 unless $event->type eq ZTUI::Event::Type::KEY_PRESS;

        my $ctx = $self->_interactive_context();
        return 0 unless defined $ctx;

        my $focused = $ctx->{focused};
        return 0 unless defined $focused;
        my $char = $event->payload->char;

        my $type = $focused->{type} // '';
        if ($type eq 'List') {
            my ($items, $selected_ref) = $self->_list_normalize_selection(undef, $focused);
            my $char = $event->payload->char;
            if ($char eq 'j') {
                $$selected_ref++ if $$selected_ref < $#$items;
                return 1;
            }
            if ($char eq 'k') {
                $$selected_ref-- if $$selected_ref > 0;
                return 1;
            }
            if ($char eq "\n" || $char eq ' ') {
                my $cb = $focused->{props}{on_activate};
                if (defined $cb) {
                    confess "List -on_activate must be a coderef"
                        unless ref($cb) eq 'CODE';
                    my $items_now = $self->_list_items(undef, $focused);
                    my $item = @$items_now ? $items_now->[$$selected_ref] : undef;
                    $cb->($self, $focused, $$selected_ref, $item);
                }
                return 1;
            }
        }
        if ($type eq 'TextViewport') {
            my $scroll_ref = $self->_viewport_scroll_ref($focused);
            my $lines = $self->_viewport_lines(undef, $focused);
            my $height = $self->_viewport_height(undef, $focused, undef);
            my $max_scroll = @$lines > $height ? @$lines - $height : 0;
            my $char = $event->payload->char;
            if ($char eq 'j') {
                if ($$scroll_ref < $max_scroll) {
                    $$scroll_ref++;
                    return 1;
                }
            }
            elsif ($char eq 'k') {
                if ($$scroll_ref > 0) {
                    $$scroll_ref--;
                    return 1;
                }
            }
            elsif ($char eq 'f') {
                if ($$scroll_ref < $max_scroll) {
                    $$scroll_ref += $height;
                    $$scroll_ref = $max_scroll if $$scroll_ref > $max_scroll;
                    return 1;
                }
            }
            elsif ($char eq 'b') {
                if ($$scroll_ref > 0) {
                    $$scroll_ref -= $height;
                    $$scroll_ref = 0 if $$scroll_ref < 0;
                    return 1;
                }
            }
        }
        if ($type eq 'Button') {
            return $self->_dispatch_button($focused)
                if $char eq "\n" || $char eq ' ';
        }
        if ($type eq 'Toggle') {
            return $self->_dispatch_toggle($focused)
                if $char eq "\n" || $char eq ' ';
        }
        if ($type eq 'TextField') {
            my $handled = $self->_dispatch_textfield($event, $focused);
            return $handled if $handled;
        }
        if ($type eq 'FieldList') {
            my $handled = $self->_dispatch_fieldlist($event, $focused);
            return $handled if $handled;
        }
        return $self->_dispatch_navigation_action($ctx, $focused, $char);
    }

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
            my $cx = ZTUI::TML::_resolve_int($self, $renderer, $child, $props->{x}, 0);
            my $cy = ZTUI::TML::_resolve_int($self, $renderer, $child, $props->{y}, 0);
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
            ? ZTUI::TML::_resolve($self, $renderer, $node, $value)
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

    sub _node_margins($self, $renderer, $node) {
        my $props = $node->{props} // {};
        my ($default_left, $default_top, $default_right, $default_bottom) =
            ($node->{type} // '') eq 'Text'
            ? (0, 0, 0, 0)
            : (1, 0, 1, 1);

        my $margin = exists $props->{margin}
            ? ZTUI::TML::_resolve_int($self, $renderer, $node, $props->{margin}, 0)
            : undef;
        my $margin_x = exists $props->{margin_x}
            ? ZTUI::TML::_resolve_int($self, $renderer, $node, $props->{margin_x}, defined($margin) ? $margin : 0)
            : undef;
        my $margin_y = exists $props->{margin_y}
            ? ZTUI::TML::_resolve_int($self, $renderer, $node, $props->{margin_y}, defined($margin) ? $margin : 0)
            : undef;

        my $left = defined($margin_x) ? $margin_x : defined($margin) ? $margin : $default_left;
        my $right = defined($margin_x) ? $margin_x : defined($margin) ? $margin : $default_right;
        my $top = defined($margin_y) ? $margin_y : defined($margin) ? $margin : $default_top;
        my $bottom = defined($margin_y) ? $margin_y : defined($margin) ? $margin : $default_bottom;

        $left = 0 if $left < 0;
        $top = 0 if $top < 0;
        $right = 0 if $right < 0;
        $bottom = 0 if $bottom < 0;
        return ($left, $top, $right, $bottom);
    }

    sub _node_inner_parent_space($self, $renderer, $node, $parent_w = undef, $parent_h = undef) {
        my ($left, $top, $right, $bottom) = $self->_node_margins($renderer, $node);
        my $inner_w = $parent_w;
        my $inner_h = $parent_h;

        if (defined $inner_w) {
            $inner_w -= $left + $right;
            $inner_w = 0 if $inner_w < 0;
        }
        if (defined $inner_h) {
            $inner_h -= $top + $bottom;
            $inner_h = 0 if $inner_h < 0;
        }

        return ($inner_w, $inner_h);
    }

    sub _text_overflow($self, $renderer, $node) {
        my $overflow = ZTUI::TML::_resolve($self, $renderer, $node, $node->{props}{overflow} // 'wrap');
        $overflow = lc($overflow // 'wrap');
        confess "text overflow must be wrap or clip"
            unless $overflow eq 'wrap' || $overflow eq 'clip';
        return $overflow;
    }

    sub _text_wrap_width($self, $renderer, $node, $parent_w = undef) {
        my $props = $node->{props};
        my $width = exists $props->{width}
            ? $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width')
            : $parent_w;
        return undef unless defined $width;
        $width = 0 if $width < 0;
        return $width;
    }

    sub _text_lines($self, $renderer, $node, $parent_w = undef) {
        my $props = $node->{props};
        my $text = ZTUI::TML::_resolve($self, $renderer, $node, $props->{text} // '');
        my $string = "$text";
        my $overflow = $self->_text_overflow($renderer, $node);
        my $wrap_width = $self->_text_wrap_width($renderer, $node, $parent_w);

        my @lines;
        for my $segment (split /\n/, $string, -1) {
            if (!defined($wrap_width)) {
                push @lines, $segment;
                next;
            }

            if ($wrap_width == 0) {
                push @lines, '';
                next;
            }

            if ($overflow eq 'clip') {
                push @lines, substr($segment, 0, $wrap_width);
                next;
            }

            if ($segment eq '') {
                push @lines, '';
                next;
            }

            while (length($segment) > $wrap_width) {
                push @lines, substr($segment, 0, $wrap_width, '');
            }
            push @lines, $segment;
        }

        @lines = ('') unless @lines;
        return \@lines;
    }

    sub _container_layout($self, $renderer, $node, $type, $parent_w = undef, $parent_h = undef) {
        my $cached = $self->_cache_fetch(
            'container_layout', $node, $parent_w, $parent_h, $type
        );
        return $cached->@* if defined $cached;

        my $props = $node->{props};
        my $default_gap = ($node->{type} // '') eq 'ButtonRow' ? 1 : 0;
        my $gap = ZTUI::TML::_resolve_int($self, $renderer, $node, $props->{gap}, $default_gap);
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
            my ($inner_parent_w, $inner_parent_h) = $self->_node_inner_parent_space(
                $renderer, $_, $child_parent_w, $child_parent_h
            );
            [ $self->_node_dimensions($renderer, $_, $inner_parent_w, $inner_parent_h) ]
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

        my $align = ZTUI::TML::_resolve($self, $renderer, $node, $props->{align});
        my $main_align = ZTUI::TML::_resolve($self, $renderer, $node,
            exists($props->{main_align}) ? $props->{main_align} : $align);
        my $cross_align = ZTUI::TML::_resolve($self, $renderer, $node,
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

        my $align = ZTUI::TML::_resolve($self, $renderer, $node, $props->{align});
        my $h_align = ZTUI::TML::_resolve($self, $renderer, $node,
            exists($props->{h_align}) ? $props->{h_align} : $align);
        my $v_align = ZTUI::TML::_resolve($self, $renderer, $node,
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
        my ($margin_left, $margin_top, $margin_right, $margin_bottom) = $self->_node_margins($renderer, $node);
        my $inner_parent_w = $parent_w;
        my $inner_parent_h = $parent_h;
        if (defined $inner_parent_w) {
            $inner_parent_w -= $margin_left + $margin_right;
            $inner_parent_w = 0 if $inner_parent_w < 0;
        }
        if (defined $inner_parent_h) {
            $inner_parent_h -= $margin_top + $margin_bottom;
            $inner_parent_h = 0 if $inner_parent_h < 0;
        }

        if ($type eq 'Rect') {
            my $w = $self->_resolve_length($renderer, $node, $props->{width}, $inner_parent_w, 'width', 0);
            my $h = $self->_resolve_length($renderer, $node, $props->{height}, $inner_parent_h, 'height', 0);
            $w = 0 if $w < 0;
            $h = 0 if $h < 0;
            my $result = [$w + $margin_left + $margin_right, $h + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'Text') {
            my $lines = $self->_text_lines($renderer, $node, $inner_parent_w);
            my $w = 0;
            for my $line (@$lines) {
                my $line_w = length($line);
                $w = $line_w if $line_w > $w;
            }
            my $result = [$w + $margin_left + $margin_right, scalar(@$lines) + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'Button') {
            my $text = $self->_button_text($renderer, $node);
            my $w = length($text);
            my $result = [$w + $margin_left + $margin_right, 1 + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'Toggle') {
            my $text = $self->_toggle_text($renderer, $node);
            my $w = length($text);
            my $result = [$w + $margin_left + $margin_right, 1 + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'TextField') {
            my $text = $self->_textfield_text($renderer, $node, $inner_parent_w);
            my $w = length($text);
            my $result = [$w + $margin_left + $margin_right, 1 + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'List') {
            my ($rows, $w, $h) = $self->_list_visible_rows($renderer, $node, $inner_parent_w, $inner_parent_h);
            my $result = [$w + $margin_left + $margin_right, $h + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'TextViewport') {
            my ($visible, $w, $h) = $self->_viewport_visible_lines($renderer, $node, $inner_parent_w, $inner_parent_h);
            my $result = [$w + $margin_left + $margin_right, $h + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'FieldList') {
            my ($rows, $w, $h) = $self->_fieldlist_row_specs($renderer, $node, $inner_parent_w, $inner_parent_h);
            my $result = [$w + $margin_left + $margin_right, $h + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'VBox' || $type eq 'HBox' || $type eq 'ButtonRow') {
            local $node->{props}{gap} = 1 if $type eq 'ButtonRow' && !exists $node->{props}{gap};
            my ($placements, $w, $h) = $self->_container_layout(
                $renderer, $node, $type eq 'ButtonRow' ? 'HBox' : $type, $inner_parent_w, $inner_parent_h
            );
            my $result = [$w + $margin_left + $margin_right, $h + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        if ($type eq 'BBox') {
            my ($w, $h, $content_x, $content_y) = $self->_bbox_layout(
                $renderer, $node, $inner_parent_w, $inner_parent_h
            );
            my $result = [$w + $margin_left + $margin_right, $h + $margin_top + $margin_bottom];
            $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
            return $result->@*;
        }

        my ($natural_w, $natural_h) = $self->_children_extent(
            $renderer,
            $node,
            $node->{children},
            $inner_parent_w,
            $inner_parent_h,
        );
        my $w = exists $props->{width}
            ? $self->_resolve_length($renderer, $node, $props->{width}, $inner_parent_w, 'width', $natural_w)
            : $natural_w;
        my $h = exists $props->{height}
            ? $self->_resolve_length($renderer, $node, $props->{height}, $inner_parent_h, 'height', $natural_h)
            : $natural_h;
        $w = 0 if $w < 0;
        $h = 0 if $h < 0;
        my $result = [$w + $margin_left + $margin_right, $h + $margin_top + $margin_bottom];
        $self->_cache_store('node_dimensions', $node, $parent_w, $parent_h, $result);
        return $result->@*;
    }

    sub _render_rect($self, $renderer, $node, $local, $parent_w = undef, $parent_h = undef) {
        my $props = $node->{props};
        my $w = $self->_resolve_length($renderer, $node, $props->{width}, $parent_w, 'width', 0);
        my $h = $self->_resolve_length($renderer, $node, $props->{height}, $parent_h, 'height', 0);
        return if $w <= 0 || $h <= 0;

        my $material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
        $renderer->render_rect($local, $w, $h, -material => $material);
    }

    sub _render_bbox($self, $renderer, $node, $local, $parent_w = undef, $parent_h = undef) {
        my $props = $node->{props};
        my ($w, $h, $content_x, $content_y) = $self->_bbox_layout(
            $renderer, $node, $parent_w, $parent_h
        );
        return if $w <= 0 || $h <= 0;

        my $material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
        my $border_material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{border_material} // 'DEFAULT');

        if ($w > 2 && $h > 2) {
            my $inner_origin = $local + ZTUI::Matrix3::Vec::from_xy(1, -1);
            $renderer->render_rect($inner_origin, $w - 2, $h - 2, -material => $material);
        }
        $renderer->render_border($local, $w, $h, -border_material => $border_material);

        my $content_base = $local + ZTUI::Matrix3::Vec::from_xy($content_x, -$content_y);
        my $inner_w = $w - 2;
        my $inner_h = $h - 2;
        for my $child ($node->{children}->@*) {
            $self->_render_node($renderer, $child, $content_base, $inner_w, $inner_h);
        }
    }

    sub _render_node($self, $renderer, $node, $base, $parent_w = undef, $parent_h = undef) {
        my $props = $node->{props};
        my $x = ZTUI::TML::_resolve_int($self, $renderer, $node, $props->{x}, 0);
        my $y = ZTUI::TML::_resolve_int($self, $renderer, $node, $props->{y}, 0);
        my $local = $base + ZTUI::Matrix3::Vec::from_xy($x, $y);
        my ($margin_left, $margin_top, $margin_right, $margin_bottom) = $self->_node_margins($renderer, $node);
        my $content_local = $local + ZTUI::Matrix3::Vec::from_xy($margin_left, -$margin_top);
        my $inner_parent_w = $parent_w;
        my $inner_parent_h = $parent_h;
        if (defined $inner_parent_w) {
            $inner_parent_w -= $margin_left + $margin_right;
            $inner_parent_w = 0 if $inner_parent_w < 0;
        }
        if (defined $inner_parent_h) {
            $inner_parent_h -= $margin_top + $margin_bottom;
            $inner_parent_h = 0 if $inner_parent_h < 0;
        }

        if ($node->{type} eq 'Rect') {
            $self->_render_rect($renderer, $node, $content_local, $inner_parent_w, $inner_parent_h);
        } elsif ($node->{type} eq 'Text') {
            my $lines = $self->_text_lines($renderer, $node, $inner_parent_w);
            my $material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
            my $justify = ZTUI::TML::_resolve($self, $renderer, $node, $props->{justify});
            my %opts = (-material => $material);
            $opts{-justify} = $justify if defined $justify;
            for my $row (0 .. $#$lines) {
                my $line_pos = $content_local + ZTUI::Matrix3::Vec::from_xy(0, -$row);
                $renderer->render_text($line_pos, $lines->[$row], %opts);
            }
        } elsif ($node->{type} eq 'Button') {
            my $ctx = $self->_interactive_context();
            local $node->{props}{focused} = $self->_widget_focus_overlay($node, $ctx);
            my $text = $self->_button_text($renderer, $node);
            my $material = $self->_widget_material($renderer, $node);
            $renderer->render_text($content_local, $text, -material => $material);
        } elsif ($node->{type} eq 'Toggle') {
            my $ctx = $self->_interactive_context();
            local $node->{props}{focused} = $self->_widget_focus_overlay($node, $ctx);
            my $text = $self->_toggle_text($renderer, $node);
            my $material = $self->_widget_material($renderer, $node);
            $renderer->render_text($content_local, $text, -material => $material);
        } elsif ($node->{type} eq 'TextField') {
            my $ctx = $self->_interactive_context();
            local $node->{props}{focused} = $self->_widget_focus_overlay($node, $ctx);
            my $text = $self->_textfield_text($renderer, $node, $inner_parent_w);
            my $material = $self->_widget_material($renderer, $node);
            $renderer->render_text($content_local, $text, -material => $material);
        } elsif ($node->{type} eq 'List') {
            my $ctx = $self->_interactive_context();
            my $focused = $self->_widget_focus_overlay($node, $ctx);
            my ($rows, $w, $h) = $self->_list_visible_rows($renderer, $node, $inner_parent_w, $inner_parent_h);
            my $base_material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
            my $selected_material = ZTUI::TML::_resolve($self, $renderer, $node,
                $focused
                ? ($props->{focused_material} // $props->{selected_material} // $base_material)
                : ($props->{selected_material} // $base_material)
            );
            for my $row (0 .. $#$rows) {
                my $line_pos = $content_local + ZTUI::Matrix3::Vec::from_xy(0, -$row);
                my $material = $rows->[$row]{selected} ? $selected_material : $base_material;
                $renderer->render_text($line_pos, $rows->[$row]{text}, -material => $material);
            }
        } elsif ($node->{type} eq 'TextViewport') {
            my $ctx = $self->_interactive_context();
            local $node->{props}{focused} = $self->_widget_focus_overlay($node, $ctx);
            my ($visible, $w, $h) = $self->_viewport_visible_lines($renderer, $node, $inner_parent_w, $inner_parent_h);
            my $material = $self->_widget_material($renderer, $node);
            for my $row (0 .. $#$visible) {
                my $line_pos = $content_local + ZTUI::Matrix3::Vec::from_xy(0, -$row);
                $renderer->render_text($line_pos, $visible->[$row], -material => $material);
            }
        } elsif ($node->{type} eq 'FieldList') {
            my $ctx = $self->_interactive_context();
            local $node->{props}{focused} = $self->_widget_focus_overlay($node, $ctx);
            my ($rows, $w, $h) = $self->_fieldlist_row_specs($renderer, $node, $inner_parent_w, $inner_parent_h);
            my $base_material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{material} // 'DEFAULT');
            my $focused_material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{focused_material} // $base_material);
            my $active_material = ZTUI::TML::_resolve($self, $renderer, $node, $props->{active_material} // $focused_material);
            for my $row (0 .. $#$rows) {
                my $line_pos = $content_local + ZTUI::Matrix3::Vec::from_xy(0, -$row);
                my $material = $rows->[$row]{active}
                    ? $active_material
                    : $rows->[$row]{selected}
                    ? $focused_material
                    : $base_material;
                $renderer->render_text($line_pos, $rows->[$row]{text}, -material => $material);
            }
        } elsif ($node->{type} eq 'VBox' || $node->{type} eq 'HBox' || $node->{type} eq 'ButtonRow') {
            my $container_type = $node->{type} eq 'ButtonRow' ? 'HBox' : $node->{type};
            local $node->{props}{gap} = 1 if $node->{type} eq 'ButtonRow' && !exists $node->{props}{gap};
            my ($placements, $w, $h) = $self->_container_layout(
                $renderer, $node, $container_type, $inner_parent_w, $inner_parent_h
            );
            for my $placement (@$placements) {
                my $child_pos = $content_local + ZTUI::Matrix3::Vec::from_xy($placement->{x}, -$placement->{y});
                $self->_render_node($renderer, $placement->{child}, $child_pos, $w, $h);
            }
            return;
        } elsif ($node->{type} eq 'BBox') {
            $self->_render_bbox($renderer, $node, $content_local, $inner_parent_w, $inner_parent_h);
            return;
        } elsif ($node->{type} eq 'InputRoot' || $node->{type} eq 'FocusScope') {
            for my $child ($node->{children}->@*) {
                $self->_render_node($renderer, $child, $content_local, $inner_parent_w, $inner_parent_h);
            }
            return;
        }

        my $child_parent_w = $inner_parent_w;
        my $child_parent_h = $inner_parent_h;
        if (exists $props->{width}) {
            $child_parent_w = $self->_resolve_length(
                $renderer, $node, $props->{width}, $inner_parent_w, 'width', $child_parent_w
            );
        }
        if (exists $props->{height}) {
            $child_parent_h = $self->_resolve_length(
                $renderer, $node, $props->{height}, $inner_parent_h, 'height', $child_parent_h
            );
        }

        for my $child ($node->{children}->@*) {
            $self->_render_node($renderer, $child, $content_local, $child_parent_w, $child_parent_h);
        }
    }

    sub update($self, $delta_time, @events) {
        $self->_pump_action_runtime();

        for my $cb ($self->{on_update}->@*) {
            $cb->($self, $delta_time, @events);
        }

        for my $event (@events) {
            next unless $event->type eq ZTUI::Event::Type::KEY_PRESS;
            my $handled = $self->_dispatch_interactive_event($event);
            next if $handled;
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
        my $origin = ZTUI::Matrix3::Vec::from_xy(0, 0);
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

    use ZTUI::TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);
    use InputTheme;

    my $ui = App {
        OnKey 'q' => sub ($app, $event) { $app->quit; };

        BBox {
            VBox {
                Text {} -text => 'Runnable TML app', -material => 'TITLE';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS',
                        -on_press => sub ($app, $node) { $app->start_action('demo') }, -margin => 0;
                } -margin => 0;
            } -gap => 1;
        } -x => -10, -y => 4,
          -border_material => 'FRAME',
          -material => 'PANEL';
    } -state => {},
      -action => sub ($app, $report, $label) {
          $report->({ message => "running $label" });
          return { label => $label };
      },
      -exit => sub ($app, $result) {
          print "phase=$result->{action_phase}\n";
          exit($result->{action_exit_code} // 0);
      };

    $ui->run(InputTheme::build_theme());

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

    App Layer VBox HBox BBox Rect Text InputRoot FocusScope Button Toggle TextField List FieldList TextViewport ButtonRow OnKey OnUpdate

=head1 APP

=head2 App BLOCK, %opts

Root builder. Returns a C<ZTUI::TML::Runtime::App> object. The returned object can
still be driven manually through C<GameLoop>, but it now also acts as a
runnable lifecycle root through C<< $app->run($theme) >>.

Supported app options:

=over 4

=item * C<-state> (hashref, default C<{}>)

Mutable state bag exposed as C<$app->state>.

=item * C<-setup> (coderef, optional)

Called once before the event loop starts. Signature:

    sub ($app, $runtime_info) { ... }

The runtime info hash contains terminal columns, rows, frame interval, and the
theme object passed to C<run>.

=item * C<-action> (coderef, optional)

Action worker callback started through C<< $app->start_action(@args) >>.
Signature:

    sub ($app, $report, @args) { ... }

The callback runs in a forked worker process. Use C<$report-E<gt>(...)> to send
progress updates back to the UI. Return a result value to make it available to
the C<-exit> callback.

=item * C<-exit> (coderef, optional)

Called after the terminal has been restored to text mode. Signature:

    sub ($app, $result) { ... }

The result hash includes the action phase, captured stdout/stderr, action exit
code, action result payload, runtime info, and app state.

=back

=head2 App Runtime Methods

=over 4

=item * C<< $app->run($theme) >>

Creates a C<GameLoop>, runs C<-setup>, drives the UI, restores terminal state,
and finally invokes C<-exit>.

=item * C<< $app->start_action(@args) >>

Starts the configured C<-action> callback unless another action is already
running.

=item * C<< $app->action_phase >>

Returns C<idle>, C<running>, C<completed>, C<failed>, or C<aborted>.

=item * C<< $app->action_is_running >>

Returns true while the worker process is active.

=item * C<< $app->action_latest_progress >>

Returns the most recent progress hash reported by the action worker.

=item * C<< $app->action_result >>

Returns the value returned by the worker callback after successful completion.

=item * C<< $app->action_stdout >> / C<< $app->action_stderr >>

Returns captured worker output that can be printed from the C<-exit> callback.

=item * C<< $app->runtime_info >>

Returns the setup-time runtime info hash after C<-setup> has executed.

=back

=head1 EVENTS

=head2 OnKey CHAR, CODEREF

Registers a key handler:

    OnKey 'q' => sub ($app, $event) { ... };

Called for C<ZTUI::Event::Type::KEY_PRESS> events whose character matches C<CHAR>.

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

=head2 TextField

Interactive single-line text input.

Options:

=over 4

=item * C<-value_ref> (scalar ref, required)

Underlying committed value.

=item * C<-validate> (regex or coderef, optional)

Validation is enforced only when committing with C<Enter>:

=over 4

=item * C<Regexp>

Candidate must match the regex.

=item * C<CODE>

Signature: C<sub ($app, $renderer, $node, $candidate) { ... }>.
The callback must return a truthy value when the candidate is valid.

=back

=item * C<-max_length> (numeric, optional)

Limits editable draft length in characters.

=item * C<-on_change> (coderef, optional)

Invoked after a successful commit with
C<sub ($app, $node, $new_value)>.

=item * C<-on_submit> (coderef, optional)

Invoked after a successful commit with
C<sub ($app, $node, $new_value)>.

=item * C<-on_cancel> (coderef, optional)

Invoked after cancel with C<sub ($app, $node, $old_value)>.

=item * C<-on_invalid> (coderef, optional)

Invoked when validation fails with
C<sub ($app, $node, $candidate)>.

=item * C<-focused_material>, C<-active_material>, C<-material>, C<-width>, C<-margin>

Style and layout props behave as for other interactive widgets.

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

C<App { ... }> returns C<ZTUI::TML::Runtime::App> with:

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
