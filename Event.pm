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
        ENTER => 10
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
