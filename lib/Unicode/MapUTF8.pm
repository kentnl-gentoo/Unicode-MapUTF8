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
    $VERSION     = "1.03";
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

1.03 2000.10.22 - Bug fix for load time autodetction of Unicode::Map8 encodings

1.02 2000.10.22 - Added load time autodetection of Unicode::Map8 supported
                  character set encodings.

                  Fixed internal calling error for some character sets with 'from_utf8'.
                  Thanks goes to Ilia Lobsanov <ilia@lobsanov.com> for reporting the
                  problem.

1.01 2000.10.02 - Fixed handling of empty strings and added more identification for error
                  messages.

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

    my $ucs2   = from_utf8 ({ -string => $string, -charset => 'ucs2' });
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
        die('[' . localtime(time) . '] ' . __PACKAGE__ . "::_unicode_map8_to_utf8() - (line $.) failed to instantate a Unicode::Map8 object for character set '$source_charset': $!\n");
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
# Character set handlers maps
#

# Various hard wird things
$_Supported_Charsets = {
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

# All the Unicode::Map8 charsets
{
    my @map_ids = &_list_unicode_map8_charsets;
    foreach my $id (@map_ids) {
        my $lc_id = lc ($id);
        next if (exists ($_Charset_Names->{$lc_id}));
        $_Supported_Charsets->{$id} = 'map8';
        $_Charset_Names->{$lc_id}    = $id;
    }
}
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
#
# Code taken and modified from the 'usr/bin/umap' code distributed
# with Unicode::Map8. It wouldn't be necessary if Unicode::Map8
# had a direct method for this....
#

sub _list_unicode_map8_charsets {
    my %set = (
	       ucs4 => {},
	       ucs2 => {utf16 => 1},
	       utf7 => {},
	       utf8 => {},
	      );
    if (opendir(DIR, $Unicode::Map8::MAPS_DIR)) {
        my @files = grep(!/^\.\.?$/,readdir(DIR));
        foreach my $f (@files) {
	        next unless -f "$Unicode::Map8::MAPS_DIR/$f";
	        $f =~ s/\.(?:bin|txt)$//;
            my $supported = 
	        $set{$f} = {} if Unicode::Map8->new($f);
	    }
    }

    my $avoid_warning = keys %Unicode::Map8::ALIASES;
    while ( my($alias, $charset) = each %Unicode::Map8::ALIASES) {
	    if (exists $set{$charset}) {
	        $set{$charset}{$alias} = 1;
	    }
    }

    my %merged_set = ();
    foreach my $encoding (keys %set) {
        $merged_set{$encoding} = 1;
        my $set_item = $set{$encoding};
        while (my ($key,$value) = each (%$set_item)) {
                $merged_set{$key} = $value;
	    }
    }
    my @final_charsets = sort keys %merged_set; 
    return @final_charsets;
}

######################################################################

=head1 VERSION

1.03 2000.10.22 - Bug fix for autodetected Unicode::Map8 encodings 

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
