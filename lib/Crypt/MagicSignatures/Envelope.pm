package Crypt::MagicSignatures::Envelope;
use strict;
use warnings;
use Crypt::MagicSignatures::Key qw/b64url_encode b64url_decode/;
use Carp qw/carp croak/;
use Mojo::DOM;
use Mojo::JSON;

our $VERSION = '0.01';

# MagicEnvelope namespace
use constant ME_NS => 'http://salmon-protocol.org/ns/magic-env';


# Constructor
sub new {
  my $class = shift;

  my $self;

  # Bless object with parameters
  if (@_ > 1 && !(@_ % 2)) {

    my %self = @_;

    # Given algorithm is wrong
    if ($self{alg} && uc($self{alg}) ne 'RSA-SHA256') {
      carp 'Algorithm is not supported' and return;
    };

    # Given encoding is wrong
    if ($self{encoding} &&
	  lc($self{encoding}) ne 'base64url') {
      carp 'Encoding is not supported' and return;
    };

    # No payload is given
    unless (defined $self{data}) {
      carp 'No data payload defined' and return;
    };

    # Create object
    $self = bless {}, $class;

    # Set data
    $self->data(delete $self{data});

    # Set data type if defined
    $self->data_type(delete $self{data_type})
      if $self{data_type};

    # Append all defined signatures
    foreach (@{$self{sigs}}) {

      # No value is given
      next unless $_->{value};

      # Create new array reference if not already existing
      $self->{sigs} //= [];

      # Start new signature value
      my %sig = ( value => $_->{value} );
      $sig{key_id} = $_->{key_id} if exists $_->{key_id};

      # Add signature to signature array
      push(@{$self->{sigs}}, \%sig);
    };
  }

  # Envelope is defined as a string
  else {

    # Construct object
    $self = bless { sigs => [] }, $class;

    # Message is me-xml
    if ($_[0] =~ /^[\s\t\n]*\</) {

      # Parse xml string
      my $dom = Mojo::DOM->new(xml => 1);
      $dom->parse( shift );

      # Extract envelope from env or provenance
      my $env = $dom->at('env');
      $env = $dom->at('provenance') unless $env;
      return if !$env || $env->namespace ne ME_NS;

      # Retrieve and edit data
      my $data = $env->at('data');

      # The envelope is empty
      return unless $data;

      # Add data type if given
      $self->data_type( $data->attrs->{type} ) if $data->attrs->{type};

      # Add decoded data
      $self->data( b64url_decode( $data->text ) );

      # Check algorithm
      if ($env->at('alg') &&
	    ($env->at('alg')->text ne 'RSA-SHA256')) {
	carp 'Algorithm is not supported' and return;
      };

      # Check encoding
      if ($env->at('encoding') &&
	    ($env->at('encoding')->text ne 'base64url')) {
	carp 'Encoding is not supported' and return;
      };

      # Find signatures
      $env->find('sig')->each(
	sub {
	  return unless $_->text;

	  my $sig_text = $_->text;
	  $sig_text =~ s/[\s\t]//g;

	  my %sig = ( value => $sig_text );

	  if (exists $_->attrs->{key_id}) {
	    $sig{key_id} = $_->attrs->{key_id};
	  };

	  # Add sig to array
	  push( @{ $self->{sigs} }, \%sig );
	});
    }

    # Message is me-json
    elsif ($_[0] =~ /^[\s\t\n]*\{/ ) {
      my $env;

      # Parse json object
      my $json = Mojo::JSON->new;
      $env = $json->decode( shift );

      unless (defined $env) {
	carp $json->error and return;
      };

      # Clone datastructure
      foreach (qw/data data_type encoding alg sigs/) {
	$self->{$_} = delete $env->{$_} if exists $env->{$_};
      };

      $self->data( b64url_decode( $self->data ));

      # Unknown parameters
      carp 'Unknown parameters: ' . join(',', %$env)
	if keys %$env;
    }

    # Message is me as a compact string
    elsif (((my $me_c = _trim($_[0])) =~ /\.YmFzZTY0dXJs\./) > 0) {

      # Parse me compact string
      my $value = [];
      foreach (@$value = split(/\./, $me_c) ) {
	$_ = b64url_decode( $_ ) if $_;
      };

      # Store sig to data structure
      for ($self->{sigs}->[0]) {
	next unless $value->[1];
	$_->{key_id}    = $value->[0] if defined $value->[0];
	$_->{value}     = $value->[1];
      };

      # Store values to data structure
      for ($value) {

	# ME is empty
	return unless $_->[2];

	$self->data( $_->[2] );
	if ($_->[3]) { $self->data_type( $_->[3] ) };
	if ($_->[4]) { $self->encoding( $_->[4] ) };
	if ($_->[5]) { $self->alg( $_->[5] ) };
      };
    };
  };

  # Message has unknown format
  unless ($self->data) {
    carp 'Envelope has unknown format' and return;
  };

  # The envelope is signed
  $self->{signed} = 1 if $self->{sigs}->[0];

  $self->{sig_base} = '';

  return $self;
};


# Signature algorithm
sub alg { 'RSA-SHA256' };


# Encoding of the MagicEnvelope
sub encoding { 'base64url' };


# Data of the MagicEnvelope
sub data {
  unless (defined $_[1]) {
    return shift->{data} // '';
  };
  my $self = shift;

  # Delete calculated signature base string
  delete $self->{sig_base};

  # Delete DOM tree
  delete $self->{dom};

  return ($self->{data} = join ' ', map { $_ } @_);
};


# Datatype of the MagicEnvelope's content
sub data_type {
  unless (defined $_[1]) {
    return shift->{data_type} // 'text/plain';
  };
  my $self = shift;

  # Delete calculated signature base string
  delete $self->{sig_base};

  # Delete DOM tree
  delete $self->{dom};

  return ($self->{data_type} = shift);
};


# Sign MagicEnvelope instance following the spec
sub sign {
  my $self = shift;

  return unless @_;

  # Get key and signature information
  my ($key_id, $mkey, $flag) = _key_array(@_);

  # Choose data to sign
  my $data = $flag eq '-data' ?
    b64url_encode($self->data) :
      $self->signature_base;

  # Todo: Regarding key id:
  # "If the signer does not maintain individual key_ids,
  #  it SHOULD output the base64url encoded representation
  #  of the SHA-256 hash of public key's application/magic-key
  #  representation."

  # A valid key is given
  if ($mkey) {

    # No valid private key
    return undef unless $mkey->d;

    # Compute signature for base string
    my $msig = $mkey->sign( $data );

    # No valid signature
    return undef unless $msig;

    # Sign envelope
    my %msig = ( value => $msig );
    $msig{key_id} = $key_id if defined $key_id;

    # Push signature
    push( @{ $self->{sigs} }, \%msig );

    # Declare envelope as signed
    $self->{signed} = 1;

    # Return envelope for piping
    return $self;
  };

  return;
};


# Verify Signature
sub verify {
  my $self = shift;

  # Regarding key id:
  # "If the signer does not maintain individual key_ids,
  #  it SHOULD output the base64url encoded representation
  #  of the SHA-256 hash of public key's application/magic-key
  #  representation."

  return unless $self->signed;

  my $verified = 0;
  foreach (@_) {

    my ($key_id, $mkey, $flag) = _key_array(
      ref $_ && ref $_ eq 'ARRAY' ? @$_ : $_
    );

    next unless $mkey;

    # Get signature
    my $sig = $self->signature($key_id);

    # Found key/sig pair
    if ($sig) {

      if ($flag ne '-data') {
	$verified = $mkey->verify($self->signature_base => $sig->{value});
	last if $verified;
      };

      if ($flag ~~ [qw/-data -compatible/]) {

	# Verify with b64url data
	$verified = $mkey->verify(b64url_encode($self->data) => $sig->{value});
	last if $verified;
      };
    };
  };

  return $verified;
};


# Retrieve MagicEnvelope signatures
sub signature {
  my $self = shift;
  my $key_id = shift;

  # MagicEnvelope has no signature
  return unless $self->signed;

  my @sigs = @{ $self->{sigs} };

  # No key_id given
  unless ($key_id) {

    # Search sigs for necessary default key
    foreach (@sigs) {
      return $_ unless exists $_->{key_id};
    };

    # Return first sig
    return $sigs[0];
  }

  # Key is given
  else {
    my $default;

    # Search sigs for necessary specific key
    foreach (@sigs) {

      # sig specifies key
      if (defined $_->{key_id}) {

	# Found wanted key
	return $_ if $_->{key_id} eq $key_id;
      }

      # sig needs default key
      else {
	$default = $_;
      };
    };

    # Return sig for default key
    return $default;
  };

  # No matching sig found
  return;
};


# Is the MagicEnvelope signed?
sub signed {

  # There is no specific key_id requested
  return $_[0]->{signed} unless defined $_[1];

  # Check for specific key_id
  foreach my $sig (@{ $_[0]->{sigs} }) {
    return 1 if $sig->{key_id} eq $_[1];
  };

  # Envelope is not signed
  return 0;
};


# Generate and return signature base
sub signature_base {
  my $self = shift;

  # Already computed
  return $self->{sig_base} if $self->{sig_base};

  $self->{sig_base} =
    join('.',
	 b64url_encode( $self->data, 0 ),
	 b64url_encode( $self->data_type ),
	 b64url_encode( $self->encoding ),
	 b64url_encode( $self->alg )
       );

  unless (defined $self->{sig_base}) {
    carp 'Unable to construct sig_base' and return;
  };

  return $self->{sig_base};
};


# Return the data as a Mojo::DOM if it is xml
sub dom {
  my $self = shift;

  # Already computed
  return $self->{dom} if $self->{dom};

  # Create new DOM instantiation
  my $dom = Mojo::DOM->new;
  if (index($self->data_type, 'xml') >= 0) {
    $dom->parse( $self->{data} );
  }

  else {
    return;
  };

  # Return DOM instantiation (Maybe empty)
  return ($self->{dom} = $dom);
};


# Return em-xml string
sub to_xml {
  my $self = shift;
  my $embed = shift;

  my $xml = '';

  my $start_tag = 'env';

  # Is a provenance me
  if ($embed) {
    $start_tag = 'provenance';
  }

  # Is a full document
  else {
    $xml = qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n};
  };

  # Start document
  $xml .= qq{<me:$start_tag xmlns:me="http://salmon-protocol.org/ns/magic-env">\n};

  # Data payload
  $xml .= '  <me:data';
  $xml .= ' type="' . $self->data_type . '"' if exists $self->{data_type};
  $xml .= ">" . b64url_encode($self->data, 0) . "</me:data>\n";

  # Encoding
  $xml .= '  <me:encoding>' . $self->encoding . "</me:encoding>\n";

  # Algorithm
  $xml .= '  <me:alg>' . $self->alg . "</me:alg>\n";

  # Signatures
  foreach my $sig (@{$self->{sigs}}) {
    $xml .= '  <me:sig';
    $xml .= ' key_id="' . $sig->{key_id} . '"' if $sig->{key_id};
    $xml .= '>' . b64url_encode($sig->{value}) . "</me:sig>\n"
  };

  # End document
  $xml .= "</me:$start_tag>";

  return $xml;
};


# Return em-compact string
sub to_compact {
  my $self = shift;

  # The me has to be signed
  return unless $self->signed;

  # Use default signature for serialization
  my $sig = $self->signature;

  return
    join(
      '.',
      b64url_encode( $sig->{key_id} ) || '',
      b64url_encode( $sig->{value} ),
      $self->signature_base
    );
};


# Return em-json string
sub to_json {
  my $self = shift;

  # Empty envelope
  return '{}' unless $self->data;

  # Create new datastructure
  my %new_em = (
    alg       => $self->alg,
    encoding  => $self->encoding,
    data_type => $self->data_type,
    data      => b64url_encode( $self->data ),
    sigs      => []
  );

  # loop through signatures
  foreach my $sig ( @{ $self->{sigs} } ) {
    my %msig = ( value => b64url_encode( $sig->{value} ) );
    $msig{key_id} = $sig->{key_id} if defined $sig->{key_id};
    push( @{ $new_em{sigs} }, \%msig );
  };

  # Return json-string
  return Mojo::JSON->new->encode( \%new_em );
};


# Delete all whitespaces
sub _trim {
  my $string = shift;
  $string =~ tr{\t-\x0d }{}d;
  $string;
};

sub _key_array {
  return () unless @_;

  my $flag = $_[-1] ~~ [qw/-data -compatible -base/] ? pop : '-base';

  my $key  = pop;
  my $key_id = shift;

  return () unless $key;

  my @param;

  # Hash reference
  if (ref $key && $key eq 'HASH') {
    return () unless $key->{n};
    @param = %$key;
  }

  # String or object
  else {
    @param = ($key);
  };

  # Create MagicKey from parameter
  my $mkey = Crypt::MagicSignatures::Key->new(@param);

  return ($key_id, $mkey, $flag);
};


1;


__END__

=pod

=head1 NAME

Crypt::MagicSignatures::Envelope - MagicEnvelopes for the Salmon Protocol

=head1 SYNOPSIS

  use Crypt::MagicSignatures::Envelope;

  my $me = Crypt::MagicSignatures::Envelope->new({
    data => 'Some arbitrary string.'
  });

  $me->sign('key-01' => 'RSA.vsd...');

  if ($me->verify('RSA.vsd...')) {
    print 'Signature is verified!';
  };

=head1 DESCRIPTION

L<Crypt::MagicSignatures::Envelope> implements MagicEnvelopes with MagicSignatures as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html> to sign messages of the L<Salmon Protocol|http://www.salmon-protocol.org/>.
MagicSignatures is a I<"robust mechanism for digitally signing nearly arbitrary messages">.

B<This module is an early release! There may be significant changes in the future.>


=head1 ATTRIBUTES

=head2 C<alg>

  my $alg = $me->alg;

The algorithm used for signing the MagicEnvelope.
Defaults to C<RSA-SHA256>, which is the only supported algorithm.


=head2 C<data>

  my $data = $me->data;
  $me->data('Hello world!');

The decoded data folded in the MagicEnvelope.


=head2 C<data_type>

  my $data_type = $me->data_type;
  $me->data_type('text/plain');

The mime type of the data folded in the MagicEnvelope.
Defaults to C<text/plain>.


=head2 C<dom>

  my $me = Crypt::MagicSignatures::Envelope->new( data => <<'XML' );
  <?xml version='1.0' encoding='UTF-8'?>
  <entry xmlns='http://www.w3.org/2005/Atom'>
    <author><uri>alice@example.com</uri></author>
  </entry>
  XML

  $me->data_type('application/atom+xml');

  # alice@example.com
  print $me->dom->at('author > uri')->text;

The L<Mojo::DOM> object of the decoded data,
if the MagicEnvelope contains XML.

B<This attribute is experimental and may change without warning!>


=head2 C<encoding>

  my $encoding = $me->encoding;

The encoding of the MagicEnvelope.
Defaults to C<base64url>, which is the only encoding supported.


=head2 C<signature>

  my $sig = $me->signature;
  my $sig = $me->signature('key-01');

A signature of the MagicEnvelope.
For retrieving a specific signature, pass a key id,
otherwise a default signature will be returned.

If a matching signature is found, the signature
is returned as a hash reference,
containing base64url encoded data for C<value>
and possibly a C<key_id>.
If no matching signature is found, a C<false> value is returned.


=head2 C<signature_base>

  my $base = $me->signature_base;

The signature base string of the MagicEnvelope as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#sbs>.


=head2 C<signed>

  # With key id
  if ($me->signed('key-01')) {
    print 'MagicEnvelope is signed with key-01.';
  }

  # Without key id
  elsif ($me->signed) {
    print 'MagicEnvelope is signed.';
  }

  else {
    print 'MagicEnvelope is not signed.';
  };

Returns a C<true> value in case the MagicEnvelope is signed at least once.
Accepts optionally a C<key_id> and returns a C<true> value, if the
MagicEnvelope was signed with this specific key.


=head1 METHODS


=head2 C<new>

  $me = Crypt::MagicSignatures::Envelope->new(<<'MEXML');
  <?xml version="1.0" encoding="UTF-8"?>
  <me:env xmlns:me="http://salmon-protocol.org/ns/magic-env">
    <me:data type="text/plain">
      U29tZSBhcmJpdHJhcnkgc3RyaW5nLg==
    </me:data>
    <me:encoding>base64url</me:encoding>
    <me:alg>RSA-SHA256</me:alg>
    <me:sig key_id="my-01">
      S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVluZkI5Ulh4dmRFSnFhQW5XUmpB
      UEJqZUM0b0lReER4d0IwWGVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==
    </me:sig>
  </me:env>
  MEXML

The constructor accepts MagicEnvelope data in various formats.
It accepts MagicEnvelopes in the XML format or an
XML document including a MagicEnvelope C<provenance> element
as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#anchor4>.

Additionally it accepts MagicEnvelopes in the JSON notation
or defined by the same attributes as the JSON notation
(but with the data not encoded)
as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#anchor5>.
The latter is the common way to fold new envelopes.

  $me = Crypt::MagicSignatures::Envelope->new(<<'MEJSON');
  {
    "data_type": "text\/plain",
    "data":"U29tZSBhcmJpdHJhcnkgc3RyaW5nLg==",
    "alg":"RSA-SHA256",
    "encoding":"base64url",
    "sigs": [
      { "key_id": "my-01",
        "value":"S1VqYVlIWFpuRGVTX3l4S09CcWdjRV..."
      }
    ]
  }
  MEJSON

  $me = Crypt::MagicSignatures::Envelope->new(
    data      => 'Some arbitrary string.',
    data_type => 'plain_text',
    alg       => 'RSA-SHA256',
    encoding  => 'base64url',
    sigs => [
      {
        key_id => 'my-01',
        value  => 'S1VqYVlIWFpuRGVTX3l4S09CcWdjRV...'
      }
    ]
  );

Finally the constructor accepts MagicEnvelopes in the compact
MagicEnvelope notation as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#compact>.

  $me = Crypt::MagicSignatures::Envelope->new(<<'MECOMPACT');
    bXktMDE=.S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVlu
    ZkI5Ulh4dmRFSnFhQW5XUmpBUEJqZUM0b0lReER4d0IwW
    GVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==.U29tZ
    SBhcmJpdHJhcnkgc3RyaW5nLg.dGV4dC9wbGFpbg.YmFz
    ZTY0dXJs.UlNBLVNIQTI1Ng
  MECOMPACT


=head2 C<sign>

  $me->sign('key-01' => 'RSA.hgfrhvb ...')
     ->sign('RSA.hgfrhvb ...')
     ->sign('RSA.hgfrhvb ...', -data)
     ->sign('key-02' => 'RSA.hgfrhvb ...', -data);

  my $mkey = Crypt::MagicSignatures::Key->new('RSA.hgfrhvb ...')
  $me->sign($mkey);

Adds a signature to the MagicEnvelope.

For adding a signature, the private key with an optional prepended
key id has to be given.
The private key can be a L<Crypt::MagicSignatures::Key> object,
a MagicKey string as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#rfc.section.8.1> or a hash reference
containing the non-generation parameters accepted by the
L<Crypt::MagicSignatures::Key> constructor.
Optionally a flag C<-data> can be passed,
that will sign the data payload instead of the signature base string as defined in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#rfc.section.3.2>
I<(this is implemented for compatibility with non-standard implementations)>.

On success, the method returns the MagicEnvelope,
otherwise it returns a C<false> value.

A MagicEnvelope can be signed multiple times.

B<This method is experimental and may change without warning!>


=head2 C<verify>

  my $mkey = Crypt::MagicSignatures::Key->new( 'RSA.hgfrhvb ...' )

  $me->verify(
    'RSA.vsd...',
    $mkey,
    ['key-01' => 'RSA.hgfrhvb...', -data]
  );

Verifies a signed envelope against a bunch of given public MagicKeys.
Returns a C<true> value on success, otherwise C<false>.

If one key succeeds, the envelope is verified.

An element can be a L<Crypt::MagicSignatures::Key> object,
a MagicKey string as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#rfc.section.8.1> or a hash reference
containing the non-generation parameters accepted by the
L<Crypt::MagicSignatures::Key> constructor.

For referring to a certain key, an array reference
can be passed, containing the key (defined as described above) with an optional prepended key id and an optional flag appended,
referring to the data to be verified.
Conforming with the specification the default value is C<-base>,
referring to the base signature string of the MagicEnvelope.
C<-data> will verify against the data only, C<-compatible> will first try to verify against the base signature string and then will verify against the data on failure
I<(this is implemented for compatibility with non-standard implementations)>.

B<This method is experimental and may change without warning!>


=head2 C<to_compact>

  my $compact_string = $me->to_compact;

Returns the MagicEnvelope in compact notation as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#compact>.


=head2 C<to_json>

  my $json_string = $me->to_json;

Returns the MagicEnvelope as a stringified json representation as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#anchor5>.


=head2 C<to_xml>

  my $xml_string = $me->to_xml;
  my $xml_provenance_string = $me->to_xml(1);

Returns the MagicEnvelope as a stringified xml representation as described in the
L<MagicSignatures Specification|http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-magicsig-01.html#anchor4>.
If a C<true> value is passed, a provenance fragment will be returned instead
of a valid xml document.


=head1 DEPENDENCIES

L<Crypt::MagicSignatures::Key>,
L<Mojolicious>.


=head1 KNOWN BUGS AND LIMITATIONS

The signing and verifification is not guaranteed to be
compatible with other implementations!
Implementations like L<StatusNet|http://status.net/> (L<Identi.ca|http://identi.ca/>),
L<MiniMe|https://code.google.com/p/minime-microblogger/>, and examples from the
L<reference implementation|https://code.google.com/p/salmon-protocol/source/browse/> are tested.

See the test suite for further information.


=head1 AVAILABILITY

  https://github.com/Akron/Crypt-MagicSignatures-Key


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, Nils Diewald.

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl.

=cut
