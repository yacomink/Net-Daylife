use strict;
use Test::More qw(no_plan);
use Test::MockModule;

use Net::Daylife;
use Digest::MD5 qw (md5_hex);

# From the docs 
# 
# So, for example in PHP:
# 
# $accesskey = "6674e8aeda420d50e716706c20c12345"; 
# $sharedsecret = "2234e8aeda420d50e716706c20c56789"; 
# $coreinput = "Iraq war"; 
# 
# $signature = hash('md5', $accesskey.$sharedsecret.$coreinput);
# 
# Note that the core input should NOT be urlencoded for the purposes of signature generation. 
# 
# If an API call accepts multiple values for the core input parameter (e.g. article calls can accept multiple article ids or multiple article urls), the $coreinput for signature generation is a concatenated string of alphabetically sorted list of the core input values.
# 
# For example, calling article_getInfo for article ids 0eQ1fovglo368, 0fP60GB2Qy9EX and 08Dh1Ij97064e, to create signature in PHP:
# 
# $accesskey = "6674e8aeda420d50e716706c20c12345"; 
# $sharedsecret = "2234e8aeda420d50e716706c20c56789"; 
# $coreinput = "08Dh1Ij97064e" . "0eQ1fovglo368" . "0fP60GB2Qy9EX"; 
# 
# $signature = hash('md5', $accesskey.$sharedsecret.$coreinput);

my $example_creds = {
	access_key => "6674e8aeda420d50e716706c20c12345",
	shared_secret => "2234e8aeda420d50e716706c20c56789"
};

my $mock_hash = new Test::MockModule('Digest::MD5');
$mock_hash->mock('md5_hex', sub { shift });

my ($sig, $expected_sig);
my $module = Net::Daylife->new( config => $example_creds );

$sig = $module->sign_args({ query => 'Iraq war' });
$expected_sig = join('', ($example_creds->{access_key}, $example_creds->{shared_secret}, 'Iraq war') );
is ($sig, $expected_sig, "Query signature correct");

$sig = $module->sign_args({ article_id => ["08Dh1Ij97064e" . "0eQ1fovglo368" . "0fP60GB2Qy9EX"] });
$expected_sig = join('', ($example_creds->{access_key}, $example_creds->{shared_secret}, "08Dh1Ij97064e" . "0eQ1fovglo368" . "0fP60GB2Qy9EX") );
is ($sig, $expected_sig, "Query signature correct for array of values");


$sig = $module->sign_args({ query => 'Iraq war', source_filter_id => '2109420' });
$expected_sig = join('', ($example_creds->{access_key}, $example_creds->{shared_secret}, 'Iraq war') );
is ($sig, $expected_sig, "Query signature correct, only includes core input");


is( 1, 1, 'hi' );

# plan tests => no_plan;

