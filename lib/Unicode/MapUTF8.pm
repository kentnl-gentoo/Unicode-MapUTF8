package Unicode::MapUTF8;

use strict;
use Carp;
use Exporter;
use Unicode::String;
use Unicode::Map;
use Unicode::Map8;
use Jcode;

use vars qw ($VERSION @EXPORT @EXPORT_OK @EXPORT_TAGS @ISA);
use subs qw (utf8_supported_charset to_utf8 from_utf8);

BEGIN {
    @ISA         = qw(Exporter);
    @EXPORT      = qw ();
    @EXPORT_OK   = qw (utf8_supported_charset to_utf8 from_utf8);
    @EXPORT_TAGS = qw ();
    $VERSION     = "1.01";
}

# File level package globals
my $_Supported_Charsets;
my $_Charset_Names;

=head1 NAME

Unicode::MapUTF8 - Conversions to and from arbitrary character sets and UTF8

=head1 SYNOPSIS

 use Unicode::MapUTF8 qw(to_utf8 from_utf8 utf8_supported_charset);

 # Convert a string in 'ISO-8859-1' to 'UTF8'
 my $output = to_utf8({ -string => 'An example', -charset => 'ISO-8859-1' });

 # Convert a string in 'UTF8' encoding to encoding 'ISO-8859-1'
 my $other  = from_utf8({ -string => 'Other text', -charset => 'ISO-8859-1' });

 # List available character set encodings
 my @character_sets = utf8_supported_charset;

 # Convert between two arbitrary (but largely compatible) charset encodings
 # (SJIS to EUC-JP)
 my $utf8_string   = to_utf8({ -string =>$sjis_string, -charset => 'sjis'});
 my $euc_jp_string = from_utf8({ -string => $utf8_string, -charset => 'euc-jp' })

 # Verify that a specific character set is supported
 if (utf8_supported_charset('ISO-8859-1') {
     # Yes
 }

=head1 DESCRIPTION

Provides an adapter layer between core routines for converting
to and from UTF8 and other encodings. In essence, a way to give multiple
existing Unicode modules a single common interface so you don't have to know
the underlaying implementations to do simple UTF8 to-from other character set
encoding conversions. As such, it wraps the Unicode::String, Unicode::Map8,
Unicode::Map and Jcode modules in a standardized and simple API.

This also provides general character set conversion operation based on UTF8 - it is
possible to convert between any two compatible and supported character sets
via a simple two step chaining of conversions.

As with most things Perlish - if you give it a few big chunks of text to chew on
instead of lots of small ones it will handle many more characters per second.

By design, it can be easily extended to encompass any new charset encoding
conversion modules that arrive on the scene.

=head1 CHANGES

1.01 2000.10.02 - Fixed handling of empty strings and added more identification for error messages.

1.00 2000.09.29 - Pre-release version

=head1 FUNCTIONS

=cut

######################################################################

=over 4

=item C<utf8_supported_charset($charset_name);>


Returns true if the named charset is supported. false if it is not.

Example:

    if (! utf8_supported_charset('VISCII')) {
        # No support yet
    }

If called in a list context with no parameters, it will return
a list of all supported character set names.

Example:

    my @charsets = utf8_supported_charset;

=back

=cut

sub utf8_supported_charset {
    if ($#_ == -1 && wantarray) {
        my @charsets = sort keys %$_Supported_Charsets;
        return @charsets;
    }
    my $charset = shift;
    if (not defined $charset) {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::utf8_supported_charset() - no character set specified\n");
    }

    my $results = exists ($_Charset_Names->{lc($charset)});
    return $results;
}

######################################################################

=over 4

=item C<to_utf8({ -string => $string, -charset => $source_charset });>


Returns the string converted to UTF8 from the specified source charset.

=back

=cut

sub to_utf8 {
    my @parm_list = @_;
    my $parms  = {};
    if (($#parm_list > 0) && (($#parm_list % 2) == 1)) {
        $parms = { @parm_list };
    } elsif ($#parm_list == 0) {
        $parms = $parm_list[0];
        if (! ref($parms)) {
            croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - invalid parameters passed\n");
        }
    } else {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - bad parameters passed\n");
    }

    if (! (exists $parms->{-string})) {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - missing '-string' parameter\n");
    }
    my $string  = $parms->{-string};
    my $charset = $parms->{-charset};

    if (! defined ($charset)) {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - missing '-charset' parameter value\n");
    }
    my $true_charset = $_Charset_Names->{lc($charset)};
    if (! defined $true_charset) {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - character set '$charset' is not supported\n");
    }

    $string = '' if (! defined ($string));

    my $converter = $_Supported_Charsets->{$true_charset};
    if    ($converter eq 'map8')       { return _unicode_map8_to_utf8   ($string,$true_charset); }
    if    ($converter eq 'unicode-map'){ return _unicode_map_to_utf8    ($string,$true_charset); }
    elsif ($converter eq 'string')     { return _unicode_string_to_utf8 ($string,$true_charset); }
    elsif ($converter eq 'jcode')      { return _jcode_to_utf8          ($string,$true_charset); }
    else {
        croak(  '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - charset '$charset' is not supported\n");
    }
}

######################################################################

=over 4

=item C<from_utf8({ -string => $string, -charset => $target_charset});>


Returns the string converted from UTF8 to the specified target charset.

=back

=cut

sub from_utf8 {
    my @parm_list = @_;
    my $parms;
    if (($#parm_list > 0) && (($#parm_list % 2) == 1)) {
        $parms = { @parm_list };
    } elsif ($#parm_list == 0) {
        $parms = $parm_list[0];
        if (! ref($parms)) {
            croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - invalid parameters passed\n");
        }
    } else {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - bad parameters passed\n");
    }

    if (! (exists $parms->{-string})) {
    ; croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - missing '-string' parameter\n");
    }

    my $string  = $parms->{-string};
    my $charset = $parms->{-charset};

    if (! defined ($charset)) {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - missing '-charset' parameter value\n");
    }
    my $true_charset = $_Charset_Names->{lc($charset)};
    if (! defined $true_charset) {
        croak( '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - character set '$charset' is not supported\n");
    }

    $string = '' if (! defined ($string));

    my $converter = $_Supported_Charsets->{$true_charset};
    my $result;
    if    ($converter eq 'map8')        { $result = _unicode_map8_from_utf8   ($string,$true_charset); }
    elsif ($converter eq 'unicode-map') { $result =  _unicode_map_from_utf8    ($string,$true_charset); }
    elsif ($converter eq 'string')      { $result =  _unicode_string_from_utf8 ($string,$true_charset); }
    elsif ($converter eq 'jcode')       { $result = _jcode_from_utf8          ($string,$true_charset); }
    else {
        croak(  '[' . localtime(time) . '] ' . __PACKAGE__ . "::to_utf8() - charset '$charset' is not supported\n");
    }
    return $result;
}

######################################################################
#
# _unicode_map_from_utf8($string,$target_charset);
#
# Returns the string converted from UTF8 to the specified target multibyte charset.
#

sub _unicode_map_from_utf8 {
    my ($string,$target_charset) = @_;

    my $ucs2   = from_utf8 ($string,'ucs2');
    my $target = Unicode::Map8->new($target_charset);
    if (! defined $target) {
        die( '[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_map8_from_utf8() - (line $.) failed to instantate Unicode::Map8 object: $!\n");
    }
    my $result = $target->from_unicode($ucs2);
    return $result;
}

######################################################################
#
# _unicode_map_to_utf8($string,$source_charset);
#
# Returns the string converted the specified target multibyte charset to UTF8.
#
sub _unicode_map_to_utf8 {
    my ($string,$source_charset) = @_;

    my $source = Unicode::Map->new($source_charset);
    if (! defined $source) {
        die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_map_to_utf8() - (line $.) failed to instantate a Unicode::Map object: $!\n");
    }
    my $ucs2   = $source->to_unicode($string);
    my $result = to_utf8({ -string => $ucs2, -charset => 'ucs2' });
    return $result;
}

######################################################################
#
# _unicode_map8_from_utf8($string,$target_charset);
#
# Returns the string converted from UTF8 to the specified target 8bit charset.
#

sub _unicode_map8_from_utf8 {
    my ($string,$target_charset) = @_;

    my $u = Unicode::String::utf8($string);
    if (! $u) {
        die( '[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_map8_from_utf8() - (line $.) failed to instantate Unicode::String::utf8 object: $!\n");
    }
    my $ordering = $u->ord;
    $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
    my $ucs2_string = $u->ucs2;

    my $target = Unicode::Map8->new($target_charset);
    if (! defined $target) {
        die( '[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_map8_from_utf8() - (line $.) ailed to instantate Unicode::Map8 object: $!\n");
    }
    my $result = $target->to8($ucs2_string);

    return $result;
}

######################################################################
#
# _unicode_map8_to_utf8($string,$source_charset);
#
# Returns the string converted the specified target 8bit charset to UTF8.
#
#

sub _unicode_map8_to_utf8 {
    my ($string,$source_charset) = @_;

    my $source = Unicode::Map8->new($source_charset);
    if (! defined $source) {
        die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_map8_to_utf8() - (line $.) failed to instantate a Unicode::Map8 object: $!\n");
    }

    my $ucs2_string = $source->tou($string);
    if (! defined $ucs2_string) {
            die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_map8_to_utf8() - (line $.) failed to instantate a Unicode::String::utf16 object: $!\n");
    }
    my $utf8_string = $ucs2_string->utf8;

    return $utf8_string;
}

######################################################################
#
# _unicode_string_from_utf8($string,$target_charset);
#
# Returns the string converted from UTF8 to the specified unicode encoding.
#

sub _unicode_string_from_utf8 {
    my ($string,$target_charset) = @_;

    $target_charset = lc ($target_charset);
    my $final;
    if ($target_charset eq 'utf8') {
        $final = $string;
    } elsif ($target_charset eq 'ucs2') {
        my $u = Unicode::String::utf8($string);
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->ucs2;
    } elsif ($target_charset eq 'ucs4') {
        my $u = Unicode::String::utf8($string);
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->ucs4;
    } elsif ($target_charset eq 'utf16') {
        my $u = Unicode::String::utf8($string);
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->utf16;
    } elsif ($target_charset eq 'utf7') {
        my $u = Unicode::String::uft8($string);
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->utf7;
    } else {
        croak(  '[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_string_from_utf8() - charset '$target_charset' is not supported\n");
    }
    return $final;
}

######################################################################
#
# _unicode_string_to_utf8($string,$source_charset);
#
# Returns the string converted the specified unicode encoding to UTF8.
#

sub _unicode_string_to_utf8 {
    my ($string,$source_charset) = @_;

    $source_charset = lc ($source_charset);
    my $final;
    if    ($source_charset eq 'utf8') {
        $final = $string;
    } elsif ($source_charset eq 'ucs2') {
        my $u = Unicode::String::utf16($string);
        if (! defined $u) {
            die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_string_to_utf8() - (line $.) failed to instantate a Unicode::String::utf16 object: $!\n");
        }
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->utf8;
    } elsif ($source_charset eq 'ucs4') {
        my $u = Unicode::String::ucs4($string);
        if (! defined $u) {
            die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_string_to_utf8() - (line $.) failed to instantate a Unicode::String::ucs4 object: $!\n");
        }
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->utf8;
    } elsif ($source_charset eq 'utf16') {
        my $u = Unicode::String::uft16($string);
        if (! defined $u) {
            die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_string_to_utf8() - (line $.) failed to instantate a Unicode::String::utf16 object: $!\n");
        }
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->utf8;
    } elsif ($source_charset eq 'utf7') {
        my $u = Unicode::String::uft7($string);
        if (! defined $u) {
            die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_string_to_utf8() - (line $.) failed to instantate a Unicode::String::utf7 object: $!\n");
        }
        my $ordering = $u->ord;
        $u->byteswap if (defined($ordering) && ($ordering == 0xFFFE));
        $final = $u->utf8;
    } else {
        croak(  '[' . localtime(time) . '] ' . __PACKAGE__ . ":: _unicode_string_to_utf8() - charset '$source_charset' is not supported\n");
    }

    return $final;
}

######################################################################
#
# _jcode_from_utf8($string,$target_charset);
#
# Returns the string converted from UTF8 to the specified Jcode encoding.
#

sub _jcode_from_utf8 {
    my ($string,$target_charset) = @_;

    my $j = Jcode->new($string,'utf8');

    $target_charset = lc ($target_charset);
    my $final;
    if    ($target_charset eq 'iso-2022-jp') {
        $final = $j->iso_2022_jp;
    } elsif ($target_charset eq 'sjis') {
        $final = $j->sjis;
    } elsif ($target_charset eq 'euc-jp') {
        $final = $j->euc;
    } elsif ($target_charset eq 'jis') {
        $final = $j->jis;
    } else {
        croak(  '[' . localtime(time) . '] ' . __PACKAGE__ . "::_jcode_from_utf8() - charset '$target_charset' is not supported\n");
    }
    return $final;
}

######################################################################
#
# _utf8_from_jcode($string,$source_charset);
#
# Returns the string converted from the specified Jcode encoding to UTF8.
#

sub _utf8_from_jcode {
    my ($string,$source_charset) = @_;

    $source_charset = lc ($source_charset);

    my $final;
    if    ($source_charset eq 'iso-2022-jp') {
        my $j  = Jcode->new($string,$source_charset);
        $final = $j->utf8;
    } elsif ($source_charset eq 'sjis') {
        my $j  = Jcode->new($string,$source_charset);
        $final = $j->utf8;
    } elsif ($source_charset eq 'euc-jp') {
        my $j  = Jcode->new($string,$source_charset);
        $final = $j->utf8;
    } elsif ($source_charset eq 'jis') {
        my $j  = Jcode->new($string,$source_charset);
        $final = $j->utf8;
    } else {
        croak(  '[' . localtime(time) . '] ' . __PACKAGE__ . "::_utf8_from_jcode() - charset '$source_charset' is not supported\n");
    }

    return $final;
}

#######################################################################
#
# Character set handlers map
#

$_Supported_Charsets = {
    'ANSI_X3.110-1983'        => 'map8',
    'CSA_T500-1983'           => 'map8',
    'NAPLPS'                  => 'map8',
    'iso-ir-99'               => 'map8',
    'ANSI_X3.4-1968'          => 'map8',
    'ANSI_X3.4-1986'          => 'map8',
    'ASCII'                   => 'map8',
    'IBM367'                  => 'map8',
    'ISO646-US'               => 'map8',
    'ISO_646.irv:1991'        => 'map8',
    'US-ASCII'                => 'map8',
    'cp367'                   => 'map8',
    'iso-ir-6'                => 'map8',
    'us'                      => 'map8',
    'ASMO_449'                => 'map8',
    'ISO_9036'                => 'map8',
    'arabic7'                 => 'map8',
    'iso-ir-89'               => 'map8',
    'Adobe-Standard'          => 'map8',
    'adobe-standard'          => 'map8',
    'Adobe-Symbol'            => 'map8',
    'adobe-symbol'            => 'map8',
    'Adobe-Zapf-Dingbats'     => 'map8',
    'adobe-zapf-dingbats'     => 'map8',
    'BS_4730'                 => 'map8',
    'ISO646-GB'               => 'map8',
    'gb'                      => 'map8',
    'iso-ir-4'                => 'map8',
    'uk'                      => 'map8',
    'BS_viewdata'             => 'map8',
    'iso-ir-47'               => 'map8',
    'CSA_Z243.4-1985-1'       => 'map8',
    'ISO646-CA'               => 'map8',
    'ca'                      => 'map8',
    'csa7-1'                  => 'map8',
    'iso-ir-121'              => 'map8',
    'CSA_Z243.4-1985-2'       => 'map8',
    'ISO646-CA2'              => 'map8',
    'csa7-2'                  => 'map8',
    'iso-ir-122'              => 'map8',
    'CSA_Z243.4-1985-gr'      => 'map8',
    'iso-ir-123'              => 'map8',
    'CSN_369103'              => 'map8',
    'iso-ir-139'              => 'map8',
    'DEC-MCS'                 => 'map8',
    'dec'                     => 'map8',
    'DIN_66003'               => 'map8',
    'ISO646-DE'               => 'map8',
    'de'                      => 'map8',
    'iso-ir-21'               => 'map8',
    'DS_2089'                 => 'map8',
    'DS2089'                  => 'map8',
    'ISO646-DK'               => 'map8',
    'dk'                      => 'map8',
    'ECMA-cyrillic'           => 'map8',
    'iso-ir-111'              => 'map8',
    'ES'                      => 'map8',
    'ISO646-ES'               => 'map8',
    'iso-ir-17'               => 'map8',
    'ES2'                     => 'map8',
    'ISO646-ES2'              => 'map8',
    'iso-ir-85'               => 'map8',
    'GB_1988-80'              => 'map8',
    'ISO646-CN'               => 'map8',
    'cn'                      => 'map8',
    'iso-ir-57'               => 'map8',
    'GOST_19768-74'           => 'map8',
    'ST_SEV_358-88'           => 'map8',
    'iso-ir-153'              => 'map8',
    'IBM037'                  => 'map8',
    'cp037'                   => 'map8',
    'ebcdic-cp-ca'            => 'map8',
    'ebcdic-cp-nl'            => 'map8',
    'ebcdic-cp-us'            => 'map8',
    'ebcdic-cp-wt'            => 'map8',
    'IBM038'                  => 'map8',
    'EBCDIC-INT'              => 'map8',
    'cp038'                   => 'map8',
    'IBM1026'                 => 'map8',
    'CP1026'                  => 'map8',
    'IBM273'                  => 'map8',
    'CP273'                   => 'map8',
    'IBM274'                  => 'map8',
    'CP274'                   => 'map8',
    'EBCDIC-BE'               => 'map8',
    'IBM275'                  => 'map8',
    'EBCDIC-BR'               => 'map8',
    'cp275'                   => 'map8',
    'IBM277'                  => 'map8',
    'EBCDIC-CP-DK'            => 'map8',
    'EBCDIC-CP-NO'            => 'map8',
    'IBM278'                  => 'map8',
    'CP278'                   => 'map8',
    'ebcdic-cp-fi'            => 'map8',
    'ebcdic-cp-se'            => 'map8',
    'IBM280'                  => 'map8',
    'CP280'                   => 'map8',
    'ebcdic-cp-it'            => 'map8',
    'IBM281'                  => 'map8',
    'EBCDIC-JP-E'             => 'map8',
    'cp281'                   => 'map8',
    'IBM284'                  => 'map8',
    'CP284'                   => 'map8',
    'ebcdic-cp-es'            => 'map8',
    'IBM285'                  => 'map8',
    'CP285'                   => 'map8',
    'ebcdic-cp-gb'            => 'map8',
    'IBM290'                  => 'map8',
    'EBCDIC-JP-kana'          => 'map8',
    'cp290'                   => 'map8',
    'IBM297'                  => 'map8',
    'cp297'                   => 'map8',
    'ebcdic-cp-fr'            => 'map8',
    'IBM420'                  => 'map8',
    'cp420'                   => 'map8',
    'ebcdic-cp-ar1'           => 'map8',
    'IBM424'                  => 'map8',
    'cp424'                   => 'map8',
    'ebcdic-cp-he'            => 'map8',
    'IBM437'                  => 'map8',
    '437'                     => 'map8',
    'cp437'                   => 'map8',
    'IBM500'                  => 'map8',
    'CP500'                   => 'map8',
    'ebcdic-cp-be'            => 'map8',
    'ebcdic-cp-ch'            => 'map8',
    'IBM850'                  => 'map8',
    '850'                     => 'map8',
    'cp850'                   => 'map8',
    'IBM851'                  => 'map8',
    '851'                     => 'map8',
    'cp851'                   => 'map8',
    'IBM852'                  => 'map8',
    '852'                     => 'map8',
    'cp852'                   => 'map8',
    'IBM855'                  => 'map8',
    '855'                     => 'map8',
    'cp855'                   => 'map8',
    'IBM857'                  => 'map8',
    '857'                     => 'map8',
    'cp857'                   => 'map8',
    'IBM860'                  => 'map8',
    '860'                     => 'map8',
    'cp860'                   => 'map8',
    'IBM861'                  => 'map8',
    '861'                     => 'map8',
    'cp-is'                   => 'map8',
    'cp861'                   => 'map8',
    'IBM862'                  => 'map8',
    '862'                     => 'map8',
    'cp862'                   => 'map8',
    'IBM863'                  => 'map8',
    '863'                     => 'map8',
    'cp863'                   => 'map8',
    'IBM864'                  => 'map8',
    'cp864'                   => 'map8',
    'IBM865'                  => 'map8',
    '865'                     => 'map8',
    'cp865'                   => 'map8',
    'IBM868'                  => 'map8',
    'CP868'                   => 'map8',
    'cp-ar'                   => 'map8',
    'IBM869'                  => 'map8',
    '869'                     => 'map8',
    'cp-gr'                   => 'map8',
    'cp869'                   => 'map8',
    'IBM870'                  => 'map8',
    'CP870'                   => 'map8',
    'ebcdic-cp-roece'         => 'map8',
    'ebcdic-cp-yu'            => 'map8',
    'IBM871'                  => 'map8',
    'CP871'                   => 'map8',
    'ebcdic-cp-is'            => 'map8',
    'IBM880'                  => 'map8',
    'EBCDIC-Cyrillic'         => 'map8',
    'cp880'                   => 'map8',
    'IBM891'                  => 'map8',
    'cp891'                   => 'map8',
    'IBM903'                  => 'map8',
    'cp903'                   => 'map8',
    'IBM904'                  => 'map8',
    '904'                     => 'map8',
    'cp904'                   => 'map8',
    'IBM905'                  => 'map8',
    'CP905'                   => 'map8',
    'ebcdic-cp-tr'            => 'map8',
    'IBM918'                  => 'map8',
    'CP918'                   => 'map8',
    'ebcdic-cp-ar2'           => 'map8',
    'IEC_P27-1'               => 'map8',
    'iso-ir-143'              => 'map8',
    'INIS'                    => 'map8',
    'iso-ir-49'               => 'map8',
    'INIS-8'                  => 'map8',
    'iso-ir-50'               => 'map8',
    'INIS-cyrillic'           => 'map8',
    'iso-ir-51'               => 'map8',
    'ISO_10367-box'           => 'map8',
    'iso-ir-155'              => 'map8',
    'ISO_2033-1983'           => 'map8',
    'e13b'                    => 'map8',
    'iso-ir-98'               => 'map8',
    'ISO_5427'                => 'map8',
    'ISO_5427:1981'           => 'map8',
    'iso-ir-37'               => 'map8',
    'iso-ir-54'               => 'map8',
    'ISO_5428'                => 'map8',
    'ISO_5428:1980'           => 'map8',
    'iso-ir-55'               => 'map8',
    'ISO_646.basic'           => 'map8',
    'ISO_646.basic:1983'      => 'map8',
    'ref'                     => 'map8',
    'ISO_646.irv'             => 'map8',
    'ISO_646.irv:1983'        => 'map8',
    'irv'                     => 'map8',
    'iso-ir-2'                => 'map8',
    'ISO_6937-2-25'           => 'map8',
    'iso-ir-152'              => 'map8',
    'ISO_6937-2-add'          => 'map8',
    'iso-ir-142'              => 'map8',
    'ISO_8859-1'              => 'map8',
    '8859-1'                  => 'map8',
    'CP819'                   => 'map8',
    'IBM819'                  => 'map8',
    'ISO-8859-1'              => 'map8',
    'ISO_8859-1:1987'         => 'map8',
    'iso-ir-100'              => 'map8',
    'iso8859-1'               => 'map8',
    'l1'                      => 'map8',
    'latin1'                  => 'map8',
    'ISO_8859-2'              => 'map8',
    '8859-2'                  => 'map8',
    'ISO-8859-2'              => 'map8',
    'ISO_8859-2:1987'         => 'map8',
    'iso-ir-101'              => 'map8',
    'iso8859-2'               => 'map8',
    'l2'                      => 'map8',
    'latin2'                  => 'map8',
    'ISO_8859-3'              => 'map8',
    '8859-3'                  => 'map8',
    'ISO-8859-3'              => 'map8',
    'ISO_8859-3:1988'         => 'map8',
    'iso-ir-109'              => 'map8',
    'iso8859-3'               => 'map8',
    'l3'                      => 'map8',
    'latin3'                  => 'map8',
    'ISO_8859-4'              => 'map8',
    '8859-4'                  => 'map8',
    'ISO-8859-4'              => 'map8',
    'ISO_8859-4:1988'         => 'map8',
    'iso-ir-110'              => 'map8',
    'iso8859-4'               => 'map8',
    'l4'                      => 'map8',
    'latin4'                  => 'map8',
    'ISO_8859-5'              => 'map8',
    '8859-5'                  => 'map8',
    'ISO-8859-5'              => 'map8',
    'ISO_8859-5:1988'         => 'map8',
    'cyrillic'                => 'map8',
    'iso-ir-144'              => 'map8',
    'iso8859-5'               => 'map8',
    'ISO_8859-6'              => 'map8',
    '8859-6'                  => 'map8',
    'ASMO-708'                => 'map8',
    'ECMA-114'                => 'map8',
    'ISO-8859-6'              => 'map8',
    'ISO_8859-6:1987'         => 'map8',
    'arabic'                  => 'map8',
    'iso-ir-127'              => 'map8',
    'iso8859-6'               => 'map8',
    'ISO_8859-7'              => 'map8',
    '8859-7'                  => 'map8',
    'ECMA-118'                => 'map8',
    'ELOT_928'                => 'map8',
    'ISO-8859-7'              => 'map8',
    'ISO_8859-7:1987'         => 'map8',
    'greek'                   => 'map8',
    'greek8'                  => 'map8',
    'iso-ir-126'              => 'map8',
    'iso8859-7'               => 'map8',
    'ISO_8859-8'              => 'map8',
    '8859-8'                  => 'map8',
    'ISO-8859-8'              => 'map8',
    'ISO_8859-8:1988'         => 'map8',
    'hebrew'                  => 'map8',
    'iso-ir-138'              => 'map8',
    'iso8859-8'               => 'map8',
    'ISO_8859-9'              => 'map8',
    '8859-9'                  => 'map8',
    'ISO-8859-9'              => 'map8',
    'ISO_8859-9:1989'         => 'map8',
    'iso-ir-148'              => 'map8',
    'iso8859-9'               => 'map8',
    'l5'                      => 'map8',
    'latin5'                  => 'map8',
    'ISO_8859-supp'           => 'map8',
    'iso-ir-154'              => 'map8',
    'latin1-2-5'              => 'map8',
    'IT'                      => 'map8',
    'ISO646-IT'               => 'map8',
    'iso-ir-15'               => 'map8',
    'JIS_C6220-1969-jp'       => 'map8',
    'JIS_C6220-1969'          => 'map8',
    'iso-ir-13'               => 'map8',
    'katakana'                => 'map8',
    'x0201-7'                 => 'map8',
    'JIS_C6220-1969-ro'       => 'map8',
    'ISO646-JP'               => 'map8',
    'iso-ir-14'               => 'map8',
    'jp'                      => 'map8',
    'JIS_C6229-1984-a'        => 'map8',
    'iso-ir-91'               => 'map8',
    'jp-ocr-a'                => 'map8',
    'JIS_C6229-1984-b'        => 'map8',
    'ISO646-JP-OCR-B'         => 'map8',
    'iso-ir-92'               => 'map8',
    'jp-ocr-b'                => 'map8',
    'JIS_C6229-1984-b-add'    => 'map8',
    'iso-ir-93'               => 'map8',
    'jp-ocr-b-add'            => 'map8',
    'JIS_C6229-1984-hand'     => 'map8',
    'iso-ir-94'               => 'map8',
    'jp-ocr-hand'             => 'map8',
    'JIS_C6229-1984-hand-add' => 'map8',
    'iso-ir-95'               => 'map8',
    'jp-ocr-hand-add'         => 'map8',
    'JIS_C6229-1984-kana'     => 'map8',
    'iso-ir-96'               => 'map8',
    'JIS_X0201'               => 'map8',
    'X0201'                   => 'map8',
    'JUS_I.B1.002'            => 'map8',
    'ISO646-YU'               => 'map8',
    'iso-ir-141'              => 'map8',
    'js'                      => 'map8',
    'yu'                      => 'map8',
    'JUS_I.B1.003-mac'        => 'map8',
    'iso-ir-147'              => 'map8',
    'macedonian'              => 'map8',
    'JUS_I.B1.003-serb'       => 'map8',
    'iso-ir-146'              => 'map8',
    'serbian'                 => 'map8',
    'KSC5636'                 => 'map8',
    'ISO646-KR'               => 'map8',
    'Latin-greek-1'           => 'map8',
    'iso-ir-27'               => 'map8',
    'MSZ_7795.3'              => 'map8',
    'ISO646-HU'               => 'map8',
    'hu'                      => 'map8',
    'iso-ir-86'               => 'map8',
    'NATS-DANO'               => 'map8',
    'iso-ir-9-1'              => 'map8',
    'NATS-DANO-ADD'           => 'map8',
    'iso-ir-9-2'              => 'map8',
    'NATS-SEFI'               => 'map8',
    'iso-ir-8-1'              => 'map8',
    'NATS-SEFI-ADD'           => 'map8',
    'iso-ir-8-2'              => 'map8',
    'NC_NC00-10'              => 'map8',
    'ISO646-CU'               => 'map8',
    'NC_NC00-10:81'           => 'map8',
    'cuba'                    => 'map8',
    'iso-ir-151'              => 'map8',
    'NF_Z_62-010'             => 'map8',
    'ISO646-FR'               => 'map8',
    'ISO646-FR1'              => 'map8',
    'NF_Z_62-010_(1973)'      => 'map8',
    'fr'                      => 'map8',
    'iso-ir-25'               => 'map8',
    'iso-ir-69'               => 'map8',
    'NS_4551-1'               => 'map8',
    'ISO646-NO'               => 'map8',
    'iso-ir-60'               => 'map8',
    'no'                      => 'map8',
    'NS_4551-2'               => 'map8',
    'ISO646-NO2'              => 'map8',
    'iso-ir-61'               => 'map8',
    'no2'                     => 'map8',
    'PT'                      => 'map8',
    'ISO646-PT'               => 'map8',
    'iso-ir-16'               => 'map8',
    'PT2'                     => 'map8',
    'ISO646-PT2'              => 'map8',
    'iso-ir-84'               => 'map8',
    'SEN_850200_B'            => 'map8',
    'FI'                      => 'map8',
    'ISO646-FI'               => 'map8',
    'ISO646-SE'               => 'map8',
    'iso-ir-10'               => 'map8',
    'se'                      => 'map8',
    'SEN_850200_C'            => 'map8',
    'ISO646-SE2'              => 'map8',
    'iso-ir-11'               => 'map8',
    'se2'                     => 'map8',
    'T.101-G2'                => 'map8',
    'iso-ir-128'              => 'map8',
    'T.61-7bit'               => 'map8',
    'iso-ir-102'              => 'map8',
    'T.61-8bit'               => 'map8',
    'T.61'                    => 'map8',
    'iso-ir-103'              => 'map8',
    'cp037'                   => 'map8',
    'IBMUSCanada'             => 'map8',
    'cp10000'                 => 'map8',
    'MacRoman'                => 'map8',
    'cp10006'                 => 'map8',
    'MacGreek'                => 'map8',
    'cp10007'                 => 'map8',
    'MacCyrillic'             => 'map8',
    'cp10029'                 => 'map8',
    'MacLatin2'               => 'map8',
    'cp10079'                 => 'map8',
    'MacIcelandic'            => 'map8',
    'cp10081'                 => 'map8',
    'MacTurkish'              => 'map8',
    'cp1026'                  => 'map8',
    'IBMLatin5Turkish'        => 'map8',
    'cp1250'                  => 'map8',
    'WinLatin2'               => 'map8',
    'cp1251'                  => 'map8',
    'WinCyrillic'             => 'map8',
    'cp1252'                  => 'map8',
    'WinLatin1'               => 'map8',
    'cp1253'                  => 'map8',
    'WinGreek'                => 'map8',
    'cp1254'                  => 'map8',
    'WinTurkish'              => 'map8',
    'cp1255'                  => 'map8',
    'WinHebrew'               => 'map8',
    'cp1256'                  => 'map8',
    'WinArabic'               => 'map8',
    'cp1257'                  => 'map8',
    'WinBaltic'               => 'map8',
    'cp1258'                  => 'map8',
    'WinVietnamese'           => 'map8',
    'cp437'                   => 'map8',
    'DOSLatinUS'              => 'map8',
    'cp500'                   => 'map8',
    'IBMInternational'        => 'map8',
    'cp737'                   => 'map8',
    'DOSGreek'                => 'map8',
    'cp775'                   => 'map8',
    'DOSBaltRim'              => 'map8',
    'cp850'                   => 'map8',
    'DOSLatin1'               => 'map8',
    'cp852'                   => 'map8',
    'DOSLatin2'               => 'map8',
    'cp855'                   => 'map8',
    'DOSCyrillic'             => 'map8',
    'cp857'                   => 'map8',
    'DOSTurkish'              => 'map8',
    'cp860'                   => 'map8',
    'DOSPortuguese'           => 'map8',
    'cp861'                   => 'map8',
    'DOSIcelandic'            => 'map8',
    'cp862'                   => 'map8',
    'DOSHebrew'               => 'map8',
    'cp863'                   => 'map8',
    'DOSCanadaF'              => 'map8',
    'cp864'                   => 'map8',
    'DOSArabic'               => 'map8',
    'cp865'                   => 'map8',
    'DOSNordic'               => 'map8',
    'cp866'                   => 'map8',
    'DOSCyrillicRussian'      => 'map8',
    'cp869'                   => 'map8',
    'DOSGreek2'               => 'map8',
    'cp874'                   => 'map8',
    'DOSThai'                 => 'map8',
    'cp875'                   => 'map8',
    'IBMGreek'                => 'map8',
    'greek-ccitt'             => 'map8',
    'iso-ir-150'              => 'map8',
    'greek7'                  => 'map8',
    'iso-ir-88'               => 'map8',
    'greek7-old'              => 'map8',
    'iso-ir-18'               => 'map8',
    'hp-roman8'               => 'map8',
    'r8'                      => 'map8',
    'roman8'                  => 'map8',
    'latin-greek'             => 'map8',
    'iso-ir-19'               => 'map8',
    'latin-lap'               => 'map8',
    'iso-ir-158'              => 'map8',
    'lap'                     => 'map8',
    'latin6'                  => 'map8',
    'iso-ir-157'              => 'map8',
    'l6'                      => 'map8',
    'macintosh'               => 'map8',
    'mac'                     => 'map8',
    'videotex-suppl'          => 'map8',
    'iso-ir-70'               => 'map8',
    'utf8'                    => 'string',
    'ucs2'                    => 'string',
    'ucs4'                    => 'string',
    'utf7'                    => 'string',
    'utf16'                   => 'string',
    'sjis'                    => 'jcode',
    'iso-2022-jp'             => 'jcode',
    'jis'                     => 'jcode',
    'euc-jp'                  => 'jcode',
};

$_Charset_Names = { map { lc ($_) => $_ } keys %$_Supported_Charsets };

# Add any charsets not already listed from Unicode::Map
{
    my $unicode_map = Unicode::Map->new;
    my @map_ids     = $unicode_map->ids;
    foreach my $id (@map_ids) {
        my $lc_id = lc ($id);
        next if (exists ($_Charset_Names->{$lc_id}));
        $_Supported_Charsets->{$id} = 'unicode-map';
        $_Charset_Names->{$lc_id}    = $id;
    }
}

######################################################################

=head1 VERSION

1.01 2000.10.02 - Initial Public Release.

=head1 COPYRIGHT

Copyright September, 2000 Benjamin Franz. All rights reserved.

This software is free software.  You can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Benjamin Franz <snowhare@nihongo.org>

=head1 TODO

Regression tests for Jcode and 2-byte encodings

=head1 SEE ALSO

Unicode::String Unicode::Map8 Unicode::Map Jcode

=cut

1;
