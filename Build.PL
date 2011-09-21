# $Id: Build.PL,v 1.1 2008/04/19 18:27:29 asc Exp $

use strict;
use Module::Build;

my $build = Module::Build->new(module_name => 'Net::Daylife',
			       # dist_author
			       # dist_abstract
			       dist_version_from => 'lib/Net/Daylife.pm',
			       license           => 'perl',
			       requires => {
                                            'Config::Simple'  => '0',
                                            'URI' => '0',
                                            'Digest::MD5' => '0',
                                            'LWP::UserAgent' => '0',
                                            'HTTP::Request' => '0',
                                            'Log::Dispatch'   => '>= 2.10',
			       },
			       build_requires => {
                                                  'Test::Simple'              => '>= 0.47',
                                                  'XML::XPath'      => '>= 1.13',
			       },
			       create_readme      => 1,
			       create_makefile_pl => 'passthrough');

$build->create_build_script();
