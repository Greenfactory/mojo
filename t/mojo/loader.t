use Mojo::Base -strict;

BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll' }

use Test::More;

use Mojo::File qw(curfile);
use lib curfile->sibling('lib')->to_string;

use Mojo::Loader qw(data_section file_is_binary find_packages find_modules load_class is_package);

package MyLoaderTest::Foo::Bar;

package MyLoaderTest::Foo::Baz;

package main;

# Single character core module
ok !load_class('B'), 'loaded';
ok !!UNIVERSAL::can(B => 'svref_2object'), 'method found';

# Exception
my $e = load_class 'Mojo::LoaderException';
isa_ok $e, 'Mojo::Exception', 'right exception';
like $e->message, qr/Missing right curly/, 'right message';
is $e->lines_before->[0][0], 4,             'right number';
is $e->lines_before->[0][1], '',            'right line';
is $e->lines_before->[1][0], 5,             'right number';
is $e->lines_before->[1][1], 'sub new { }', 'right line';
is $e->lines_before->[2][0], 6,             'right number';
is $e->lines_before->[2][1], '',            'right line';
is $e->lines_before->[3][0], 7,             'right number';
is $e->lines_before->[3][1], 'foo {',       'right line';
is $e->lines_before->[4][0], 8,             'right number';
is $e->lines_before->[4][1], '',            'right line';
is $e->line->[0], 9,    'right number';
is $e->line->[1], "1;", 'right line';
like "$e", qr/Missing right curly/, 'right message';

# Complicated exception
$e = load_class 'Mojo::LoaderException2';
isa_ok $e, 'Mojo::Exception', 'right exception';
like $e->message, qr/Exception/, 'right message';
is $e->lines_before->[0][0], 1,                                 'right number';
is $e->lines_before->[0][1], 'package Mojo::LoaderException2;', 'right line';
is $e->lines_before->[1][0], 2,                                 'right number';
is $e->lines_before->[1][1], 'use Mojo::Base -strict;',         'right line';
is $e->lines_before->[2][0], 3,                                 'right number';
is $e->lines_before->[2][1], '',                                'right line';
is $e->line->[0], 4,                                          'right number';
is $e->line->[1], 'Mojo::LoaderException2_2::throw_error();', 'right line';
is $e->lines_after->[0][0], 5,    'right number';
is $e->lines_after->[0][1], '',   'right line';
is $e->lines_after->[1][0], 6,    'right number';
is $e->lines_after->[1][1], '1;', 'right line';
like "$e", qr/Exception/, 'right message';

# Search modules
my @modules = find_modules 'Mojo::LoaderTest';
is_deeply \@modules, [qw(Mojo::LoaderTest::A Mojo::LoaderTest::B Mojo::LoaderTest::C)], 'found the right modules';
is_deeply [find_modules "Mojo'LoaderTest"], [qw(Mojo'LoaderTest::A Mojo'LoaderTest::B Mojo'LoaderTest::C)],
  'found the right modules';
is_deeply [find_modules 'MyLoaderTest::DoesNotExist'], [], 'no modules found';

# Search packages
my @pkgs = find_packages 'MyLoaderTest::Foo';
is_deeply \@pkgs, ['MyLoaderTest::Foo::Bar', 'MyLoaderTest::Foo::Baz'], 'found the right packages';
is_deeply [find_packages 'MyLoaderTest::DoesNotExist'], [], 'no packages found';

# is_package
# To check cases use
# perl -e"package aaa::a; print __PACKAGE__"

# is_package valid
ok is_package('A'), 'valid package';
ok is_package('a::aaa'), 'valid package';
ok is_package('A::aaa'), 'valid package';
ok is_package('a1::aaa'), 'valid package';
ok is_package('a1::AaA::a'), 'valid package';
ok is_package("a1'AaA::a"), 'valid package';
ok is_package('_::aaa'), 'valid package';
ok is_package('_::111'), 'valid package';

#is_package invalid
ok !is_package('A:::aaa'), 'invalid package';
ok !is_package('1::aaa'), 'invalid package';
ok !is_package('a:aaa'), 'invalid package';
ok !is_package('a::'), 'invalid package';
ok !is_package("a'"), 'invalid package';
ok !is_package('::a'), 'invalid package';
ok !is_package('aa-a'), 'valid package';

# Load
ok !load_class("Mojo'LoaderTest::A"), 'loaded successfully';
ok !!Mojo::LoaderTest::A->can('new'), 'loaded successfully';
load_class $_ for @modules;
ok !!Mojo::LoaderTest::B->can('new'), 'loaded successfully';
ok !!Mojo::LoaderTest::C->can('new'), 'loaded successfully';

# Class does not exist
is load_class('Mojo::LoaderTest'), 1, 'nothing to load';
is load_class('Mojo::LoaderTest'), 1, 'nothing to load';

# Invalid class
is load_class('Mojolicious/Lite'),      1,     'nothing to load';
is load_class('Mojolicious/Lite.pm'),   1,     'nothing to load';
is load_class('Mojolicious\Lite'),      1,     'nothing to load';
is load_class('Mojolicious\Lite.pm'),   1,     'nothing to load';
is load_class('::Mojolicious::Lite'),   1,     'nothing to load';
is load_class('Mojolicious::Lite::'),   1,     'nothing to load';
is load_class('::Mojolicious::Lite::'), 1,     'nothing to load';
is load_class('Mojolicious::Lite'),     undef, 'loaded successfully';

# UNIX DATA templates
{
  my $unix = "@@ template1\nFirst Template\n@@ template2\r\nSecond Template\n";
  open my $data, '<', \$unix;
  no strict 'refs';
  *{"Example::Package::UNIX::DATA"} = $data;
  ok !file_is_binary('Example::Package::UNIX', 'template1'), 'file is not binary';
  is data_section('Example::Package::UNIX', 'template1'), "First Template\n",  'right template';
  is data_section('Example::Package::UNIX', 'template2'), "Second Template\n", 'right template';
  is_deeply [sort keys %{data_section 'Example::Package::UNIX'}], [qw(template1 template2)], 'right DATA files';
}

# Windows DATA templates
{
  my $windows = "@@ template3\r\nThird Template\r\n@@ template4\r\nFourth Template\r\n";
  open my $data, '<', \$windows;
  no strict 'refs';
  *{"Example::Package::Windows::DATA"} = $data;
  is data_section('Example::Package::Windows', 'template3'), "Third Template\r\n",  'right template';
  is data_section('Example::Package::Windows', 'template4'), "Fourth Template\r\n", 'right template';
  is_deeply [sort keys %{data_section 'Example::Package::Windows'}], [qw(template3 template4)], 'right DATA files';
}

# Mixed whitespace
{
  my $mixed = "@\@template5\n5\n\n@@  template6\n6\n@@     template7\n7";
  open my $data, '<', \$mixed;
  no strict 'refs';
  *{"Example::Package::Mixed::DATA"} = $data;
  is data_section('Example::Package::Mixed', 'template5'), "5\n\n", 'right template';
  is data_section('Example::Package::Mixed', 'template6'), "6\n",   'right template';
  is data_section('Example::Package::Mixed', 'template7'), '7',     'right template';
  is_deeply [sort keys %{data_section 'Example::Package::Mixed'}], [qw(template5 template6 template7)],
    'right DATA files';
}

# Base64
{
  my $b64 = "@\@test.bin (base64)\n4pml";
  open my $data, '<', \$b64;
  no strict 'refs';
  *{"Example::Package::Base64::DATA"} = $data;
  ok !file_is_binary('Example::Package::DoesNotExist', 'test.bin'), 'file is not binary';
  ok file_is_binary('Example::Package::Base64', 'test.bin'),        'file is binary';
  is data_section('Example::Package::Base64', 'test.bin'), "\xe2\x99\xa5", 'right template';
  is_deeply [sort keys %{data_section 'Example::Package::Base64'}], ['test.bin'], 'right DATA files';
}

# Hide DATA usage from error messages
eval { die 'whatever' };
unlike $@, qr/DATA/, 'DATA has been hidden';

done_testing();
