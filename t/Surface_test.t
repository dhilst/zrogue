use v5.36;
use Test::More;
use Test::Exception;

use lib ".";
use Matrix3;
use Geometry3;
use MaterialMapper;
use Quad;
use Surface;
use TerminalStyle;

sub vect($x, $y) { Matrix3::Vec::from_xy($x, $y) }

subtest 'render_text writes glyphs and styles' => sub {
    my $mat = MaterialMapper::from_callback(sub ($mat) { return {}; });
    my $surface = Surface::new(3, 5, -material => $mat);
    $surface->render_text(vect(1, 0), "Hi", -fg => 7);

    is_deeply([ $surface->buffer->get(1, 0) ], [ord('H'), 7, -1, -1], 'H cell');
    is_deeply([ $surface->buffer->get(2, 0) ], [ord('i'), 7, -1, -1], 'i cell');
};

subtest 'render_line uses material style' => sub {
    my $mat = MaterialMapper::from_callback(sub ($mat) {
        return TerminalStyle::new(-bg => 5) if $mat eq 'LINE';
    });
    my $surface = Surface::new(3, 5, -material => $mat);
    $surface->render_line(vect(0, 0), vect(2, 0), 'LINE');

    for my $col (0 .. 2) {
        is_deeply([ $surface->buffer->get($col, 0) ],
            [ord(' '), -1, 5, -1],
            "line cell $col");
    }
};

subtest 'render_quad fills rectangle' => sub {
    my $mat = MaterialMapper::from_callback(sub ($mat) {
        return TerminalStyle::new(-bg => 9) if $mat eq 'BG';
    });
    my $surface = Surface::new(3, 4, -material => $mat);
    my $quad = Quad::from_wh(2, 2, 'BG');
    $surface->render_quad(vect(0, 0), $quad);

    is_deeply([ $surface->buffer->get(0, 0) ], [ord(' '), -1, 9, -1], 'top-left');
    is_deeply([ $surface->buffer->get(1, 0) ], [ord(' '), -1, 9, -1], 'top-right');
    is_deeply([ $surface->buffer->get(0, 1) ], [ord(' '), -1, 9, -1], 'bottom-left');
    is_deeply([ $surface->buffer->get(1, 1) ], [ord(' '), -1, 9, -1], 'bottom-right');
};

subtest 'render_geometry draws text at positions' => sub {
    my $mat = MaterialMapper::from_callback(sub ($mat) { return {}; });
    my $surface = Surface::new(3, 3, -material => $mat);
    my $geo = Geometry3::from_str("AB\nCD");
    $surface->render_geometry(vect(0, 0), $geo);

    is_deeply([ $surface->buffer->get(0, 0) ], [ord('A'), -1, -1, -1], 'A');
    is_deeply([ $surface->buffer->get(1, 0) ], [ord('B'), -1, -1, -1], 'B');
    is_deeply([ $surface->buffer->get(0, 1) ], [ord('C'), -1, -1, -1], 'C');
    is_deeply([ $surface->buffer->get(1, 1) ], [ord('D'), -1, -1, -1], 'D');
};

subtest 'layers compose via successive draws' => sub {
    my $mat = MaterialMapper::from_callback(sub ($mat) {
        return TerminalStyle::new(-bg => 3) if $mat eq 'BG';
    });
    my $surface = Surface::new(2, 2, -material => $mat);
    my $quad = Quad::from_wh(2, 2, 'BG');
    $surface->render_quad(vect(0, 0), $quad);
    $surface->render_text(vect(0, 0), "Z", -fg => 1);

    is_deeply([ $surface->buffer->get(0, 0) ], [ord('Z'), 1, 3, -1], 'text over bg');
};

done_testing;
