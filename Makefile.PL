use strict;
use warnings;

use ExtUtils::MakeMaker 6.31;

my %WriteMakefileArgs = (
	'ABSTRACT'       => 'Net::Daylife is an OOP wrapper for the Daylife.com API.',
	'AUTHOR'         => 'Aaron Straup Cope <ascope@cpan.org>',
	'BUILD_REQUIRES' => {
		'Test::Simple' => '0.47',
		'XML::XPath'   => '1.13',
	},
	'CONFIGURE_REQUIRES' => { 'ExtUtils::MakeMaker' => '6.31' },
	'DISTNAME'           => 'Net-Daylife',
	'EXE_FILES'          => [],
	'LICENSE'            => 'perl',
	'NAME'               => 'Net::Daylife',
	'PREREQ_PM'          => {
		'URI'            => '0',
		'Digest::MD5'    => '0',
		'LWP::UserAgent' => '0',
		'HTTP::Request'  => '0',
		'Log::Dispatch'  => '2.10',
	},
	'VERSION' => '1.0',
	'test'    => { 'TESTS' => 't/*.t' }
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
	my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
	my $pp = $WriteMakefileArgs{PREREQ_PM};
	for my $mod ( keys %$br ) {
		if ( exists $pp->{$mod} ) {
			$pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
		}
		else {
			$pp->{$mod} = $br->{$mod};
		}
	}
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

