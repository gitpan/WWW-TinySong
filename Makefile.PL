use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'WWW::TinySong',
    VERSION_FROM      => 'lib/WWW/TinySong.pm',
    LICENSE           => 'perl',
    PREREQ_PM         => {
                            Carp           => 0,
                            CGI            => 0,
                            Exporter       => 0,
                            HTML::Parser   => 3,
                            LWP::UserAgent => 0,
                         },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/WWW/TinySong.pm',
       AUTHOR         => 'Miorel-Lucian Palii <mlpalii@gmail.com>') : ()),
);
