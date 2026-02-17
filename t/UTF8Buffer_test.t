use v5.36;
use Test::More;

use lib ".";
use UTF8Buffer;

sub bytes_for($codepoint) {
    my $char = pack("U", $codepoint);
    my $bytes = $char;
    utf8::encode($bytes);
    $bytes;
}

subtest 'ascii pass-through' => sub {
    my $buf = UTF8Buffer::new();
    my @out = $buf->push_bytes("abc");
    is_deeply(\@out, [qw(a b c)], 'ascii chars');
    is($buf->buf, '', 'buffer empty');
};

subtest 'two-byte sequence across chunks' => sub {
    my $buf = UTF8Buffer::new();
    my $bytes = bytes_for(0x00E9); # U+00E9
    my @out = $buf->push_bytes(substr($bytes, 0, 1));
    is_deeply(\@out, [], 'no output on partial');
    is(length($buf->buf), 1, 'buffer holds partial');
    @out = $buf->push_bytes(substr($bytes, 1, 1));
    is_deeply(\@out, [pack("U", 0x00E9)], 'decoded after completion');
    is($buf->buf, '', 'buffer empty');
};

subtest 'three-byte sequence' => sub {
    my $buf = UTF8Buffer::new();
    my $bytes = bytes_for(0x20AC); # U+20AC
    my @out = $buf->push_bytes($bytes);
    is_deeply(\@out, [pack("U", 0x20AC)], 'decoded 3-byte char');
};

subtest 'four-byte sequence' => sub {
    my $buf = UTF8Buffer::new();
    my $bytes = bytes_for(0x1F600); # U+1F600
    my @out = $buf->push_bytes($bytes);
    is_deeply(\@out, [pack("U", 0x1F600)], 'decoded 4-byte char');
};

subtest 'drops invalid leading continuation byte' => sub {
    my $buf = UTF8Buffer::new();
    my @out = $buf->push_bytes("\x80A");
    is_deeply(\@out, ['A'], 'invalid byte skipped');
    is($buf->buf, '', 'buffer empty');
};

done_testing;
