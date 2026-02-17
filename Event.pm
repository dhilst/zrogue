package Event;
use v5.36;
use utf8;

use Class::Struct;;

package Event::Type {
    use constant {
        KEY_PRESS => 'KEY_PRESS',
    };
}

package Event::KeyCode {
    use constant {
        ENTER => 10,
        ESC   => 27,
    };
}

package Event::KeyPress {
    use Class::Struct;
    use overload
        '""' => \&to_str;

    struct
        char => '$',
        code => '$';

    sub to_str {
        my $self = shift;
        sprintf "KeyPress('%s', %02x)", $self->char, $self->code;
    }
}

use overload
    '""' => \&to_str;

struct
    type => '$',
    payload => '$';

# Constructors
sub key_press($key_code) {
    __PACKAGE__->new(
        type => Event::Type::KEY_PRESS,
        payload => Event::KeyPress->new(char => $key_code, code => ord($key_code)),
    );
}

# methods
sub to_str($self, @ignored) {
    sprintf "Event(%s, %s)", $self->type, $self->payload;
}

1;

__END__

=head1 NAME

Event

=head1 SYNOPSIS

    use Event;
    my $ev = Event::key_press("a");
    say $ev->type;

=head1 DESCRIPTION

Event defines a small event type system for input handling. It currently
supports key press events with a character and code.

=head1 TYPES

=over 4

=item Event::Type

Contains constants like C<KEY_PRESS>.

=item Event::KeyCode

Contains constants like C<ENTER> and C<ESC>.

=item Event::KeyPress

Payload type with C<char> and C<code>.

=back

=head1 CONSTRUCTORS

=over 4

=item key_press($char)

Builds a C<KEY_PRESS> event with C<char> and its ordinal C<code>.

=back
