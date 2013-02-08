#!/usr/bin/env perl
use 5.010001;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    VERSION_FROM => 'lib/Crypt/MagicSignatures/Envelope.pm',
    NAME         => 'Crypt::MagicSignatures::Envelope',
    AUTHOR       => 'Nils Diewald',
    PREREQ_PM => {
      'Crypt::MagicSignatures::Key' => '0.04',
      'Mojolicious' => 3.43,
      'Carp' => 0,
      'Test::More' => 0
    },
    LICENSE => 'perl',
    META_MERGE   => {
      requires  => {perl => '5.010001'},
      resources => {
	license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
	repository  => 'https://github.com/Akron/Crypt-MagicSignatures-Envelope'
      }
    },
    test => {TESTS => 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t'}
);
