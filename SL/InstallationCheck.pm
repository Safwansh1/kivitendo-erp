package SL::InstallationCheck;

use English '-no_match_vars';
use IO::File;

use vars qw(@required_modules @optional_modules @developer_modules);

use strict;

BEGIN {
@required_modules = (
  { name => "parent",                              url => "http://search.cpan.org/~corion/",    debian => 'libparent-perl' },
  { name => "Archive::Zip",    version => '1.16',  url => "http://search.cpan.org/~adamk/",     debian => 'libarchive-zip-perl' },
  { name => "Config::Std",                         url => "http://search.cpan.org/~dconway/",   debian => 'libconfig-std-perl' },
  { name => "DateTime",                            url => "http://search.cpan.org/~drolsky/",   debian => 'libdatetime-perl' },
  { name => "DBI",             version => '1.50',  url => "http://search.cpan.org/~timb/",      debian => 'libdbi-perl' },
  { name => "DBD::Pg",         version => '1.49',  url => "http://search.cpan.org/~dbdpg/",     debian => 'libdbd-pg' },
  { name => "Email::Address",                      url => "http://search.cpan.org/~rjbs/",      debian => 'libemail-address-perl' },
  { name => "FCGI",                                url => "http://search.cpan.org/~mstrout/",   debian => 'libfcgi-perl' },
  { name => "JSON",                                url => "http://search.cpan.org/~makamaka",   debian => 'libjson-perl' },
  { name => "List::MoreUtils", version => '0.21',  url => "http://search.cpan.org/~vparseval/", debian => 'liblist-moreutils-perl' },
  { name => "Params::Validate",                    url => "http://search.cpan.org/~drolsky/",   debian => 'libparams-validate-perl' },
  { name => "PDF::API2",       version => '2.000', url => "http://search.cpan.org/~areibens/",  debian => 'libpdf-api2-perl' },
  { name => "Rose::Object",                        url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-object-perl' },
  { name => "Rose::DB",                            url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-db-perl' },
  { name => "Rose::DB::Object",                    url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-db-object-perl' },
  { name => "String::ShellQuote", version => 1.01, url => "http://search.cpan.org/~rosch/",     debian => 'libstring-shellquote-perl' },
  { name => "Sort::Naturally",                     url => "http://search.cpan.org/~sburke/",    debian => 'libsort-naturally-perl' },
  { name => "Template",        version => '2.18',  url => "http://search.cpan.org/~abw/",       debian => 'libtemplate-perl' },
  { name => "Text::CSV_XS",    version => '0.23',  url => "http://search.cpan.org/~hmbrand/",   debian => 'libtext-csv-xs-perl' },
  { name => "Text::Iconv",     version => '1.2',   url => "http://search.cpan.org/~mpiotr/",    debian => 'libtext-iconv-perl' },
  { name => "URI",             version => '1.35',  url => "http://search.cpan.org/~gaas/",      debian => 'liburi-perl' },
  { name => "XML::Writer",     version => '0.602', url => "http://search.cpan.org/~josephw/",   debian => 'libxml-writer-perl' },
  { name => "YAML",            version => '0.62',  url => "http://search.cpan.org/~ingy/",      debian => 'libyaml-perl' },
);

@optional_modules = (
  { name => "Digest::SHA",                         url => "http://search.cpan.org/~mshelor/",   debian => 'libdigest-sha-perl' },
  { name => "IO::Socket::SSL",                     url => "http://search.cpan.org/~sullr/",     debian => 'libio-socket-ssl-perl' },
  { name => "Net::LDAP",                           url => "http://search.cpan.org/~gbarr/",     debian => 'libnet-ldap-perl' },
);

@developer_modules = (
  { name => "Devel::REPL",                         url => "http://search.cpan.org/~doy/",       debian => 'libdevel-repl-perl' },
  { name => "Moose::Role",                         url => "http://search.cpan.org/~doy/",       debian => 'libmoose-role-perl' },
  { name => "Perl::Tags",                          url => "http://search.cpan.org/~osfameron/", debian => 'libperl-tags-perl' },
);

$_->{fullname} = join ' ', grep $_, @$_{qw(name version)}
  for @required_modules, @optional_modules, @developer_modules;

}

sub module_available {
  my $module  = $_[0];
  my $version = $_[1] || '' ;

  my $got = eval "use $module $version; 1";

  if ($got) {
    return ($got, $module->VERSION);
  } else {
    return
  }
}

sub check_kpsewhich {
  my $exit = system("which kpsewhich > /dev/null");

  return $exit > 0 ? 0 : 1;
}

sub template_dirs {
  my ($path) = @_;
  opendir my $dh, $path || die "can't open $path";
  my @templates = sort grep { !/^\.\.?$/ } readdir $dh;
  close $dh;

  return @templates;
}

sub classes_from_latex {
  my ($path, $class) = @_;
  eval { use String::ShellQuote; 1 } or warn "can't load String::ShellQuote" && return;
  $path  = shell_quote $path;
  $class = shell_quote $class;

  open my $pipe, q#egrep -rs '^[\ \t]*# . "$class' $path". q# | sed 's/ //g' | awk -F '{' '{print $2}' | awk -F '}' '{print $1}' |#;
  my @cls = <$pipe>;
  close $pipe;

  # can't use uniq here
  my %class_hash = map { $_ => 1 } map { s/\n//; $_ } split ',', join ',', @cls;
  return sort keys %class_hash;
}

my %conditional_dependencies;

sub check_for_conditional_dependencies {
  return if $conditional_dependencies{net_ldap}++;

  push @required_modules, grep { $_->{name} eq 'Net::LDAP' } @optional_modules
    if $::lx_office_conf{authentication} && ($::lx_office_conf{authentication}->{module} eq 'LDAP');
}

sub test_all_modules {
  return grep { !module_available($_->{name}) } @required_modules;
}

1;
