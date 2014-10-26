#!/usr/bin/env perl
use Test::More;
use strict;
use warnings;
no strict 'refs';

$|++;

use lib '../lib', '../../lib';

our ($module, $modulekey);
BEGIN {
    our $module    = 'Crypt::MagicSignatures::Envelope';
    our $modulekey = 'Crypt::MagicSignatures::Key';
    use_ok($module);
    use_ok($modulekey, qw/b64url_encode b64url_decode/);
};


# From Minime test suite

ok(my $mkey = Crypt::MagicSignatures::Key->new(<<'IDENTICAKEY'), 'Key Constructor');
RSA.oSdSbJ99WDC0zRUpk41bpI42FarMo-o6JxJKEeKCPSU1SW9kdXdAUPhWu0JVwdF5rDXWijXaOcdZ3utGwk0pmKxsX6MEQg54L4rfIzWZiHz9OUGgDx9R4tXpm38CXOGfpu4Sx2lmeYVxIii32P32EPJHyZN5Zi9Sr_8zSbXYnM8=.AQAB
IDENTICAKEY

ok(my $me = Crypt::MagicSignatures::Envelope->new(<<'IDENTICA'), 'Envelope Constructor');
<?xml version="1.0"?>
<me:env xmlns:me="http://salmon-protocol.org/ns/magic-env">
  <me:data type="application/atom+xml">
    PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiID8-PGVudHJ5IHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDA1L0F0b20iIHhtbG5zOmFjdGl2aXR5PSJodHRwOi8vYWN0aXZpdHlzdHJlYS5tcy9zcGVjLzEuMC8iIHhtbG5zOmdlb3Jzcz0iaHR0cDovL3d3dy5nZW9yc3Mub3JnL2dlb3JzcyIgeG1sbnM6b3N0YXR1cz0iaHR0cDovL29zdGF0dXMub3JnL3NjaGVtYS8xLjAiIHhtbG5zOnBvY289Imh0dHA6Ly9wb3J0YWJsZWNvbnRhY3RzLm5ldC9zcGVjLzEuMCIgeG1sbnM6bWVkaWE9Imh0dHA6Ly9wdXJsLm9yZy9zeW5kaWNhdGlvbi9hdG9tbWVkaWEiPgogPGlkPnRhZzppZGVudGkuY2EsMjAxMC0wOC0xMDp1cGRhdGUtcHJvZmlsZTo1MjQ2NzoxOTcwLTAxLTAxVDAwOjAwOjAwKzAwOjAwPC9pZD4KIDx0aXRsZT5Qcm9maWxlIHVwZGF0ZTwvdGl0bGU-CiA8cHVibGlzaGVkPjE5NzAtMDEtMDFUMDA6MDA6MDArMDA6MDA8L3B1Ymxpc2hlZD4KIDxjb250ZW50IHR5cGU9Imh0bWwiPlR1b21hcyBLb3NraSBoYXMgdXBkYXRlZCB0aGVpciBwcm9maWxlIHBhZ2UuPC9jb250ZW50PgogPGF1dGhvcj4KICA8dXJpPmh0dHA6Ly9pZGVudGkuY2EvdXNlci81MjQ2NzwvdXJpPgogIDxuYW1lPlR1b21hcyBLb3NraTwvbmFtZT4KPC9hdXRob3I-CjxhY3Rpdml0eTphY3Rvcj4KIDxhY3Rpdml0eTpvYmplY3QtdHlwZT5odHRwOi8vYWN0aXZpdHlzdHJlYS5tcy9zY2hlbWEvMS4wL3BlcnNvbjwvYWN0aXZpdHk6b2JqZWN0LXR5cGU-CiA8aWQ-aHR0cDovL2lkZW50aS5jYS91c2VyLzUyNDY3PC9pZD4KIDx0aXRsZT5UdW9tYXMgS29za2k8L3RpdGxlPgogPGxpbmsgcmVsPSJhbHRlcm5hdGUiIHR5cGU9InRleHQvaHRtbCIgaHJlZj0iaHR0cDovL2lkZW50aS5jYS90a29za2kiLz4KIDxsaW5rIHJlbD0iYXZhdGFyIiB0eXBlPSJpbWFnZS9qcGVnIiBtZWRpYTp3aWR0aD0iMjY2IiBtZWRpYTpoZWlnaHQ9IjI2NiIgaHJlZj0iaHR0cDovL2F2YXRhci5pZGVudGkuY2EvNTI0NjctMjY2LTIwMTAwODEwMTMzMjIxLmpwZWciLz4KIDxsaW5rIHJlbD0iYXZhdGFyIiB0eXBlPSJpbWFnZS9qcGVnIiBtZWRpYTp3aWR0aD0iOTYiIG1lZGlhOmhlaWdodD0iOTYiIGhyZWY9Imh0dHA6Ly9hdmF0YXIuaWRlbnRpLmNhLzUyNDY3LTk2LTIwMTAwODEwMTMzMjIxLmpwZWciLz4KIDxsaW5rIHJlbD0iYXZhdGFyIiB0eXBlPSJpbWFnZS9qcGVnIiBtZWRpYTp3aWR0aD0iNDgiIG1lZGlhOmhlaWdodD0iNDgiIGhyZWY9Imh0dHA6Ly9hdmF0YXIuaWRlbnRpLmNhLzUyNDY3LTQ4LTIwMTAwODEwMTMzMjIxLmpwZWciLz4KIDxsaW5rIHJlbD0iYXZhdGFyIiB0eXBlPSJpbWFnZS9qcGVnIiBtZWRpYTp3aWR0aD0iMjQiIG1lZGlhOmhlaWdodD0iMjQiIGhyZWY9Imh0dHA6Ly9hdmF0YXIuaWRlbnRpLmNhLzUyNDY3LTI0LTIwMTAwODEwMTMzMjIyLmpwZWciLz4KPHBvY286cHJlZmVycmVkVXNlcm5hbWU-dGtvc2tpPC9wb2NvOnByZWZlcnJlZFVzZXJuYW1lPgo8cG9jbzpkaXNwbGF5TmFtZT5UdW9tYXMgS29za2k8L3BvY286ZGlzcGxheU5hbWU-Cjxwb2NvOm5vdGU-SGFwcHkgRmlubmlzaCBwcm9ncmFtbWVyLjwvcG9jbzpub3RlPgo8cG9jbzphZGRyZXNzPgogPHBvY286Zm9ybWF0dGVkPlBhcmlzPC9wb2NvOmZvcm1hdHRlZD4KPC9wb2NvOmFkZHJlc3M-Cjxwb2NvOnVybHM-CiA8cG9jbzp0eXBlPmhvbWVwYWdlPC9wb2NvOnR5cGU-CiA8cG9jbzp2YWx1ZT5odHRwOi8vd3d3LmxvYnN0ZXJtb25zdGVyLm9yZzwvcG9jbzp2YWx1ZT4KIDxwb2NvOnByaW1hcnk-dHJ1ZTwvcG9jbzpwcmltYXJ5Pgo8L3BvY286dXJscz4KPC9hY3Rpdml0eTphY3Rvcj4KIDxhY3Rpdml0eTp2ZXJiPmh0dHA6Ly9vc3RhdHVzLm9yZy9zY2hlbWEvMS4wL3VwZGF0ZS1wcm9maWxlPC9hY3Rpdml0eTp2ZXJiPgo8L2VudHJ5Pgo=
  </me:data>
  <me:encoding>base64url</me:encoding>
  <me:alg>RSA-SHA256</me:alg>
  <me:sig>FdN0qsIYyc_WtNCca0KMQx2YesT4jfNULkH5wMF6uJE1dwd74_2xEh559xAvnB-siPcdDbZAUb84z7hFSbtEBfbcYmM7PZAfZQFXHM-aXomqx0mXjRnRM2YKxO6l3FCd_enErW2q8E-hDE24FACdEK6LzbJnXFoRxMCYsW8l_jA=</me:sig>
</me:env>
IDENTICA

is($mkey->size, 1024, 'Key size');

ok(!$me->verify($mkey), 'Identica Verification 1');
ok($me->verify([$mkey, -data]), 'Identica Verification 2');
ok($me->verify([$mkey, -compatible]), 'Identica Verification 3');

# From Minime testsuite - seems to be wrong as well:
ok($mkey->verify(b64url_encode($me->data), $me->signature->{value}), 'Identica Verification 4');

done_testing;

__END__
