# -*-cperl-*-

package Net::Daylife;
use base qw (LWP::UserAgent);

$Net::Daylife::VERSION = '1.0';

=head1 NAME

Net::Daylife - OOP for the Daylife.com API

=head1 SYNOPSIS

 use Getopt::Std;
 use Net::Daylife;

 my %opts = ();
 getopts('c:', \%opts);

 my $day = Net::Daylife->new('config' => $opts{'c'});

 my $res = $day->api_call('search_getRelatedArticles', {'query' => 'flickr'});

 foreach my $a ($res->findnodes("/response/payload/article")){
        print $a->findvalue("headline") . "\n";
 }

=head1 DESCRIPTION

Net::Daylife is an OOP wrapper for the Daylife.com API.

Rather than try to mirror the API itself with individual object methods it exposes
one principle method called...you guessed it, I<api_call> that accepts an API
method name and its arguments as a hash reference.

API results are returned in a format specific handler. For example, XML responses
are returned as I<XML::XPath> objects, JSON responses as I<JSON::Any> objects and
so on.

Currently only HTTP level errors are handled. API specific errors are left to the
developer. At some point I may add format specific packages (Net::Daylife::XML, etc.)
at which point it will make more sense to check response codes automagically.

=head1 OPTIONS

Options are passed to Net::Daylife using a Config::Simple object or
a valid Config::Simple config file. Options are grouped by "block".

=head2 daypi

=over 4

=item * B<access_key>

String. I<required>

Your Daylife API access key.

=item * B<shared_secret>

String. I<required>

Your Daylife API shared secret.

=item * B<format>

String.

Return API results in a specific format. Valid options are : 

=over 4 

=item * B<xml>

API results will be parsed with and returned as a I<XML::XPath> object.

=item * B<json>

API results will be parsed with and returned as a I<JSON::Any> object.

=item * B<php>

API results will be parsed with I<PHP::Serialization> (or unserialize as the case
may be) and returned as a hash.

Why would you want to do this when you can just use JSON? That's your business, really...

=back

The default is B<xml>

=item *B <host>

String.

Which Daylife API server to talk to.

The default is B<freeapi.daylife.com>

=item * B<version>

String.

Which version of the Daylife API to use.

The default is B<4.2>

=back

=head1 LOGGING AND REPORTING

Logging is handled by an internal I<Log::Dispatch> method and errors are
written to STDERR. There is a I<log> object method for accessing the dispatch
handler directly.

=cut

use strict;

use URI;
use Digest::MD5 qw (md5_hex);
use HTTP::Request;

use Log::Dispatch;
use Log::Dispatch::Screen;

=head1 PACKAGE METHODS

=cut

=head2 __PACKAGE__->new(%options)

I<Net::Daylife> subclasses I<LWP::UserAgent>. In addition its parent class' arguments
you must include the following : 

=over 4 

=item * B<config>

Either a valid I<Config::Simple> object or the path to a file that can be parsed by
I<Config::Simple>.

=back

Returns a I<Net::Daylife> object!

=cut

sub new {
        my $pkg = shift;
        my %opts = @_;

        my $self = $pkg->SUPER::new(%opts);

        if (! $self){
                warn "Unable to instantiate parent class, $!";
                return undef;
        }

        my $cfg = $opts{'config'};
        $self->{'cfg'} = (UNIVERSAL::isa($cfg, "Config::Simple")) ? $cfg : Config::Simple->new($cfg);

        # 

        my $log_fmt = sub {
                my %args = @_;
                
                my $msg = $args{'message'};
                chomp $msg;
                
                if ($args{'level'} eq "error") {
                        
                        my ($ln, $sub) = (caller(4))[2,3];
                        $sub =~ s/.*:://;
                        
                        return sprintf("[%s][%s, ln%d] %s\n",
                                       $args{'level'}, $sub, $ln, $msg);
                }
                
                return sprintf("[%s] %s\n", $args{'level'}, $msg);
        };
        
        my $logger = Log::Dispatch->new(callbacks => $log_fmt);
        my $error  = Log::Dispatch::Screen->new(name      => '__error',
                                                min_level => 'error',
                                                stderr    => 1);
        
        $logger->add($error);
        $self->{'log'} = $logger;

        # 

        bless $self, $pkg;
        return $self;
}

=head1 OBJECT METHODS YOU SHOULD CARE ABOUT

=cut

=head2 $obj->api_call($method, \%args)

Execute an API call for the method called I<$method>, passing I<%args> as the ...well, arguments.

On success returns a format-specific object handler. On failure, returns false.

=cut

sub api_call {
        my $self = shift;
        my $method = shift;
        my $args = shift;

        my $res = $self->execute_request($method, $args);

        if (! $res->is_success()){
                $self->log()->error("API request failed with HTTP error " . $res->code() . " : " . $res->message());
                return 0;
        }

        return $self->parse_response($res);
}

=head1 OBJECT METHODS YOU MAY CARE ABOUT

=cut

=head2 $obj->execute_request($method, \%args)

Execute an API call for the method called I<$method>, passing I<%args> as the ...well, arguments.

On success returns an I<HTTP::Response> handler. On failure, returns false.

=cut

sub execute_request {
        my $self = shift;
        my $method = shift;
        my $args = shift;

        my $sig = $self->sign_args($args);

        $args->{'signature'} = $sig;
        $args->{'accesskey'} = $self->{'cfg'}->param("daypi.access_key");
        
        my $host = $self->divine_option("daypi.host", "freeapi.daylife.com");
        my $version = $self->divine_option("daypi.version", "4.2");
        my $format = $self->divine_option("daypi.format", "xml");
        
        my $endpoint = sprintf("/%srest/publicapi/%s/%s", $format, $version, $method);

        my $url = URI->new("http://" . $host);
        $url->path($endpoint);
        $url->query_form($args);

        $self->log()->info($url->as_string());

        my $req = HTTP::Request->new('GET' => $url->as_string());
        my $res = $self->request($req);

        $self->log()->debug($res->as_string());
        return $res;
}

=head2 $obj->sign_args(\%args)

Sign the arguments for an API call with the object's Daylife API shared secret.

Returns a sting.

=cut

sub sign_args {
        my $self = shift;
        my $args = shift;

        my $str_query = join("", sort {$a cmp $b} values %$args);

        my $raw = $self->{'cfg'}->param("daypi.access_key");
        $raw .= $self->{'cfg'}->param("daypi.shared_secret");
        $raw .= $str_query;

        return md5_hex($raw);
}

=head2 $obj->parse_response(HTTP::Response)

Helper method to juggle and hand off an API response to the correct format
handler.

Returns either an object or false.

=cut

sub parse_response {
        my $self = shift;
        my $res = shift;

        my $format = $self->divine_option("daypi.format", "xml");
        my $method = "parse_response_" . $format;

        if (! $self->can($method)){
                $self->log()->error("'$format' is an unknown or unsupported response format");
                return 0;
        }

        return $self->$method($res);
}

=head2 $obj->parse_response_xml(HTTP::Response)

Parse an API response in to an I<XML::XPath> object.

Returns false, otherwise.

=cut

sub parse_response_xml {
        my $self = shift;
        my $res = shift;
        
        my $xml = undef;

        eval {
                require XML::XPath;
                $xml = XML::XPath->new('xml' => $res->content());
        };

        if ($@){
                $self->log()->error("Failed to parse XML response : $@");
                return 0;
        }

        return $xml;
}

=head2 $obj->parse_response_json(HTTP::Response)

Parse an API response in to an I<JSON::Any> object.

Returns false, otherwise.

=cut

sub parse_response_json {
        my $self = shift;
        my $res = shift;

        my $json = undef;

        eval {
                require JSON::Any;
                $json = JSON::Any->new();
                $json = $json->jsonToObj($res->content());
        };

        if ($@){
                $self->log()->error("Failed to parse JSON response : $@");
                return 0;
        }

        return $json;
}

=head2 $obj->parse_response_php(HTTP::Response)

Parse an API response in to a hash using I<PHP::Serialization>.

Returns false, otherwise.

=cut

sub parse_response_php {
        my $self = shift;
        my $res = shift;

        my $php = undef;

        eval {
                require PHP::Serialization;
                $php = PHP::Serialization::unserialize($res->content());
        };

        if ($@){
                $self->log()->error("Failed to parse PHP response : $@");
                return 0;
        }

        return $php;
}

=head2 $obj->divine_option($option, $default)

Wrapper method check for configs that may be (re) set by a user.

Returns a string.

=cut

sub divine_option {
        my $self = shift;
        my $opt = shift;
        my $default = shift;

        if (my $v = $self->cfg()->param($opt)){
                $self->log()->debug("divine by config : $opt => $v");
                return $v;
        }

        $self->log()->debug("divine by default : $opt => $default");
        return $default;
}

=head2 $obj->log()

Access to the object's internal I<Log::Dispatch> object.

=cut

sub log {
        my $self = shift;
        return $self->{'log'};
}

=head2 $obj->cfg()

Access to the object's internal I<Config::Simple> object.

=cut

sub cfg {
        my $self = shift;
        return $self->{'cfg'};
}

=head1 VERSION

1.0

=head1 DATE

$Date: 2008/04/19 18:39:41 $

=head1 AUTHOR

Aaron Straup Cope E<lt>ascope@cpan.orgE<gt>

=head1 SEE ALSO 

L<http://www.daylife.com/>

L<http://developer.daylife.com/>

=head1 BUGS

Sure, why not.

Please report all bugs via L<http://rt.cpan.org>

=head1 LICENSE

Copyright (c) 2008 Aaron Straup Cope. All Rights Reserved.

This is free software. You may redistribute it and/or
modify it under the same terms as Perl itself.

=cut

return 1;
