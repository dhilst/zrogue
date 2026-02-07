use v5.36;
use utf8;
use Test::More;

use lib '.';
use Renderers;

# ------------------------------------------------------------
# Initialization and Geometry
# ------------------------------------------------------------
subtest 'Basic initialization' => sub {
    my ($h, $w) = (10, 20);
    my $pb = Renderers::PackedBuffer2D::new("L4", $h, $w);

    isa_ok($pb, 'Renderers::PackedBuffer2D');
    is($pb->stride, 16, 'Stride correctly calculated for L4 (16 bytes)');
    is($pb->size, 200, 'Total cell count is H * W');
    is($pb->bytes, 3200, 'Total buffer size is size * stride');
    is(length($pb->buffer), 3200, 'Internal buffer length matches expectation');
};

# ------------------------------------------------------------
# Read/Write Integrity
# ------------------------------------------------------------
subtest 'Read after Write integrity' => sub {
    my $pb = Renderers::PackedBuffer2D::new("L4", 5, 5);
    
    # Define a test cell: Glyph=65 (A), FG=Red, BG=Black, Attr=Bold
    my @cell_data = (65, 0xFF0000, 0x000000, 1);
    
    $pb->set(2, 2, @cell_data); # Set middle of 5x5 grid
    
    my @retrieved = $pb->get(2, 2);
    is_deeply(\@retrieved, \@cell_data, 'Unpacked data matches original packed input');
    
    # Verify neighbors are still zero (no bleed/offset errors)
    my @neighbor = $pb->get(2, 1);
    is_deeply(\@neighbor, [0, 0, 0, 0], 'Neighboring cell remains untouched (offset logic sound)');
};

# ------------------------------------------------------------
# Reset and Memory Isolation
# ------------------------------------------------------------
subtest 'Reset and Buffer Isolation' => sub {
    my $pb = Renderers::PackedBuffer2D::new("L4", 2, 2);
    
    # Fill buffer with data
    $pb->set(0, 0, (1, 1, 1, 1));
    $pb->set(1, 1, (2, 2, 2, 2));
    
    $pb->reset();
    
    # Check all cells
    my $all_zero = 1;
    for (my $i = 0; $i < $pb->size; $i++) {
        my @data = $pb->get_1d($i);
        $all_zero = 0 if grep { $_ != 0 } @data;
    }
    
    ok($all_zero, 'All cells are zero after reset');
    is(length($pb->buffer), $pb->bytes, 'Buffer size preserved after reset');
    
    # Verify COW/Isolation: Write again and reset again
    $pb->set(0, 0, (9, 9, 9, 9));
    $pb->reset();
    is_deeply([$pb->get(0, 0)], [0, 0, 0, 0], 'Reset works multiple times (zbuffer is immutable)');
};

# ------------------------------------------------------------
# Binary Equality (eq)
# ------------------------------------------------------------
subtest 'Binary equality (eq) logic' => sub {
    my $pb = Renderers::PackedBuffer2D::new("L4", 3, 3);
    
    my @data = (65, 0xFF0000, 0x000000, 1);
    my $packed = pack("L4", @data);
    my $different = pack("L4", 65, 0xFF0000, 0x000000, 0); # Attribute is 0 instead of 1

    $pb->set(1, 1, @data);

    ok($pb->eq_packed(1, 1, $packed), 'eq returns true for identical packed content');
    ok(!$pb->eq_packed(1, 1, $different), 'eq returns false for different attributes (even if glyph/colors match)');
    ok(!$pb->eq_packed(0, 0, $packed), 'eq returns false against an empty/zeroed cell');
    
    # Verify that comparing against the zbuffer works for empty cells
    my $null_cell = pack("L4", 0, 0, 0, 0);
    ok($pb->eq_packed(0, 0, $null_cell), 'eq correctly identifies a zeroed cell using packed nulls');
};


done_testing;
