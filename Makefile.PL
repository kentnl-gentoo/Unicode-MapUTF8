use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'       => 'Unicode::MapUTF8',
  'VERSION_FROM' => 'lib/Unicode/MapUTF8.pm',
    'linkext'    => { 'LINKTYPE' => '' },    # no link needed
    'dist'       => { 'COMPRESS' => 'gzip -9f',     'SUFFIX' => 'gz',
                           'ZIP' => '/usr/bin/zip','ZIPFLAGS'=>'-rl'},
'PREREQ_PM'      => {
                'Unicode::Map'     => 0,
                'Unicode::String'  => 0,
                'Unicode::Map8'    => 0,
                'Jcode'            => 0,
                        },
);
