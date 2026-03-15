use v5.36;
use Test::More;
use Test::Exception;
use File::Temp qw(tempfile);

use lib '.';
use IniFile;

sub write_tmp_ini($content) {
    my ($fh, $path) = tempfile(SUFFIX => '.ini', UNLINK => 1);
    print {$fh} $content;
    close $fh;
    return $path;
}

subtest 'constructor accepts strict flag' => sub {
    my $ini = IniFile::new();
    isa_ok($ini, 'IniFile', 'default constructor');

    my $strict = IniFile::new(-strict => 0);
    isa_ok($strict, 'IniFile', 'strict can be disabled');

    dies_ok { IniFile::new(-strict => 2) } 'invalid strict value dies';
};

subtest 'parse handles whitespace and comments' => sub {
    my $ini = IniFile::new();
    my $data = $ini->parse(
        -content => <<'INI'
# header comment
  [material:TITLE]
fg = 255
bg = 0x10
attrs =  7

; comment line
[ border:FRAME ]
fg=1
;
  glyphs = ┌,─,┐,│, ,│,└,─,┘

[theme.metadata]
name = demo
INI
    );

    is($data->{'material:TITLE'}->{fg}, '255', 'material fg parsed');
    is($data->{'material:TITLE'}->{bg}, '0x10', 'material bg parsed');
    is($data->{'material:TITLE'}->{attrs}, '7', 'material attrs parsed');
    is($data->{'border:FRAME'}->{fg}, '1', 'section whitespace trimmed');
    is($data->{'border:FRAME'}->{glyphs}, '┌,─,┐,│, ,│,└,─,┘', 'glyph string preserved');
    is($data->{'theme.metadata'}->{name}, 'demo', 'metadata parsed');
};

subtest 'parse_file loads filesystem file content' => sub {
    my $ini = IniFile::new();
    my $path = write_tmp_ini("[material:ONLY]\nfg=11\n");
    my $data = $ini->parse_file($path);

    is($data->{'material:ONLY'}->{fg}, '11', 'loaded from file');
};

subtest 'unparse is deterministic' => sub {
    my $ini = IniFile::new();
    my $source = <<'INI'
[border:FRAME]
fg=9
glyphs=┌,─,┐,│, ,│,└,─,┘

[material:TITLE]
bg=2
fg=1
INI
    my $data = $ini->parse(-content => $source);
    my $text = $ini->unparse($data);
    my $again = $ini->parse(-content => $text);
    is_deeply($again, $data, 'unparse then parse returns equivalent data');
};

subtest 'validation rejects malformed data in strict mode' => sub {
    my $ini = IniFile::new();
    my $data = $ini->parse(
        -content => <<'INI'
[material:TITLE]
fg = 255
unknown = 1

[bad:THING]
foo = bar
INI
    );

    dies_ok {
        $ini->validate(
            $data,
            -strict_sections => 1,
            -strict_keys => 1,
            -sections => [
                { name => 'theme.metadata' },
                { prefix => 'material:', keys => { fg => 'int' } },
            ],
        )
    } 'invalid section and key are rejected';

    lives_ok {
        $ini->validate(
            $data,
            -strict_sections => 0,
            -strict_keys => 0,
            -sections => [
                { name => 'theme.metadata' },
                { prefix => 'material:', keys => { fg => 'int' } },
            ],
        )
    } 'non-strict validation allows unknown data';

    my $bad_num = $ini->parse(
        -content => <<'INI'
[material:TITLE]
fg=bad
INI
    );
    dies_ok {
        $ini->validate(
            $bad_num,
            -sections => [ { prefix => 'material:', keys => { fg => 'int' } } ],
        )
    } 'integer validator rejects bad value';
};

done_testing;
