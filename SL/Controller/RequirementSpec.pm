package SL::Controller::RequirementSpec;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;
use SL::DB::Customer;
use SL::DB::Project;
use SL::DB::RequirementSpecStatus;
use SL::DB::RequirementSpecType;
use SL::DB::RequirementSpec;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec requirement_spec_item customers projects types statuses db_args flat_filter is_template) ],
);

__PACKAGE__->run_before('setup');
__PACKAGE__->run_before('load_requirement_spec',      only => [ qw(    edit        update show destroy tree) ]);
__PACKAGE__->run_before('load_select_options',        only => [ qw(new edit create update list) ]);
__PACKAGE__->run_before('load_search_select_options', only => [ qw(                       list) ]);

__PACKAGE__->get_models_url_params('flat_filter');
__PACKAGE__->make_paginated(
  MODEL         => 'RequirementSpec',
  PAGINATE_ARGS => 'db_args',
  ONLY          => [ qw(list) ],
);

__PACKAGE__->make_sorted(
  MODEL         => 'RequirementSpec',
  ONLY          => [ qw(list) ],

  DEFAULT_BY    => 'customer',
  DEFAULT_DIR   => 1,

  customer      => t8('Customer'),
  title         => t8('Title'),
  type          => t8('Requirement Spec Type'),
  status        => t8('Requirement Spec Status'),
  projectnumber => t8('Project Number'),
);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->setup_db_args_from_filter;
  $self->flat_filter({ map { $_->{key} => $_->{value} } $::form->flatten_variables('filter') });

  $self->prepare_report;

  my $requirement_specs = $self->get_models(%{ $self->db_args });

  $self->report_generator_list_objects(report => $self->{report}, objects => $requirement_specs);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec} = SL::DB::RequirementSpec->new;
  $self->render('requirement_spec/form', title => t8('Create a new requirement spec'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('requirement_spec/form', title => t8('Edit requirement spec'));
}

sub action_show {
  my ($self) = @_;

  my $item = $::form->{requirement_spec_item_id} ? SL::DB::RequirementSpecItem->new(id => $::form->{requirement_spec_item_id})->load : @{ $self->requirement_spec->sections }[0];
  $self->requirement_spec_item($item);

  $self->render('requirement_spec/show', title => t8('Show requirement spec'));
}

sub action_create {
  my ($self) = @_;

  $self->{requirement_spec} = SL::DB::RequirementSpec->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{requirement_spec}->delete; 1; }) {
    flash_later('info',  t8('The requirement spec has been deleted.'));
  } else {
    flash_later('error', t8('The requirement spec is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::RequirementSpec->reorder_list(@{ $::form->{requirement_spec_id} || [] });

  $self->render('1;', { type => 'js', inline => 1 });
}

sub action_tree {
  my ($self) = @_;
  my $r = $self->render('requirement_spec/tree', now => DateTime->now);
}

#
# filters
#

sub setup {
  my ($self) = @_;

  $::auth->assert('config');
  $::request->{layout}->use_stylesheet("${_}.css") for qw(jquery.contextMenu requirement_spec);
  $::request->{layout}->use_javascript("${_}.js") for qw(jquery.jstree jquery/jquery.contextMenu requirement_spec);
  $self->is_template($::form->{is_template} ? 1 : 0);

  return 1;
}

sub load_requirement_spec {
  my ($self) = @_;
  $self->{requirement_spec} = SL::DB::RequirementSpec->new(id => $::form->{id})->load || die "No such requirement spec";
}

sub load_select_options {
  my ($self) = @_;

  my @filter = ('!obsolete' => 1);
  if ($self->requirement_spec && $self->requirement_spec->customer_id) {
    @filter = ( or => [ @filter, id => $self->requirement_spec->customer_id ] );
  }

  $self->customers(SL::DB::Manager::Customer->get_all_sorted(where => \@filter));
  $self->statuses( SL::DB::Manager::RequirementSpecStatus->get_all_sorted);
  $self->types(    SL::DB::Manager::RequirementSpecType->get_all_sorted);
}

sub load_search_select_options {
  my ($self) = @_;

  $self->projects(SL::DB::Manager::Project->get_all_sorted);
}

#
# helpers
#

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->{requirement_spec}->id;
  my $params = delete($::form->{requirement_spec}) || { };
  my $title  = $is_new ? t8('Create a new requirement spec') : t8('Edit requirement spec');

  $self->{requirement_spec}->assign_attributes(%{ $params });

  my @errors = $self->{requirement_spec}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('requirement_spec/form', title => $title);
    return;
  }

  $self->{requirement_spec}->save;

  flash_later('info', $is_new ? t8('The requirement spec has been created.') : t8('The requirement spec has been saved.'));
  $self->redirect_to(action => 'list');
}

sub setup_db_args_from_filter {
  my ($self) = @_;

  $self->{filter} = {};
  my %args = parse_filter(
    $::form->{filter},
    with_objects => [ 'customer', 'type', 'status', 'project' ],
    launder_to   => $self->{filter},
  );

  $args{where} = [
    and => [
      @{ $args{where} || [] },
      is_template => $self->is_template
    ]];

  $self->db_args(\%args);
}

sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->get_callback;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(title customer status type projectnumber);
  my @sortable    = qw(title customer status type projectnumber);

  my %column_defs = (
    title         => { obj_link => sub { $self->url_for(action => 'edit', id => $_[0]->id, callback => $callback) } },
    customer      => { raw_data => sub { $self->presenter->customer($_[0]->customer, display => 'table-cell', callback => $callback) },
                       sub      => sub { $_[0]->customer->name } },
    projectnumber => { raw_data => sub { $self->presenter->project($_[0]->project, display => 'table-cell', callback => $callback) },
                       sub      => sub { $_[0]->project_id ? $_[0]->project->projectnumber : '' } },
    status        => { sub      => sub { $_[0]->status->description } },
    type          => { sub      => sub { $_[0]->type->description } },
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'RequirementSpec',
    output_format         => 'HTML',
    raw_top_info_text     => $self->render('requirement_spec/report_top',    { output => 0 }),
    raw_bottom_info_text  => $self->render('requirement_spec/report_bottom', { output => 0 }),
    title                 => $::locale->text('Requirement Specs'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  $self->disable_pagination if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
}

1;
