#!/usr/bin/env perl
use Test::More;
use strict;
use warnings;
no strict 'refs';

use lib '../lib';

BEGIN {
  use_ok('Crypt::MagicSignatures::Envelope');
  use_ok('Crypt::MagicSignatures::Key');
};



ok(my $me = Crypt::MagicSignatures::Envelope->new(
  data => 'Some arbitrary string.'
), 'Constructor (Attributes)');

is($me->data, 'Some arbitrary string.', 'Data');
is($me->data_type, 'text/plain', 'Data type');
is($me->alg, 'RSA-SHA256', 'Algorithm');
is($me->encoding, 'base64url', 'Encoding');

ok(!$me->signed, 'Is not signed');
ok(!$me->dom, 'DOM not okay');

ok($me = Crypt::MagicSignatures::Envelope->new(<<'MEJSON'), 'Constructor (JSON)');
{
  "data_type": "text\/plain",
  "data":"U29tZSBhcmJpdHJhcnkgc3RyaW5nLg==",
  "alg":"RSA-SHA256",
  "encoding":"base64url",
  "sigs": [
    { "key_id": "my-01",
      "value": "S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVluZkI5Ulh4dmRFSnFhQW5XUmpBUEJqZUM0b0lReER4d0IwWGVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ=="
    }
  ]
}
MEJSON

ok($me->signed, 'Is signed');

is($me->data, 'Some arbitrary string.', 'Data');
is($me->data_type, 'text/plain', 'Data type');
is($me->alg, 'RSA-SHA256', 'Algorithm');
is($me->encoding, 'base64url', 'Encoding');

ok($me = Crypt::MagicSignatures::Envelope->new(<<'MECOMPACT'), 'Constructor (Compact)');
    bXktMDE=.S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVlu
    ZkI5Ulh4dmRFSnFhQW5XUmpBUEJqZUM0b0lReER4d0IwW
    GVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==.U29tZ
    SBhcmJpdHJhcnkgc3RyaW5nLg.dGV4dC9wbGFpbg.YmFz
    ZTY0dXJs.UlNBLVNIQTI1Ng
MECOMPACT

is($me->data, 'Some arbitrary string.', 'Data');
is($me->data_type, 'text/plain', 'Data type');
is($me->alg, 'RSA-SHA256', 'Algorithm');
is($me->encoding, 'base64url', 'Encoding');

ok($me = Crypt::MagicSignatures::Envelope->new(<<'MEXML'), 'Constructor (XML)');

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

is($me->data, 'Some arbitrary string.', 'Data');
is($me->data_type, 'text/plain', 'Data type');
is($me->alg, 'RSA-SHA256', 'Algorithm');
is($me->encoding, 'base64url', 'Encoding');

ok(my $sig = $me->signature, 'Signature');
is($sig->{key_id}, 'my-01', 'Signature Key id');
is($sig->{value}, 'S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVluZkI5Ulh4dmRFSnFhQW5XUmpBUEJqZUM0b0lReER4d0IwWGVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==', 'Signature value');

# Signing

ok($me = Crypt::MagicSignatures::Envelope->new(
  data => 'Some arbitrary string.'
), 'Construct Envelope');

ok(my $mkey = Crypt::MagicSignatures::Key->new(
  n => '7559044843939663506259320537304075578393827653061512'.
    '8473782766607634893582870680024021118955399592377939320'.
    '97814477506511744331780532898089567876987800547',
  e => '65537',
  d => '4081886522529635038016957654686531802178274267083432'.
    '8649269452526728395927456718919822835972368706726172581'.
    '7490923395335201901856183147375494766403567873'
), 'Key constructor');


ok($me->sign(my_key => $mkey), 'Sign me');

ok($me->verify($mkey->to_string), 'Verify me');

ok($me->sign(my_second_key => $mkey, -data), 'Sign me data');

ok($me->verify([my_second_key => $mkey->to_string, -data]), 'Verify me data');

ok(!$me->verify([my_second_key => $mkey->to_string]), 'Verify me base (fail)');

is($me->signature_base,
   'U29tZSBhcmJpdHJhcnkgc3RyaW5nLg.dGV4dC9wbGFpbg==.YmFzZTY0dXJs.UlNBLVNIQTI1Ng==',
   'Base signature');

is_deeply($me->signature, {
  key_id => 'my_key',
  value => 'EzyOt1ff81lAjlIz26P9CMTfk4OHSULh9kdiVFu' .
    'lpHXQCOjxUSOARQ3nZl-cTy9F6aaaqmFr5GY7hZ-LmJ1Vew=='
  }, 'Signature');

is_deeply($me->signature('my_key'), {
  key_id => 'my_key',
  value => 'EzyOt1ff81lAjlIz26P9CMTfk4OHSULh9kdiVFu' .
    'lpHXQCOjxUSOARQ3nZl-cTy9F6aaaqmFr5GY7hZ-LmJ1Vew=='
  }, 'Signature');

is_deeply($me->signature('my_second_key'), {
  key_id => 'my_second_key',
  value => 'gmsMM5n009SuiWy39ZcvxzA7X4DcH5T6BD7LuwYA7nO18W4qwQLo5gN6_G4lAljg-F1gwwfoubgTv7UInxZV7Q=='
  }, 'Signature');

# Test XML
my $xml_msg =<< 'XML';
<?xml version='1.0' encoding='UTF-8'?>
<entry xmlns='http://www.w3.org/2005/Atom'>
  <id>tag:example.com,2009:cmt-0.44775718</id>
  <author><name>test@example.com</name><uri>bob@example.com</uri></author>
  <thr:in-reply-to xmlns:thr='http://purl.org/syndication/thread/1.0'
    ref='tag:blogger.com,1999:blog-893591374313312737.post-3861663258538857954'>
    tag:blogger.com,1999:blog-893591374313312737.post-3861663258538857954
  </thr:in-reply-to>
  <content>Salmon swim upstream!</content>
  <title>Salmon swim upstream!</title>
  <updated>2009-12-18T20:04:03Z</updated>
</entry>
XML

ok($me = Crypt::MagicSignatures::Envelope->new(
  data => $xml_msg,
  data_type => 'application/atom+xml'
), 'Construct Envelope');

ok(!$me->to_compact, 'Compact impossible as it is not signed');

ok($me->to_json, 'JSON okay');

ok($me->to_xml, 'JSON okay');

ok($me->dom, 'DOM okay');

is($me->dom->at('id')->text, 'tag:example.com,2009:cmt-0.44775718', 'DOM id');
is($me->dom->at('author > uri')->text, 'bob@example.com', 'DOM author uri');
is($me->dom->at('content')->text, 'Salmon swim upstream!', 'DOM content');
is($me->dom->at('title')->text, 'Salmon swim upstream!', 'DOM title');

ok($me = Crypt::MagicSignatures::Envelope->new( data => <<'XML'), 'Create xml me');
<?xml version='1.0' encoding='UTF-8'?>
<entry xmlns='http://www.w3.org/2005/Atom'>
  <author><uri>alice@example.com</uri></author>
</entry>
XML
ok($me->data_type('application/atom+xml'), 'Set datatype'),
is($me->dom->at('author > uri')->text, 'alice@example.com', 'DOM author uri');

{
  local $SIG{__WARN__} = sub {};

ok(!($me = Crypt::MagicSignatures::Envelope->new(<<'MEXML')), 'Constructor (XML) Wrong enc');
  <?xml version="1.0" encoding="UTF-8"?>
  <me:env xmlns:me="http://salmon-protocol.org/ns/magic-env">
    <me:data type="text/plain">
      U29tZSBhcmJpdHJhcnkgc3RyaW5nLg==
    </me:data>
    <me:encoding>unk</me:encoding>
    <me:alg>RSA-SHA256</me:alg>
    <me:sig key_id="my-01">
      S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVluZkI5Ulh4dmRFSnFhQW5XUmpB
      UEJqZUM0b0lReER4d0IwWGVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==
    </me:sig>
  </me:env>
MEXML

ok($me = Crypt::MagicSignatures::Envelope->new(<<'MEXML'), 'Constructor (XML) Fuzzy Enc');
  <?xml version="1.0" encoding="UTF-8"?>
  <me:env xmlns:me="http://salmon-protocol.org/ns/magic-env">
    <me:data type="text/plain">
      U29tZSBhcmJpdHJhcnkgc3RyaW5nLg==
    </me:data>
    <me:encoding>Base64URL</me:encoding>
    <me:alg>RSA-SHA256</me:alg>
    <me:sig key_id="my-01">
      S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVluZkI5Ulh4dmRFSnFhQW5XUmpB
      UEJqZUM0b0lReER4d0IwWGVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==
    </me:sig>
  </me:env>
MEXML

ok(!($me = Crypt::MagicSignatures::Envelope->new(<<'MEXML')), 'Constructor (XML) Wrong alg');
  <?xml version="1.0" encoding="UTF-8"?>
  <me:env xmlns:me="http://salmon-protocol.org/ns/magic-env">
    <me:data type="text/plain">
      U29tZSBhcmJpdHJhcnkgc3RyaW5nLg==
    </me:data>
    <me:encoding>base64url</me:encoding>
    <me:alg>RSA/SHA256</me:alg>
    <me:sig key_id="my-01">
      S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVluZkI5Ulh4dmRFSnFhQW5XUmpB
      UEJqZUM0b0lReER4d0IwWGVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==
    </me:sig>
  </me:env>
MEXML

ok($me = Crypt::MagicSignatures::Envelope->new(<<'MEXML'), 'Constructor (XML) Fuzzy alg');
  <?xml version="1.0" encoding="UTF-8"?>
  <me:env xmlns:me="http://salmon-protocol.org/ns/magic-env">
    <me:data type="text/plain">
      U29tZSBhcmJpdHJhcnkgc3RyaW5nLg==
    </me:data>
    <me:encoding>base64url</me:encoding>
    <me:alg>rsa-sha256</me:alg>
    <me:sig key_id="my-01">
      S1VqYVlIWFpuRGVTX3l4S09CcWdjRVFDYVluZkI5Ulh4dmRFSnFhQW5XUmpB
      UEJqZUM0b0lReER4d0IwWGVQZDhzWHAxN3oybWhpTk1vNHViNGNVOVE9PQ==
    </me:sig>
  </me:env>
MEXML



};

done_testing;

__END__

