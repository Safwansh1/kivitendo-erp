package SL::Controller::Helper::GetModels::Base;

use strict;
use parent 'Rose::Object';
use Scalar::Util qw(weaken);


use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(get_models) ],
);

sub set_get_models {
  $_[0]->get_models($_[1]);

  weaken($_[1]);
}

sub merge_args {
  my ($self, @args) = @_;
  my $final_args = { };

  for my $field (qw(query with_objects)) {
    $final_args->{$field} = [ map { @{ $_->{$field} || [] } } @args ];
  }

  return %$final_args;
}

1;
