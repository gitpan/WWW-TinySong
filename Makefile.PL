use 5.008008;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'WWW::TinySong',
    VERSION_FROM      => 'lib/WWW/TinySong.pm',
    PREREQ_PM         => {
                            Carp           => 1.04,
                            CGI            => 3.15,
                            HTML::Parser   => 3.59,
                            LWP::UserAgent => 5.822,
                         },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/WWW/TinySong.pm',
       AUTHOR         => 'Miorel-Lucian Palii <mlpalii@gmail.com>') : ()),
);
