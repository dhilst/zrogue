package ZTUI::IniFile;

use v5.36;
use Carp qw(confess);

sub new(%opts) {
    my $strict = exists($opts{-strict}) ? $opts{-strict} : 1;
    confess "-strict must be 0 or 1" unless $strict == 0 || $strict == 1;

    return bless {
        strict => $strict,
    }, __PACKAGE__;
}

sub parse($self, %opts) {
    my $source = $opts{-content};
    confess "missing -content" unless defined $source;

    my $result = {};
    my $section;

    my @lines = split /\n/, $source;
    for my $line_no (1 .. scalar @lines) {
        my $raw_line = $lines[$line_no - 1];
        $raw_line =~ s/\r\z//;

        my $line = _trim($raw_line);
        next if $line eq '';
        next if $line =~ /^\s*[#;]/;

        if ($line =~ /^\[\s*(.+?)\s*\]\z/) {
            $section = $1;
            $result->{$section} = {};
            next;
        }

        confess "Malformed ini line $line_no (missing section)" unless defined $section;

        my $eq = index $line, '=';
        confess "Malformed ini key/value on line $line_no" if $eq < 0;

        my $key = _trim(substr $line, 0, $eq);
        my $value = _trim(substr $line, $eq + 1);
        confess "Malformed ini key on line $line_no" if $key eq '';

        $result->{$section}{$key} = $value;
    }

    return $result;
}

sub parse_file($self, $path, %opts) {
    confess "missing path" unless defined $path;
    open my $fh, '<', $path or confess "Cannot open '$path': $!";
    local $/;
    my $content = <$fh>;
    close $fh;

    return $self->parse(-content => $content, %opts);
}

sub unparse($self, $data) {
    confess "data must be a hashref" unless defined $data && ref($data) eq 'HASH';

    my @lines;
    for my $section (sort keys $data->%*) {
        my $section_data = $data->{$section};
        confess "Section '$section' must be a hashref" unless ref($section_data) eq 'HASH';
        push @lines, "[$section]\n";
        for my $key (sort keys $section_data->%*) {
            my $value = $section_data->{$key};
            if (ref($value)) {
                if (ref($value) eq 'ARRAY') {
                    $value = join ', ', @$value;
                } else {
                    confess "Unsupported value type for '$section:$key'";
                }
            }
            push @lines, "$key=$value\n";
        }
        push @lines, "\n";
    }

    return join '', @lines;
}

sub validate($self, $data, %schema) {
    confess "data must be a hashref" unless defined $data && ref($data) eq 'HASH';
    confess "-sections must be an arrayref" if exists($schema{-sections}) && ref($schema{-sections}) ne 'ARRAY';

    my $strict_sections = exists($schema{-strict_sections}) ? $schema{-strict_sections} : $self->{strict};
    my $strict_keys = exists($schema{-strict_keys}) ? $schema{-strict_keys} : $self->{strict};

    my $sections = $schema{-sections} // [];

    for my $section_name (keys $data->%*) {
        my $section_data = $data->{$section_name};
        confess "Section '$section_name' must be a hashref" unless ref($section_data) eq 'HASH';

        my $spec = _find_section_spec($section_name, $sections);
        confess "Unknown section '$section_name'" if !defined $spec && $strict_sections;
        next unless defined $spec;

        my $keys = $spec->{keys};
        next unless defined $keys && ref($keys) eq 'HASH';

        for my $key (keys $section_data->%*) {
            my $validator = $keys->{$key};
            confess "Unknown key '$key' in section '$section_name'"
                if !exists($keys->{$key}) && $strict_keys;
            next unless exists $keys->{$key};

            next unless defined $validator;

            my $value = $section_data->{$key};
            if (ref($validator) eq 'CODE') {
                confess "Validation failed for '$section_name:$key'"
                    unless $validator->($value, $section_name, $key);
                next;
            }

            if (!ref($validator) && $validator eq 'int') {
                confess "Key '$key' in section '$section_name' must be an integer"
                    unless _looks_like_integer($value);
                next;
            }

            confess "Unknown validator type for '$section_name:$key'";
        }
    }

    return 1;
}

sub _find_section_spec($section_name, $specs) {
    for my $spec (@$specs) {
        if (exists($spec->{name})) {
            return $spec if $spec->{name} eq $section_name;
            next;
        }

        if (exists($spec->{prefix})) {
            return $spec if index($section_name, $spec->{prefix}) == 0;
            next;
        }

        if (exists($spec->{pattern}) && ref($spec->{pattern}) eq 'Regexp') {
            return $spec if $section_name =~ $spec->{pattern};
            next;
        }
    }

    return undef;
}

sub _looks_like_integer($value) {
    return 0 unless defined $value;
    return 1 if "$value" =~ /^\s*[+-]?\d+\s*$/;
    return 1 if "$value" =~ /^\s*0x[0-9A-Fa-f]+\s*$/;
    return 0;
}

sub _trim($text) {
    $text =~ s/^\s+//;
    $text =~ s/\s+\z//;
    return $text;
}

1;

__END__

=head1 NAME

IniFile

=head1 SYNOPSIS

    use ZTUI::IniFile;

    my $ini = ZTUI::IniFile::new();
    my $data = $ini->parse_file('theme.ini');

    $ini->validate($data,
        -sections => [
            { name => 'theme.metadata' },
            { prefix => 'material:', keys => { fg => 'int', bg => 'int', attrs => 'int' } },
        ],
    );

=head1 DESCRIPTION

Simple INI parsing/unparsing with strict validation hooks.

=head1 METHODS

=over 4

=item new(%opts)

Creates a parser with optional strictness for validation.

=item parse(%opts)

Parses INI text from C<-content>.

=item parse_file($path)

Reads and parses a file.

=item unparse($data)

Serializes parsed data back to INI text with deterministic ordering.

=item validate($data, %schema)

Validates parsed data against section/key schema contracts.

=back

=cut
